import Foundation

/// Pure draft/commit policy for continuous numeric controls.
///
/// Draft changes are intentionally side-effect free. Only `commit` returns a
/// patch suitable for authoritative plan revision, history, and rendering.
public struct ParameterDraftCommitState: Equatable, Sendable {
    public private(set) var authoritative: [String: ParameterValue]
    public private(set) var drafts: [String: ParameterValue]

    public init(authoritative: [String: ParameterValue] = [:]) {
        self.authoritative = authoritative
        self.drafts = [:]
    }

    public mutating func synchronize(name: String, authoritative value: ParameterValue) {
        authoritative[name] = value
        drafts.removeValue(forKey: name)
    }

    public mutating func updateDraft(name: String, value: ParameterValue) {
        drafts[name] = value
    }

    public func value(for name: String) -> ParameterValue? {
        drafts[name] ?? authoritative[name]
    }

    public func hasUncommittedDraft(for name: String) -> Bool {
        guard let draft = drafts[name] else { return false }
        return draft != authoritative[name]
    }

    /// Returns exactly one authoritative patch for the final value of any
    /// number of preceding draft updates.
    public mutating func commit(name: String) -> [String: ParameterValue]? {
        guard let draft = drafts.removeValue(forKey: name),
              draft != authoritative[name] else { return nil }
        authoritative[name] = draft
        return [name: draft]
    }

    public mutating func reject(name: String) {
        drafts.removeValue(forKey: name)
    }

    public mutating func discardAllDrafts() {
        drafts.removeAll()
    }
}
