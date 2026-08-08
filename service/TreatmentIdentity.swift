import Foundation

/// Canonical identities used for options and admitted constructions.  These are
/// intentionally text based and sort every unordered collection before hashing;
/// Swift's `Hasher`, dictionary iteration, UUID generation, and clock time are
/// never part of an option identity.
public enum TreatmentIdentity {
    public static func digest(_ fields: [String]) -> String { ContentHasher.sha256(Data(fields.joined(separator: "\u{1e}").utf8)) }
    public static func optionID(seed: UInt64, fingerprint: String, cardIDs: [String], plan: EffectPlan) -> String {
        digest(["option", String(seed), fingerprint, cardIDs.sorted().joined(separator: ","), constructionSignature(for: plan)])
    }
    public static func stableUUID(from digest: String) -> UUID {
        let raw = String(digest.prefix(32))
        let value = "\(raw.prefix(8))-\(raw.dropFirst(8).prefix(4))-\(raw.dropFirst(12).prefix(4))-\(raw.dropFirst(16).prefix(4))-\(raw.dropFirst(20).prefix(12))"
        return UUID(uuidString: value) ?? UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    }
    public static func constructionSignature(for plan: EffectPlan, channels: [String] = []) -> String {
        let parameters = plan.parameters.keys.sorted().map { key in "\(key)=\(canonical(plan.parameters[key]!))" }.joined(separator: "|")
        let sources = plan.selectionToken.sourceIdentities.map { "\($0.itemID)@\($0.canonicalPath)#\($0.sha256)" }.joined(separator: "|")
        let target = plan.normalizedPoint.map { "\($0.x.bitPattern),\($0.y.bitPattern),\($0.coordinateSpace),\($0.confirmed)" } ?? "none"
        return digest(["construction", plan.effectID.rawValue, plan.representation.rawValue, parameters, sources, target, channels.sorted().joined(separator: "|")])
    }
    private static func canonical(_ value: ParameterValue) -> String {
        switch value {
        case .number(let n): return "n:\(n.bitPattern)"
        case .integer(let n): return "i:\(n)"
        case .boolean(let b): return "b:\(b)"
        case .string(let s): return "s:\(s)"
        case .object(let values): return "o:{" + values.keys.sorted().map { "\($0)=\(canonical(values[$0]!))" }.joined(separator: ",") + "}"
        case .array(let values): return "a:[" + values.map(canonical).joined(separator: ",") + "]"
        case .null: return "null"
        }
    }
}
