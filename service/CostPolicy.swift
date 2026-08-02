import Foundation

public enum CostPolicyError: Error, LocalizedError, Equatable {
    case invalidEstimate
    case overCeiling(Double)
    case providerApprovalRequired(String)
    case usageReadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEstimate: return "Cost estimate must be finite and non-negative"
        case .overCeiling(let value): return "Monthly provider budget exceeded: $\(String(format: "%.2f", value))"
        case .providerApprovalRequired(let provider): return "First use of provider requires explicit approval: \(provider)"
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

public struct CostPolicy: Sendable {
    public let monthlyCeilingUSD: Double
    public let usageURL: URL
    private var approvedProviders: Set<String>

    public init(monthlyCeilingUSD: Double = 20, usageURL: URL = PathPolicy.defaultOutputRoot.appendingPathComponent("usage/cost.jsonl"), approvedProviders: Set<String> = []) {
        self.monthlyCeilingUSD = monthlyCeilingUSD
        self.usageURL = usageURL
        self.approvedProviders = approvedProviders
    }

    public mutating func approveFirstProvider(_ provider: String) {
        approvedProviders.insert(provider)
    }

    public func estimateAllowed(_ estimate: CostEstimate, now: Date = Date()) throws {
        guard estimate.usd.isFinite, estimate.usd >= 0, (!estimate.paid || !estimate.provider.isEmpty) else { throw CostPolicyError.invalidEstimate }
        guard estimate.usd <= monthlyCeilingUSD else { throw CostPolicyError.overCeiling(estimate.usd) }
        guard estimate.paid else { return }
        guard approvedProviders.contains(estimate.provider) else { throw CostPolicyError.providerApprovalRequired(estimate.provider) }
        let total = try monthTotal(provider: estimate.provider, now: now)
        guard total + estimate.usd <= monthlyCeilingUSD else { throw CostPolicyError.overCeiling(total + estimate.usd) }
    }

    public func enforce(_ estimate: CostEstimate, operationID: UUID? = nil, now: Date = Date()) throws {
        try estimateAllowed(estimate, now: now)
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
