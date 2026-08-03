import Foundation

/// A deterministic, per-role generation counter for UI coordinators. A result
/// may be applied only when its token still matches the latest request for the
/// same role; cancellation advances the generation to make in-flight results
/// stale without relying on timing.
public struct LocalMediaOperationGeneration: Sendable {
    private var values: [LocalMediaRole: UInt64] = [:]

    public init() {}

    public mutating func begin(_ role: LocalMediaRole) -> UInt64 {
        let next = (values[role] ?? 0) &+ 1
        values[role] = next
        return next
    }

    public mutating func cancel(_ role: LocalMediaRole) {
        _ = begin(role)
    }

    public mutating func cancelAll() {
        for role in LocalMediaRole.allCases { cancel(role) }
    }

    public func isCurrent(_ token: UInt64, for role: LocalMediaRole) -> Bool {
        values[role] == token
    }
}
