import Foundation
import Darwin

public enum JobState: String, Codable, CaseIterable, Sendable {
    case planned
    case previewed
    case applying
    case applied
    case cancelled
    case failed
    case rollbackRequired = "rollback-required"
}

public struct VerifiedMutationEvidence: Codable, Equatable, Sendable {
    public var evidenceID: String
    public var afterSnapshotHash: String
    public var verified: Bool
    public var details: [String]

    public init(evidenceID: String, afterSnapshotHash: String, verified: Bool, details: [String] = []) {
        self.evidenceID = evidenceID
        self.afterSnapshotHash = afterSnapshotHash
        self.verified = verified
        self.details = details
    }
}

public struct RollbackPayload: Codable, Equatable, Sendable {
    public var operationID: UUID
    public var planHash: String
    public var preconditionRevision: String
    public var beforeSnapshotHash: String?
    public var sourceContentHashes: [String]
    public var createdAt: Date

    public init(operationID: UUID, planHash: String, preconditionRevision: String, beforeSnapshotHash: String? = nil, sourceContentHashes: [String] = [], createdAt: Date = Date()) {
        self.operationID = operationID
        self.planHash = planHash
        self.preconditionRevision = preconditionRevision
        self.beforeSnapshotHash = beforeSnapshotHash
        self.sourceContentHashes = sourceContentHashes
        self.createdAt = createdAt
    }
}

public struct JobRecord: Codable, Equatable, Sendable {
    public var operationID: UUID
    public var planHash: String
    public var effectID: EffectID
    public var state: JobState
    public var preconditionRevision: String
    public var rollbackPayloadPath: String
    public var verifiedEvidence: VerifiedMutationEvidence?
    public var error: String?
    public var rollbackRequired: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(operationID: UUID, planHash: String, effectID: EffectID, state: JobState = .planned, preconditionRevision: String, rollbackPayloadPath: String, verifiedEvidence: VerifiedMutationEvidence? = nil, error: String? = nil, rollbackRequired: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.operationID = operationID
        self.planHash = planHash
        self.effectID = effectID
        self.state = state
        self.preconditionRevision = preconditionRevision
        self.rollbackPayloadPath = rollbackPayloadPath
        self.verifiedEvidence = verifiedEvidence
        self.error = error
        self.rollbackRequired = rollbackRequired
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct JobHistoryEvent: Codable, Equatable, Sendable {
    public var eventID: UUID
    public var operationID: UUID
    public var state: JobState
    public var record: JobRecord
    public var detail: String?
    public var createdAt: Date

    public init(eventID: UUID = UUID(), operationID: UUID, state: JobState, record: JobRecord, detail: String? = nil, createdAt: Date = Date()) {
        self.eventID = eventID
        self.operationID = operationID
        self.state = state
        self.record = record
        self.detail = detail
        self.createdAt = createdAt
    }
}

public enum JobCoordinatorError: Error, LocalizedError, Equatable {
    case invalidRuntimeRoot(String)
    case duplicateOperation(UUID)
    case unknownOperation(UUID)
    case invalidTransition(from: JobState, to: JobState)
    case staleRevision(expected: String, actual: String)
    case cancelled(UUID)
    case mutationFailed(String)
    case verificationFailed(String)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRuntimeRoot(let reason): return "Invalid job runtime root: \(reason)"
        case .duplicateOperation(let id): return "Operation is already recorded and cannot run again: \(id.uuidString)"
        case .unknownOperation(let id): return "Unknown operation: \(id.uuidString)"
        case .invalidTransition(let from, let to): return "Invalid job transition \(from.rawValue) -> \(to.rawValue)"
        case .staleRevision(let expected, let actual): return "Stale selection revision (expected \(expected), got \(actual))"
        case .cancelled(let id): return "Operation was cancelled before mutation: \(id.uuidString)"
        case .mutationFailed(let reason): return "Mutation failed; rollback is required: \(reason)"
        case .verificationFailed(let reason): return "Mutation verification failed; rollback is required: \(reason)"
        case .persistenceFailed(let reason): return "Unable to persist job state: \(reason)"
        }
    }
}

