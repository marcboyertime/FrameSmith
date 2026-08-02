import Foundation
import CryptoKit

public enum ContentHashError: Error, LocalizedError {
    case unreadable(URL)
    public var errorDescription: String? {
        if case .unreadable(let url) = self { return "Unable to read source for SHA-256: \(url.path)" }
        return "Unable to hash content"
    }
}

public enum ContentHasher {
    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256File(_ url: URL, chunkSize: Int = 1_048_576) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw ContentHashError.unreadable(url) }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum StablePlanHasher {
    public static func hash(_ plan: EffectPlan) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return ContentHasher.sha256(try encoder.encode(plan))
    }

    public static func hashJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return ContentHasher.sha256(try encoder.encode(value))
    }
}
