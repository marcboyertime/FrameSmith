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
    case undoing
    case undone
}

public struct VerifiedMutationEvidence: Codable, Equatable, Sendable {
    public var evidenceID: String
    public var afterSnapshotHash: String
    public var verified: Bool
    public var details: [String]
    /// The host revision observed after a verified apply.  This is optional for
    /// backwards compatibility with older apply records, but undo requires a
    /// non-empty value so that it can refuse a stale host state.
    public var postMutationRevision: String?

    public init(evidenceID: String, afterSnapshotHash: String, verified: Bool, details: [String] = [], postMutationRevision: String? = nil) {
        self.evidenceID = evidenceID
        self.afterSnapshotHash = afterSnapshotHash
        self.verified = verified
        self.details = details
        self.postMutationRevision = postMutationRevision
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
    /// Digest of the exact persisted rollback payload bytes.  Optional keeps
    /// older job records decodable; undo rejects records that lack it.
    public var rollbackPayloadSHA256: String?
    public var verifiedEvidence: VerifiedMutationEvidence?
    /// Evidence returned by a verified undo.  Apply evidence remains intact so
    /// the original post-mutation revision and audit trail survive a restart.
    public var verifiedUndoEvidence: VerifiedMutationEvidence?
    public var error: String?
    public var rollbackRequired: Bool
    public var createdAt: Date
    public var updatedAt: Date

    /// Compatibility spelling for callers that refer to the digest as a
    /// payload hash rather than an explicit SHA-256 field.
    public var rollbackPayloadHash: String? {
        get { rollbackPayloadSHA256 }
        set { rollbackPayloadSHA256 = newValue }
    }

    public init(operationID: UUID, planHash: String, effectID: EffectID, state: JobState = .planned, preconditionRevision: String, rollbackPayloadPath: String, verifiedEvidence: VerifiedMutationEvidence? = nil, error: String? = nil, rollbackRequired: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date(), rollbackPayloadSHA256: String? = nil, verifiedUndoEvidence: VerifiedMutationEvidence? = nil) {
        self.operationID = operationID
        self.planHash = planHash
        self.effectID = effectID
        self.state = state
        self.preconditionRevision = preconditionRevision
        self.rollbackPayloadPath = rollbackPayloadPath
        self.rollbackPayloadSHA256 = rollbackPayloadSHA256
        self.verifiedEvidence = verifiedEvidence
        self.verifiedUndoEvidence = verifiedUndoEvidence
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
    case undoUnavailable(String)
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
        case .undoUnavailable(let reason): return "Undo is unavailable: \(reason)"
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
            try Self.recoverInterruptedUndoStates(jobs: &self.jobs, events: &self.events, pathPolicy: policy, jobsDirectory: jobs, historyURL: self.historyURL)
        } catch {
            throw JobCoordinatorError.persistenceFailed("history or job record is unreadable: \(error.localizedDescription)")
        }
    }

    public func history() -> [JobHistoryEvent] { events }

    public func record(operationID: UUID) -> JobRecord? { jobs[operationID] }

    /// Read-only preflight used by the command panel.  The payload is always
    /// read from disk so an in-memory record cannot accidentally authorize an
    /// undo after a restart or payload replacement.
    public func canUndo(operationID: UUID, currentRevision: String) -> Bool {
        guard let record = jobs[operationID], record.state == .applied else { return false }
        do {
            _ = try validatedUndoContext(record: record, currentRevision: currentRevision)
            return true
        } catch {
            return false
        }
    }

