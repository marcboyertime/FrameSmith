import Foundation

public enum CostPolicyError: Error, LocalizedError, Equatable {
    case invalidEstimate
    case overCeiling(Double)
    case providerApprovalRequired(String)
    case mediaUploadApprovalRequired(UUID?)
    case usageReadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEstimate: return "Cost estimate must be finite and non-negative"
        case .overCeiling(let value): return "Monthly provider budget exceeded: $\(String(format: "%.2f", value))"
        case .providerApprovalRequired(let provider): return "First use of provider requires explicit approval: \(provider)"
        case .mediaUploadApprovalRequired(let operationID): return "Media upload requires separate approval\(operationID.map { " for \($0.uuidString)" } ?? "")"
        case .usageReadFailed(let reason): return "Could not read usage ledger: \(reason)"
        }
    }
}

public struct UsageRecord: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var provider: String
    public var usd: Double
    public var approved: Bool
    public var operationID: UUID?

    public init(timestamp: Date = Date(), provider: String, usd: Double, approved: Bool, operationID: UUID? = nil) {
        self.timestamp = timestamp; self.provider = provider; self.usd = usd; self.approved = approved; self.operationID = operationID
    }
}

public struct MediaUploadApprovalRecord: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var operationID: UUID
    public var scope: String

    public init(timestamp: Date = Date(), operationID: UUID, scope: String = "operation") {
        self.timestamp = timestamp; self.operationID = operationID; self.scope = scope
    }
}

public struct ProviderApprovalRecord: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var provider: String
    public var scope: String

    public init(timestamp: Date = Date(), provider: String, scope: String = "provider-first-use") {
        self.timestamp = timestamp; self.provider = provider; self.scope = scope
    }
}

public struct CostPolicy: Sendable {
    public let monthlyCeilingUSD: Double
    public let usageURL: URL
    public let mediaUploadApprovalURL: URL
    public let providerApprovalURL: URL
    private var approvedProviders: Set<String>
    private var approvedMediaUploadOperations: Set<UUID>

    public init(monthlyCeilingUSD: Double = 20, usageURL: URL = PathPolicy.defaultOutputRoot.appendingPathComponent("usage/cost.jsonl"), approvedProviders: Set<String> = [], approvedMediaUploadOperations: Set<UUID> = [], mediaUploadApprovalURL: URL? = nil, providerApprovalURL: URL? = nil) {
        self.monthlyCeilingUSD = monthlyCeilingUSD
        self.usageURL = usageURL
        self.mediaUploadApprovalURL = mediaUploadApprovalURL ?? usageURL.deletingLastPathComponent().appendingPathComponent("media-upload-approvals.jsonl")
        self.providerApprovalURL = providerApprovalURL ?? usageURL.deletingLastPathComponent().appendingPathComponent("provider-approvals.jsonl")
        self.approvedProviders = approvedProviders
        self.approvedMediaUploadOperations = approvedMediaUploadOperations
    }

    public mutating func approveFirstProvider(_ provider: String) {
        approvedProviders.insert(provider)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        if let line = try? encoder.encode(ProviderApprovalRecord(provider: provider)) {
            try? FileManager.default.createDirectory(at: providerApprovalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: providerApprovalURL.path) { FileManager.default.createFile(atPath: providerApprovalURL.path, contents: nil) }
            if let handle = try? FileHandle(forWritingTo: providerApprovalURL) {
                _ = try? handle.seekToEnd(); _ = try? handle.write(contentsOf: line); _ = try? handle.write(contentsOf: Data([0x0a])); _ = try? handle.close()
            }
        }
    }

    /// Media approval is deliberately a separate, operation-scoped state. A
    /// provider approval never adds an operation to this set.
    public mutating func approveMediaUpload(for operationID: UUID) {
        approvedMediaUploadOperations.insert(operationID)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        if let line = try? encoder.encode(MediaUploadApprovalRecord(operationID: operationID)) {
            try? FileManager.default.createDirectory(at: mediaUploadApprovalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: mediaUploadApprovalURL.path) { FileManager.default.createFile(atPath: mediaUploadApprovalURL.path, contents: nil) }
            if let handle = try? FileHandle(forWritingTo: mediaUploadApprovalURL) {
                _ = try? handle.seekToEnd(); _ = try? handle.write(contentsOf: line); _ = try? handle.write(contentsOf: Data([0x0a])); _ = try? handle.close()
            }
        }
    }

    public func isMediaUploadApproved(for operationID: UUID) -> Bool {
        approvedMediaUploadOperations.contains(operationID)
    }

    public func estimateAllowed(_ estimate: CostEstimate, operationID: UUID? = nil, now: Date = Date()) throws {
        guard estimate.usd.isFinite, estimate.usd >= 0, (!estimate.paid || !estimate.provider.isEmpty) else { throw CostPolicyError.invalidEstimate }
        if estimate.requiresMediaUpload {
            guard let operationID, approvedMediaUploadOperations.contains(operationID) else { throw CostPolicyError.mediaUploadApprovalRequired(operationID) }
        }
        guard estimate.usd <= monthlyCeilingUSD else { throw CostPolicyError.overCeiling(estimate.usd) }
        guard estimate.paid else { return }
        guard approvedProviders.contains(estimate.provider) else { throw CostPolicyError.providerApprovalRequired(estimate.provider) }
        let total = try monthTotal(provider: estimate.provider, now: now)
        guard total + estimate.usd <= monthlyCeilingUSD else { throw CostPolicyError.overCeiling(total + estimate.usd) }
    }

    public func enforce(_ estimate: CostEstimate, operationID: UUID? = nil, now: Date = Date()) throws {
        try estimateAllowed(estimate, operationID: operationID, now: now)
        guard estimate.paid, estimate.usd > 0 else { return }
        let record = UsageRecord(timestamp: now, provider: estimate.provider, usd: estimate.usd, approved: true, operationID: operationID)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        let line = try encoder.encode(record)
        try FileManager.default.createDirectory(at: usageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: usageURL.path) { FileManager.default.createFile(atPath: usageURL.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: usageURL) else { throw CostPolicyError.usageReadFailed("cannot open usage ledger") }
        defer { try? handle.close() }
        try handle.seekToEnd(); try handle.write(contentsOf: line); try handle.write(contentsOf: Data([0x0a]))
    }

    public func monthTotal(provider: String? = nil, now: Date = Date()) throws -> Double {
        guard FileManager.default.fileExists(atPath: usageURL.path) else { return 0 }
        let data: Data
        do { data = try Data(contentsOf: usageURL) } catch { throw CostPolicyError.usageReadFailed(error.localizedDescription) }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.dateComponents([.year, .month], from: now)
        var sum = 0.0
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let record = try? decoder.decode(UsageRecord.self, from: Data(line.utf8)) else { continue }
            let components = calendar.dateComponents([.year, .month], from: record.timestamp)
            if components.year == month.year, components.month == month.month, provider == nil || provider == record.provider { sum += record.usd }
        }
        return sum
    }
}

public enum KeychainIdentifier: String, CaseIterable, Sendable {
    case providerApproval = "com.fcpcommandconsole.provider-approval"
    case modelCredential = "com.fcpcommandconsole.model-credential"
}