/// Offline coordinator for typed plans. The mutation closure is deliberately
/// injected by a later adapter; this type never knows how to call Final Cut,
/// a shell, a network, or UI automation.
public actor JobCoordinator {
    public let runtimeRoot: URL

    private let pathPolicy: PathPolicy
    private let jobsDirectory: URL
    private let rollbackDirectory: URL
    private let historyURL: URL
    private let registry: EffectRegistry?
    private var jobs: [UUID: JobRecord]
    private var events: [JobHistoryEvent]

    public init(runtimeRoot: URL, registry: EffectRegistry? = nil) throws {
        let canonical = runtimeRoot.standardizedFileURL
        guard canonical.isFileURL, canonical.path.hasPrefix("/"), canonical.path != "/", !canonical.path.split(separator: "/").contains("..") else {
            throw JobCoordinatorError.invalidRuntimeRoot("runtime root must be an absolute canonical directory")
        }
        guard !canonical.path.unicodeScalars.contains(where: { ";&|`$()<>*?{}\n\r".unicodeScalars.contains($0) }) else {
            throw JobCoordinatorError.invalidRuntimeRoot("runtime root contains shell metacharacters")
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: canonical.path) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: canonical.path, isDirectory: &isDirectory), isDirectory.boolValue, !((try? canonical.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true) else {
                throw JobCoordinatorError.invalidRuntimeRoot("runtime root must be a real directory")
            }
        } else {
            do { try fileManager.createDirectory(at: canonical, withIntermediateDirectories: true) }
            catch { throw JobCoordinatorError.invalidRuntimeRoot(error.localizedDescription) }
        }
        guard canonical.resolvingSymlinksInPath().standardizedFileURL.path == canonical.path else {
            throw JobCoordinatorError.invalidRuntimeRoot("runtime root must not resolve through a symlink")
        }

        let policy = PathPolicy(allowedInputRoots: [], outputRoot: canonical)
        let jobs = canonical.appendingPathComponent("jobs", isDirectory: true)
        let rollback = canonical.appendingPathComponent("rollback", isDirectory: true)
        do {
            try fileManager.createDirectory(at: jobs, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: rollback, withIntermediateDirectories: true)
            _ = try policy.validateOutput(jobs, overwrite: true)
            _ = try policy.validateOutput(rollback, overwrite: true)
        } catch {
            throw JobCoordinatorError.invalidRuntimeRoot(error.localizedDescription)
        }

        self.runtimeRoot = canonical
        self.pathPolicy = policy
        self.jobsDirectory = jobs
        self.rollbackDirectory = rollback
        self.historyURL = canonical.appendingPathComponent("history.jsonl")
        self.registry = registry
        self.jobs = [:]
        self.events = []

        do {
            self.events = try Self.loadEvents(from: self.historyURL)
            for event in self.events { self.jobs[event.operationID] = event.record }
            for url in try fileManager.contentsOfDirectory(at: jobs, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "json" }) {
                let record = try Self.loadRecord(from: url)
                self.jobs[record.operationID] = record
            }
        } catch {
            throw JobCoordinatorError.persistenceFailed("history or job record is unreadable: \(error.localizedDescription)")
        }
    }

    public func history() -> [JobHistoryEvent] { events }

    public func record(operationID: UUID) -> JobRecord? { jobs[operationID] }

    @discardableResult
    public func preview(plan: EffectPlan) throws -> JobRecord {
        try validate(plan)
        let hash = try StablePlanHasher.hash(plan)
        if let existing = jobs[plan.operationID] {
            guard existing.planHash == hash else { throw JobCoordinatorError.duplicateOperation(plan.operationID) }
            switch existing.state {
            case .planned:
                return try transition(existing, to: .previewed, detail: "previewed")
            case .previewed:
                return existing
            default:
                throw JobCoordinatorError.duplicateOperation(plan.operationID)
            }
        }
        let now = Date()
        let record = JobRecord(operationID: plan.operationID, planHash: hash, effectID: plan.effectID, preconditionRevision: plan.preconditionRevision, rollbackPayloadPath: rollbackRelativePath(plan.operationID), createdAt: now, updatedAt: now)
        let payload = RollbackPayload(operationID: plan.operationID, planHash: hash, preconditionRevision: plan.preconditionRevision, sourceContentHashes: plan.selectionToken.sourceIdentities.map(\.sha256), createdAt: now)
        try persistPayload(payload, operationID: plan.operationID)
        return try transition(record, to: .previewed, detail: "previewed")
    }

    @discardableResult
    public func cancel(operationID: UUID) throws -> JobRecord {
        guard let existing = jobs[operationID] else { throw JobCoordinatorError.unknownOperation(operationID) }
        guard existing.state == .planned || existing.state == .previewed else {
            if existing.state == .cancelled { return existing }
            throw JobCoordinatorError.invalidTransition(from: existing.state, to: .cancelled)
        }
        return try transition(existing, to: .cancelled, detail: "cancelled before mutation")
    }

    @discardableResult
    public func apply(plan: EffectPlan, currentRevision: String, beforeSnapshotHash: String? = nil, mutation: @escaping @Sendable () throws -> VerifiedMutationEvidence) throws -> JobRecord {
        try apply(plan: plan, revisionProvider: { currentRevision }, beforeSnapshotHash: beforeSnapshotHash, mutation: mutation)
    }

    @discardableResult
    public func apply(plan: EffectPlan, revisionProvider: @escaping @Sendable () throws -> String, beforeSnapshotHash: String? = nil, mutation: @escaping @Sendable () throws -> VerifiedMutationEvidence) throws -> JobRecord {
        try validate(plan)
        let hash = try StablePlanHasher.hash(plan)
        let existing: JobRecord
        if let stored = jobs[plan.operationID] {
            guard stored.planHash == hash else { throw JobCoordinatorError.duplicateOperation(plan.operationID) }
            guard stored.state == .planned || stored.state == .previewed else {
                if stored.state == .cancelled { throw JobCoordinatorError.cancelled(plan.operationID) }
                throw JobCoordinatorError.duplicateOperation(plan.operationID)
            }
            existing = stored
        } else {
            let now = Date()
            existing = JobRecord(operationID: plan.operationID, planHash: hash, effectID: plan.effectID, preconditionRevision: plan.preconditionRevision, rollbackPayloadPath: rollbackRelativePath(plan.operationID), createdAt: now, updatedAt: now)
            let payload = RollbackPayload(operationID: plan.operationID, planHash: hash, preconditionRevision: plan.preconditionRevision, beforeSnapshotHash: beforeSnapshotHash, sourceContentHashes: plan.selectionToken.sourceIdentities.map(\.sha256), createdAt: now)
            try persistPayload(payload, operationID: plan.operationID)
            _ = try transition(existing, to: .planned, detail: "registered for apply")
        }

        let payload = RollbackPayload(operationID: plan.operationID, planHash: hash, preconditionRevision: plan.preconditionRevision, beforeSnapshotHash: beforeSnapshotHash, sourceContentHashes: plan.selectionToken.sourceIdentities.map(\.sha256), createdAt: existing.createdAt)
        try persistPayload(payload, operationID: plan.operationID)
        let applying = try transition(existing, to: .applying, detail: "apply started")
        guard applying.state == .applying else { throw JobCoordinatorError.invalidTransition(from: applying.state, to: .applying) }

        // This is intentionally the final coordinator action before invoking
        // the injected closure. There is no mutation-capable work between the
        // revision read and the closure call.
        let actualRevision: String
        do { actualRevision = try revisionProvider() }
        catch {
            _ = try fail(applying, error: error.localizedDescription, rollbackRequired: false)
            throw JobCoordinatorError.mutationFailed("revision provider failed: \(error.localizedDescription)")
        }
        guard actualRevision == plan.preconditionRevision else {
            _ = try fail(applying, error: JobCoordinatorError.staleRevision(expected: plan.preconditionRevision, actual: actualRevision).localizedDescription, rollbackRequired: false)
            throw JobCoordinatorError.staleRevision(expected: plan.preconditionRevision, actual: actualRevision)
        }

        let evidence: VerifiedMutationEvidence
        do { evidence = try mutation() }
        catch {
            let failed = try fail(applying, error: error.localizedDescription, rollbackRequired: true)
            _ = try transition(failed, to: .rollbackRequired, detail: "mutation failed; rollback required")
            throw JobCoordinatorError.mutationFailed(error.localizedDescription)
        }
        guard evidence.verified, !evidence.evidenceID.isEmpty, !evidence.afterSnapshotHash.isEmpty else {
            let failed = try fail(applying, error: "closure returned unverified or incomplete evidence", rollbackRequired: true)
            _ = try transition(failed, to: .rollbackRequired, detail: "verification failed; rollback required")
            throw JobCoordinatorError.verificationFailed("closure returned unverified or incomplete evidence")
        }
        var result = applying
        result.state = .applied
        result.verifiedEvidence = evidence
        result.rollbackRequired = false
        result.error = nil
        result.updatedAt = Date()
        try persistRecord(result)
        let appliedEvent = JobHistoryEvent(operationID: result.operationID, state: .applied, record: result, detail: "verified mutation evidence recorded", createdAt: result.updatedAt)
        try append(appliedEvent)
        jobs[plan.operationID] = result
        events.append(appliedEvent)
        return result
    }

    private func validate(_ plan: EffectPlan) throws {
        if let registry { try PlanValidator(registry: registry).validate(plan) }
    }

    private func transition(_ record: JobRecord, to state: JobState, detail: String) throws -> JobRecord {
        guard canTransition(from: record.state, to: state) else { throw JobCoordinatorError.invalidTransition(from: record.state, to: state) }
        var next = record
        next.state = state
        next.updatedAt = Date()
        try persistRecord(next)
        let event = JobHistoryEvent(operationID: next.operationID, state: state, record: next, detail: detail, createdAt: next.updatedAt)
        try append(event)
        jobs[next.operationID] = next
        events.append(event)
        return next
    }

    private func fail(_ record: JobRecord, error: String, rollbackRequired: Bool) throws -> JobRecord {
        var next = record
        next.error = error
        next.rollbackRequired = rollbackRequired
        return try transition(next, to: .failed, detail: error)
    }

    private func canTransition(from: JobState, to: JobState) -> Bool {
        switch (from, to) {
        case (.planned, .planned), (.planned, .previewed), (.planned, .applying), (.planned, .cancelled),
             (.previewed, .applying), (.previewed, .cancelled),
             (.applying, .applied), (.applying, .failed),
             (.failed, .rollbackRequired): return true
        default: return false
        }
    }

    private func rollbackRelativePath(_ operationID: UUID) -> String { "rollback/\(operationID.uuidString).json" }

    private func persistPayload(_ payload: RollbackPayload, operationID: UUID) throws {
        let destination = rollbackDirectory.appendingPathComponent("\(operationID.uuidString).json")
        do { _ = try pathPolicy.validateOutput(destination, overwrite: true) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        do { try encoder.encode(payload).write(to: destination, options: .atomic) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
    }

    private func persistRecord(_ record: JobRecord) throws {
        let destination = jobsDirectory.appendingPathComponent("\(record.operationID.uuidString).json")
        do { _ = try pathPolicy.validateOutput(destination, overwrite: true) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        do { try encoder.encode(record).write(to: destination, options: .atomic) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
    }

    private func append(_ event: JobHistoryEvent) throws {
        do { _ = try pathPolicy.validateOutput(historyURL, overwrite: true) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(event)
        data.append(0x0A)
        let descriptor = Darwin.open(historyURL.path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw JobCoordinatorError.persistenceFailed(String(cString: strerror(errno))) }
        defer { _ = Darwin.close(descriptor) }
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { throw JobCoordinatorError.persistenceFailed("empty history event") }
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(descriptor, base.advanced(by: offset), bytes.count - offset)
                guard written > 0 else { throw JobCoordinatorError.persistenceFailed(String(cString: strerror(errno))) }
                offset += written
            }
        }
    }

    private static func loadEvents(from url: URL) throws -> [JobHistoryEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try String(decoding: data, as: UTF8.self).split(separator: "\n").map { try decoder.decode(JobHistoryEvent.self, from: Data($0.utf8)) }
    }

    private static func loadRecord(from url: URL) throws -> JobRecord {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(JobRecord.self, from: Data(contentsOf: url))
    }
}