    /// Alias retained for callers that name this gate as availability rather
    /// than capability.
    public func undoAvailable(operationID: UUID, currentRevision: String) -> Bool {
        canUndo(operationID: operationID, currentRevision: currentRevision)
    }

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
        var record = JobRecord(operationID: plan.operationID, planHash: hash, effectID: plan.effectID, preconditionRevision: plan.preconditionRevision, rollbackPayloadPath: rollbackRelativePath(plan.operationID), createdAt: now, updatedAt: now)
        let payload = RollbackPayload(operationID: plan.operationID, planHash: hash, preconditionRevision: plan.preconditionRevision, sourceContentHashes: plan.selectionToken.sourceIdentities.map(\.sha256), createdAt: now)
        record.rollbackPayloadSHA256 = try persistPayload(payload, operationID: plan.operationID)
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
        var existing: JobRecord
        var isNew = false
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
            existing.rollbackPayloadSHA256 = try persistPayload(payload, operationID: plan.operationID)
            isNew = true
        }

        let payload = RollbackPayload(operationID: plan.operationID, planHash: hash, preconditionRevision: plan.preconditionRevision, beforeSnapshotHash: beforeSnapshotHash, sourceContentHashes: plan.selectionToken.sourceIdentities.map(\.sha256), createdAt: existing.createdAt)
        existing.rollbackPayloadSHA256 = try persistPayload(payload, operationID: plan.operationID)
        if isNew {
            _ = try transition(existing, to: .planned, detail: "registered for apply")
        }
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

    /// Undo a verified, revision-bound apply.  This overload is convenient for
    /// offline callers that already have a single current revision value.
    @discardableResult
    public func undo(operationID: UUID, currentRevision: String, mutation: @escaping @Sendable (JobRecord) throws -> VerifiedMutationEvidence) throws -> JobRecord {
        try undo(operationID: operationID, revisionProvider: { currentRevision }, mutation: mutation)
    }

    /// Undo a plan only when its persisted operation and plan hash still agree.
    /// The plan overload prevents a caller from using a record for a different
    /// plan with the same operation identifier.
    @discardableResult
    public func undo(plan: EffectPlan, currentRevision: String, mutation: @escaping @Sendable (JobRecord) throws -> VerifiedMutationEvidence) throws -> JobRecord {
        try undo(plan: plan, revisionProvider: { currentRevision }, mutation: mutation)
    }

    @discardableResult
    public func undo(plan: EffectPlan, revisionProvider: @escaping @Sendable () throws -> String, mutation: @escaping @Sendable (JobRecord) throws -> VerifiedMutationEvidence) throws -> JobRecord {
        let hash = try StablePlanHasher.hash(plan)
        guard let record = jobs[plan.operationID] else { throw JobCoordinatorError.unknownOperation(plan.operationID) }
        guard record.planHash == hash else { throw JobCoordinatorError.duplicateOperation(plan.operationID) }
        return try undo(operationID: plan.operationID, revisionProvider: revisionProvider, mutation: mutation)
    }

    /// Perform a restart-safe, fail-closed undo transition.  No native host
    /// call is made here; the injected closure is the future adapter boundary.
    @discardableResult
    public func undo(operationID: UUID, revisionProvider: @escaping @Sendable () throws -> String, mutation: @escaping @Sendable (JobRecord) throws -> VerifiedMutationEvidence) throws -> JobRecord {
        guard let existing = jobs[operationID] else { throw JobCoordinatorError.unknownOperation(operationID) }
        if existing.state == .undone { return existing }
        guard existing.state == .applied else {
            throw JobCoordinatorError.undoUnavailable("operation is \(existing.state.rawValue), not applied")
        }

        // Validate all gates and re-read the confined rollback payload before
        // making an irreversible lifecycle transition.
        let initialContext = try validatedUndoContext(record: existing, revisionProvider: revisionProvider)
        let undoing = try transition(existing, to: .undoing, detail: "undo started")
        guard undoing.state == .undoing else {
            throw JobCoordinatorError.invalidTransition(from: undoing.state, to: .undoing)
        }

        // This is intentionally the final coordinator action before invoking
        // the injected closure.  A host revision change at this point denies
        // the undo without calling the closure.
        let finalRevision: String
        do {
            finalRevision = try revisionProvider()
        } catch {
            let reason = "revision provider failed: \(error.localizedDescription)"
            _ = try fail(undoing, error: reason, rollbackRequired: false)
            throw JobCoordinatorError.undoUnavailable(reason)
        }
        guard finalRevision == initialContext.postMutationRevision else {
            _ = try fail(undoing, error: JobCoordinatorError.staleRevision(expected: initialContext.postMutationRevision, actual: finalRevision).localizedDescription, rollbackRequired: false)
            throw JobCoordinatorError.staleRevision(expected: initialContext.postMutationRevision, actual: finalRevision)
        }

        let evidence: VerifiedMutationEvidence
        do {
            evidence = try mutation(undoing)
        } catch {
            _ = try fail(undoing, error: error.localizedDescription, rollbackRequired: true)
            _ = try transition(jobs[operationID] ?? undoing, to: .rollbackRequired, detail: "undo failed; rollback required")
            throw JobCoordinatorError.mutationFailed(error.localizedDescription)
        }

        guard evidence.verified, !evidence.evidenceID.isEmpty, !evidence.afterSnapshotHash.isEmpty else {
            let reason = "undo closure returned unverified or incomplete evidence"
            _ = try fail(undoing, error: reason, rollbackRequired: true)
            _ = try transition(jobs[operationID] ?? undoing, to: .rollbackRequired, detail: "undo verification failed; rollback required")
            throw JobCoordinatorError.verificationFailed(reason)
        }
        guard evidence.afterSnapshotHash == initialContext.beforeSnapshotHash else {
            let reason = "undo restored snapshot hash does not match the persisted before snapshot"
            _ = try fail(undoing, error: reason, rollbackRequired: true)
            _ = try transition(jobs[operationID] ?? undoing, to: .rollbackRequired, detail: "undo restored the wrong snapshot; rollback required")
            throw JobCoordinatorError.verificationFailed(reason)
        }

        var result = undoing
        result.state = .undone
        result.verifiedUndoEvidence = evidence
        result.rollbackRequired = false
        result.error = nil
        result.updatedAt = Date()
        try persistRecord(result)
        let event = JobHistoryEvent(operationID: result.operationID, state: .undone, record: result, detail: "verified undo evidence recorded", createdAt: result.updatedAt)
        try append(event)
        jobs[operationID] = result
        events.append(event)
        return result
    }

    private struct ValidatedUndoContext: Sendable {
        let beforeSnapshotHash: String
        let postMutationRevision: String
    }

    private func validatedUndoContext(record: JobRecord, currentRevision: String) throws -> ValidatedUndoContext {
        guard let evidence = record.verifiedEvidence else {
            throw JobCoordinatorError.undoUnavailable("no verified apply evidence is recorded")
        }
        guard evidence.verified, !evidence.evidenceID.isEmpty, !evidence.afterSnapshotHash.isEmpty else {
            throw JobCoordinatorError.undoUnavailable("apply evidence is incomplete or unverified")
        }
        guard let postMutationRevision = evidence.postMutationRevision,
              !postMutationRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JobCoordinatorError.undoUnavailable("verified apply evidence has no post-mutation revision")
        }

        let payload = try loadAndValidateRollbackPayload(for: record)
        guard let beforeSnapshotHash = payload.beforeSnapshotHash,
              !beforeSnapshotHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JobCoordinatorError.undoUnavailable("rollback payload has no complete before snapshot hash")
        }
        guard currentRevision == postMutationRevision else {
            throw JobCoordinatorError.staleRevision(expected: postMutationRevision, actual: currentRevision)
        }
        return ValidatedUndoContext(beforeSnapshotHash: beforeSnapshotHash, postMutationRevision: postMutationRevision)
    }

    private func validatedUndoContext(record: JobRecord, revisionProvider: @escaping @Sendable () throws -> String) throws -> ValidatedUndoContext {
        let currentRevision: String
        do {
            currentRevision = try revisionProvider()
        } catch {
            throw JobCoordinatorError.undoUnavailable("current revision could not be read: \(error.localizedDescription)")
        }
        return try validatedUndoContext(record: record, currentRevision: currentRevision)
    }

    private func loadAndValidateRollbackPayload(for record: JobRecord) throws -> RollbackPayload {
        let rawPath = record.rollbackPayloadPath
        guard !rawPath.isEmpty, !rawPath.hasPrefix("/"), !rawPath.split(separator: "/").contains(".."),
              !rawPath.unicodeScalars.contains(where: { ";&|`$()<>*?{}\n\r".unicodeScalars.contains($0) }) else {
            throw JobCoordinatorError.undoUnavailable("rollback payload path is not a confined relative path")
        }
        let destination = runtimeRoot.appendingPathComponent(rawPath, isDirectory: false).standardizedFileURL
        guard isDescendant(destination, of: rollbackDirectory) else {
            throw JobCoordinatorError.undoUnavailable("rollback payload path escapes the rollback directory")
        }
        guard FileManager.default.fileExists(atPath: destination.path),
              (try? destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw JobCoordinatorError.undoUnavailable("rollback payload is missing or symlinked")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: destination.path) else {
            throw JobCoordinatorError.undoUnavailable("rollback payload is not a readable regular file")
        }
        let resolved = destination.resolvingSymlinksInPath().standardizedFileURL
        guard isDescendant(resolved, of: rollbackDirectory.resolvingSymlinksInPath().standardizedFileURL) else {
            throw JobCoordinatorError.undoUnavailable("rollback payload resolves outside the rollback directory")
        }
        do { _ = try pathPolicy.validateOutput(destination, overwrite: true) }
        catch { throw JobCoordinatorError.undoUnavailable("rollback payload path is invalid: \(error.localizedDescription)") }

        guard let expectedDigest = record.rollbackPayloadSHA256,
              expectedDigest.count == 64, isLowerHex(expectedDigest) else {
            throw JobCoordinatorError.undoUnavailable("rollback payload digest is missing from the job record")
        }
        let data: Data
        do { data = try Data(contentsOf: destination) }
        catch { throw JobCoordinatorError.undoUnavailable("rollback payload is unreadable: \(error.localizedDescription)") }
        guard ContentHasher.sha256(data) == expectedDigest else {
            throw JobCoordinatorError.undoUnavailable("rollback payload digest does not match the persisted job record")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: RollbackPayload
        do {
            payload = try decoder.decode(RollbackPayload.self, from: data)
        } catch {
            throw JobCoordinatorError.undoUnavailable("rollback payload is unreadable: \(error.localizedDescription)")
        }
        guard payload.operationID == record.operationID else {
            throw JobCoordinatorError.undoUnavailable("rollback payload operation identifier does not match the job")
        }
        guard payload.planHash == record.planHash else {
            throw JobCoordinatorError.undoUnavailable("rollback payload plan hash does not match the job")
        }
        guard payload.preconditionRevision == record.preconditionRevision else {
            throw JobCoordinatorError.undoUnavailable("rollback payload precondition revision does not match the job")
        }
        guard !payload.sourceContentHashes.isEmpty,
              payload.sourceContentHashes.allSatisfy({ $0.count == 64 && isLowerHex($0) }) else {
            throw JobCoordinatorError.undoUnavailable("rollback payload source content hashes are incomplete or not canonical SHA-256")
        }
        return payload
    }

    private static func recoverInterruptedUndoStates(jobs: inout [UUID: JobRecord], events: inout [JobHistoryEvent], pathPolicy: PathPolicy, jobsDirectory: URL, historyURL: URL) throws {
        let interrupted = jobs.values.filter { $0.state == .undoing }
        for record in interrupted {
            var recovered = record
            recovered.state = .rollbackRequired
            recovered.rollbackRequired = true
            recovered.error = "undo was interrupted before verified completion; rollback is required"
            recovered.updatedAt = Date()
            let destination = jobsDirectory.appendingPathComponent("\(recovered.operationID.uuidString).json")
            do { _ = try pathPolicy.validateOutput(destination, overwrite: true) }
            catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
            do { try encoder.encode(recovered).write(to: destination, options: .atomic) }
            catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
            let event = JobHistoryEvent(operationID: recovered.operationID, state: .rollbackRequired, record: recovered, detail: "recovered interrupted undo; rollback required", createdAt: recovered.updatedAt)
            do { _ = try pathPolicy.validateOutput(historyURL, overwrite: true) }
            catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
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
            jobs[recovered.operationID] = recovered
            events.append(event)
        }
    }

    private func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path.hasSuffix("/") ? candidate.standardizedFileURL.path : candidate.standardizedFileURL.path + "/"
        let rootPath = root.standardizedFileURL.path.hasSuffix("/") ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath)
    }

    private func isLowerHex(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 97...102: return true
            default: return false
            }
        }
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
             (.failed, .rollbackRequired),
             (.applied, .undoing), (.undoing, .failed), (.undoing, .rollbackRequired): return true
        default: return false
        }
    }

    private func rollbackRelativePath(_ operationID: UUID) -> String { "rollback/\(operationID.uuidString).json" }

    @discardableResult
    private func persistPayload(_ payload: RollbackPayload, operationID: UUID) throws -> String {
        let destination = rollbackDirectory.appendingPathComponent("\(operationID.uuidString).json")
        do { _ = try pathPolicy.validateOutput(destination, overwrite: true) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do { data = try encoder.encode(payload) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
        do { try data.write(to: destination, options: .atomic) }
        catch { throw JobCoordinatorError.persistenceFailed(error.localizedDescription) }
        return ContentHasher.sha256(data)
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
