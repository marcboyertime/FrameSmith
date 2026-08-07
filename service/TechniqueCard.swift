import Foundation

/// How far a technique has actually been taken.
///
/// The ordering matters and the gap between the top two is the whole point:
/// a source describing a technique beautifully justifies `referenceOnly`, never
/// `validated`. Validation means *this repository* produced the construction and
/// somebody looked at the result.
public enum TechniqueCardStatus: String, Codable, CaseIterable, Sendable {
    /// Implemented through the shared construction and visually reviewed.
    case validated
    /// Implemented, but not yet verified on representative media.
    case experimental
    /// Knowledge worth retrieving. No construction exists.
    case referenceOnly = "reference_only"
    /// Known to be unavailable here — no emitter, or a contract that is not admitted.
    case unsupported

    /// Only `validated` may ever be offered to the user as executable, and even
    /// then the catalog re-checks capabilities at retrieval time.
    public var mayBeOfferedAsExecutable: Bool { self == .validated }
}

public enum TechniqueDomain: String, Codable, CaseIterable, Sendable {
    case motion, transition, look, typography, audio, safety, analysis, process
}

/// Whether a technique touches the user's edit. Anything but `none` is barred
/// from Surprise Me by construction.
public enum LockedStructureEffect: String, Codable, Sendable {
    case none
    case requiresAuthorization = "requires_authorization"
}

public enum PreviewFidelity: String, Codable, Sendable {
    /// Preview samples the same channels the export emits.
    case sharedConstruction = "shared_construction"
    /// Right shape, imprecise magnitude.
    case approximate
    /// Direction only — the magnitude is not verified. Colour is here.
    case indicative
    case none
}

public enum TechniqueBackend: String, Codable, Sendable {
    case nativeFCPXML = "native_fcpxml"
    case motionTemplate = "motion_template"
    case metal
    case externalComposition = "external_composition"
    case bakedRender = "baked_render"
    case none
}

public enum TechniqueEditability: String, Codable, Sendable {
    case finalCutNative = "final_cut_native"
    case framesmithRegeneration = "framesmith_regeneration"
    case sourceComposition = "source_composition"
    case none
}

public struct TechniqueParameter: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case float, int, bool, `enum`, point, duration }
    public enum Liveness: String, Codable, Sendable {
        case live, invariant, unsupported, unavailable
    }
    public let key: String
    public let type: Kind
    public let unit: String?
    public let range: [Double]?
    public let liveness: Liveness?
}

/// One source backing one specific claim.
///
/// `claim` is required and must be specific. "See the Final Cut manual" is not
/// provenance; "Final Cut transition movement depends on available media
/// handles" is.
public struct TechniqueProvenance: Codable, Equatable, Sendable {
    public enum Confidence: String, Codable, Sendable {
        case directEvidence = "direct_evidence"
        case officialDocumentation = "official_documentation"
        case practitionerConsensus = "practitioner_consensus"
        case singleSource = "single_source"
        case disputed
    }
    public let sourceId: String
    public let claim: String
    public let sourceRole: String?
    public let confidence: Confidence?
}

/// Disagreement between sources, kept rather than resolved away.
public struct TechniqueConflict: Codable, Equatable, Sendable {
    public let description: String
    public let sourceIds: [String]?
    public let resolution: String?
}

public struct TechniqueValidation: Codable, Equatable, Sendable {
    public let implemented: Bool
    public let visuallyVerified: Bool
    public let finalCutEvidence: [String]?
    public let verifiedOn: [String]?
    public let notes: String?
}

public struct TechniqueConstruction: Codable, Equatable, Sendable {
    public let preferredBackends: [TechniqueBackend]
    public let fallbackBackends: [String]?
    public let requiredCapabilities: [String]
    public let requiredEffectID: String?
    public let previewFidelity: PreviewFidelity
}

public struct TechniqueCost: Codable, Equatable, Sendable {
    public enum Latency: String, Codable, Sendable { case instant, seconds, minutes, long }
    public enum Monetary: String, Codable, Sendable { case free, paid }
    public enum Privacy: String, Codable, Sendable { case localOnly = "local_only", uploadsMedia = "uploads_media" }
    public let latency: Latency?
    public let monetary: Monetary?
    public let privacy: Privacy?
}

/// A compact craft record, retrieved on demand rather than loaded wholesale.
public struct TechniqueCard: Codable, Equatable, Sendable {
    public let id: String
    public let version: Int
    public let name: String
    public let domain: TechniqueDomain
    public let status: TechniqueCardStatus
    public let summary: String
    public let creativeJobs: [String]
    public let intentTags: [String]
    public let mediaPrerequisites: [String]
    public let refusalConditions: [String]?
    public let lockedStructureEffect: LockedStructureEffect
    public let construction: TechniqueConstruction
    public let parameters: [TechniqueParameter]
    public let qualityChecks: [String]
    public let failureModes: [String]
    public let safety: [String]?
    public let editability: [TechniqueEditability]
    public let expectedCost: TechniqueCost?
    public let provenance: [TechniqueProvenance]
    public let conflicts: [TechniqueConflict]?
    public let validation: TechniqueValidation
    public let notes: String?

    /// Whether this card may be shown to the user as something they can run.
    ///
    /// Three independent gates, all of which must pass. Status alone is not
    /// enough: a card validated against contracts that a later Final Cut update
    /// revoked must stop being offered without anyone editing the card.
    public func isExecutable(admittedCapabilities: Set<String>) -> Bool {
        guard status.mayBeOfferedAsExecutable else { return false }
        guard lockedStructureEffect == .none else { return false }
        return construction.requiredCapabilities.allSatisfy { admittedCapabilities.contains($0) }
    }

    /// Why the card is not executable, for showing the user an actionable
    /// reason instead of an empty option list.
    public func unavailabilityReason(admittedCapabilities: Set<String>) -> String? {
        if isExecutable(admittedCapabilities: admittedCapabilities) { return nil }
        switch status {
        case .unsupported:
            return "\(name) has no production emitter in FrameSmith yet."
        case .referenceOnly:
            return "\(name) is knowledge only — nothing implements it yet."
        case .experimental:
            return "\(name) is implemented but has not passed visual review."
        case .validated:
            if lockedStructureEffect != .none {
                return "\(name) would change your edit structure, so it is never offered automatically."
            }
            let missing = construction.requiredCapabilities.filter { !admittedCapabilities.contains($0) }
            return "\(name) needs \(missing.joined(separator: ", ")), which this Final Cut build has not admitted."
        }
    }
}
