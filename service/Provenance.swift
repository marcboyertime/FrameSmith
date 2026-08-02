import Foundation

public enum ProvenanceError: Error, LocalizedError, Equatable {
    case conflict(UUID)
    case staleRevision(expected: String, actual: String)
    case invalidSnapshot
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .conflict(let id): return "Operation UUID already exists with a different plan: \(id.uuidString)"
        case .staleRevision(let expected, let actual): return "Stale operation revision (expected \(expected), got \(actual))"
        case .invalidSnapshot: return "Snapshot hash is empty"
        case .writeFailed(let reason): return "Unable to write provenance: \(reason)"
        }
    }
}

public struct ProvenanceRecord: Codable, Equatable, Sendable {
    public var operation: OperationRecord
    public var sourceContentHashes: [String]
    public var notes: [String]

    public init(operation: OperationRecord, sourceContentHashes: [String] = [], notes: [String] = []) {
        self.operation = operation; self.sourceContentHashes = sourceContentHashes; self.notes = notes
    }
}

public struct ProvenanceStore: Sendable {
    public let rootURL: URL

    public init(rootURL: URL = PathPolicy.defaultOutputRoot.appendingPathComponent("provenance", isDirectory: true)) {
        self.rootURL = rootURL
    }

    public func record(_ provenance: ProvenanceRecord) throws -> ProvenanceRecord {
        guard !provenance.operation.beforeSnapshotHash.isEmpty else { throw ProvenanceError.invalidSnapshot }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let destination = rootURL.appendingPathComponent("\(provenance.operation.operationID.uuidString).json")
        if FileManager.default.fileExists(atPath: destination.path) {
            let existing = try load(operationID: provenance.operation.operationID)
            if existing.operation.planHash == provenance.operation.planHash && existing.operation.preconditionRevision == provenance.operation.preconditionRevision { return existing }
            throw ProvenanceError.conflict(provenance.operation.operationID)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(provenance)
        let temporary = destination.appendingPathExtension("tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temporary, options: .atomic)
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw ProvenanceError.writeFailed(error.localizedDescription)
        }
        return provenance
    }

    public func load(operationID: UUID) throws -> ProvenanceRecord {
        let url = rootURL.appendingPathComponent("\(operationID.uuidString).json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProvenanceRecord.self, from: Data(contentsOf: url))
    }

    public func existing(planHash: String, revision: String) throws -> ProvenanceRecord? {
        guard FileManager.default.fileExists(atPath: rootURL.path) else { return nil }
        for url in try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "json" }) {
            guard let record = try? loadURL(url), record.operation.planHash == planHash, record.operation.preconditionRevision == revision else { continue }
            return record
        }
        return nil
    }

    private func loadURL(_ url: URL) throws -> ProvenanceRecord {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProvenanceRecord.self, from: Data(contentsOf: url))
    }
}

public struct IdempotencyStore: Sendable {
    public let store: ProvenanceStore
    public init(rootURL: URL) { self.store = ProvenanceStore(rootURL: rootURL) }

    public func register(plan: EffectPlan, beforeSnapshotHash: String, expectedAfterSnapshotHash: String? = nil, sourceContentHashes: [String] = [], createdModelIdentities: [String] = [], generatedAssetHashes: [String] = [], generatedAssetParameters: [String: ParameterValue] = [:]) throws -> ProvenanceRecord {
        let hash = try StablePlanHasher.hash(plan)
        if let existing = try store.existing(planHash: hash, revision: plan.preconditionRevision) { return existing }
        // ISO-8601 JSON is intentionally second-granular for deterministic
        // idempotency comparisons across a write/read cycle.
        let now = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let operation = OperationRecord(operationID: plan.operationID, planHash: hash, preconditionRevision: plan.preconditionRevision, beforeSnapshotHash: beforeSnapshotHash, expectedAfterSnapshotHash: expectedAfterSnapshotHash, createdModelIdentities: createdModelIdentities, generatedAssetHashes: generatedAssetHashes, generatedAssetParameters: generatedAssetParameters, rollback: RollbackRecord(operationID: plan.operationID, status: .pending), createdAt: now)
        return try store.record(ProvenanceRecord(operation: operation, sourceContentHashes: sourceContentHashes))
    }
}

public typealias ProvenanceLedger = ProvenanceStore
