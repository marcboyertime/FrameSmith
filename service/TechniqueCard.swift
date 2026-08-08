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
    public let defaultValue: ParameterValue?
    public let liveness: Liveness?

    private enum CodingKeys: String, CodingKey { case key, type, unit, range, defaultValue = "default", liveness }
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

/// A machine-evaluable fact about the media and target currently presented to
/// a technique. Prose in a card explains the rule; this value is the part that
/// admission is allowed to act on. There is deliberately no catch-all string
/// rule: a rule we cannot evaluate is not an executable precondition.
public struct TechniqueRule: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case mediaKind = "media_kind", requiredRole = "required_role", roleCount = "role_count", audioPresence = "audio_presence", minDimensions = "min_dimensions", confirmedTarget = "confirmed_target" }
    public let kind: Kind
    public let mediaKind: LocalMediaKind?
    public let role: LocalMediaRole?
    public let count: Int?
    public let hasAudio: Bool?
    public let minWidth: Int?
    public let minHeight: Int?

    public init(kind: Kind, mediaKind: LocalMediaKind? = nil, role: LocalMediaRole? = nil, count: Int? = nil, hasAudio: Bool? = nil, minWidth: Int? = nil, minHeight: Int? = nil) {
        self.kind = kind; self.mediaKind = mediaKind; self.role = role; self.count = count; self.hasAudio = hasAudio; self.minWidth = minWidth; self.minHeight = minHeight
    }
}

public enum TechniqueDecision: String, Codable, Equatable, Sendable { case allowedAutomatically = "allowed_automatically", refused, requiresUserApproval = "requires_user_approval" }
public enum TechniqueRiskLevel: String, Codable, Equatable, Sendable { case low, moderate, high, critical }
public enum TechniqueRiskCategory: String, Codable, CaseIterable, Sendable { case visualQuality = "visual_quality", photosensitiveFlash = "photosensitive_flash", accessibility, privacy, editorialIntegrity = "editorial_integrity", contentSafety = "content_safety" }

/// A declared risk or safety gate. It has a category, severity, and an
/// explicit decision, rather than asking runtime code to infer safety from a
/// sentence. Approval is category-scoped and must be supplied at admission.
public struct TechniqueRiskGate: Codable, Equatable, Sendable {
    public let category: TechniqueRiskCategory
    public let level: TechniqueRiskLevel
    public let decision: TechniqueDecision
    /// Concrete repository evidence for this classification. It is immutable
    /// card data, not a runtime inference from a marketing label.
    public let basis: String
    public init(category: TechniqueRiskCategory, level: TechniqueRiskLevel, decision: TechniqueDecision, basis: String) { self.category = category; self.level = level; self.decision = decision; self.basis = basis }
}

public struct TechniqueEvaluationContext: Sendable {
    public let media: [LocalMediaRole: LocalMediaAsset]
    public let target: Target?
    public let approvedRiskCategories: Set<TechniqueRiskCategory>
    public init(media: [LocalMediaRole: LocalMediaAsset], target: Target?, approvedRiskCategories: Set<TechniqueRiskCategory> = []) { self.media = media; self.target = target; self.approvedRiskCategories = approvedRiskCategories }
}

public enum TechniqueRuleOutcome: String, Codable, Equatable, Sendable { case satisfied, triggered, notTriggered, unknown }
public struct TechniqueRuleDecision: Codable, Equatable, Sendable {
    public let rule: TechniqueRule
    public let outcome: TechniqueRuleOutcome
    public let decision: TechniqueDecision
}
public struct TechniqueRiskDecision: Codable, Equatable, Sendable {
    public let gate: TechniqueRiskGate
    public let decision: TechniqueDecision
}
public struct TechniqueCardEvaluation: Codable, Equatable, Sendable {
    public let prerequisiteDecisions: [TechniqueRuleDecision]
    public let refusalDecisions: [TechniqueRuleDecision]
    public let riskDecisions: [TechniqueRiskDecision]
    public let safetyDecisions: [TechniqueRiskDecision]
    public var executableDecision: TechniqueDecision {
        let decisions = prerequisiteDecisions.map(\.decision) + refusalDecisions.map(\.decision) + riskDecisions.map(\.decision) + safetyDecisions.map(\.decision)
        if decisions.contains(.refused) { return .refused }
        if decisions.contains(.requiresUserApproval) { return .requiresUserApproval }
        return .allowedAutomatically
    }
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
    public let prerequisiteRules: [TechniqueRule]
    public let refusalRules: [TechniqueRule]
    public let lockedStructureEffect: LockedStructureEffect
    public let construction: TechniqueConstruction
    public let parameters: [TechniqueParameter]
    public let qualityChecks: [String]
    public let failureModes: [String]
    public let safety: [String]?
    public let riskGates: [TechniqueRiskGate]
    public let safetyGates: [TechniqueRiskGate]
    public let editability: [TechniqueEditability]
    public let expectedCost: TechniqueCost?
    public let provenance: [TechniqueProvenance]
    public let conflicts: [TechniqueConflict]?
    public let validation: TechniqueValidation
    public let notes: String?

    /// A normalized view used only for broad retrieval. Admission never uses
    /// these prose-derived values; it evaluates `prerequisiteRules` instead.
    public var requiredMediaKinds: Set<LocalMediaKind> {
        Set(mediaPrerequisites.compactMap { text in
            let lower = text.lowercased()
            if lower.contains("still") || lower.contains("image") { return .still }
            if lower.contains("movie") || lower.contains("video") || lower.contains("clip") { return .movie }
            return nil
        })
    }

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

    public func evaluate(in context: TechniqueEvaluationContext) -> TechniqueCardEvaluation {
        let prerequisites = prerequisiteRules.map { rule in
            let met = evaluate(rule, in: context)
            return TechniqueRuleDecision(rule: rule, outcome: met ? .satisfied : .unknown, decision: met ? .allowedAutomatically : .refused)
        }
        let refusals = refusalRules.map { rule in
            let triggered = evaluate(rule, in: context)
            return TechniqueRuleDecision(rule: rule, outcome: triggered ? .triggered : .notTriggered, decision: triggered ? .refused : .allowedAutomatically)
        }
        func decisions(_ gates: [TechniqueRiskGate]) -> [TechniqueRiskDecision] {
            gates.map { gate in
                let decision: TechniqueDecision
                switch gate.decision {
                case .allowedAutomatically: decision = .allowedAutomatically
                case .refused: decision = .refused
                case .requiresUserApproval: decision = context.approvedRiskCategories.contains(gate.category) ? .allowedAutomatically : .requiresUserApproval
                }
                return TechniqueRiskDecision(gate: gate, decision: decision)
            }
        }
        return TechniqueCardEvaluation(prerequisiteDecisions: prerequisites, refusalDecisions: refusals, riskDecisions: decisions(riskGates), safetyDecisions: decisions(safetyGates))
    }

    private func evaluate(_ rule: TechniqueRule, in context: TechniqueEvaluationContext) -> Bool {
        switch rule.kind {
        case .mediaKind:
            guard let kind = rule.mediaKind else { return false }
            if let role = rule.role { return context.media[role]?.kind == kind }
            return context.media.values.contains { $0.kind == kind }
        case .requiredRole:
            guard let role = rule.role else { return false }; return context.media[role] != nil
        case .roleCount:
            guard let count = rule.count, count >= 0 else { return false }
            if let role = rule.role { return context.media[role] != nil && count <= 1 }
            return context.media.count >= count
        case .audioPresence:
            guard let hasAudio = rule.hasAudio else { return false }
            if let role = rule.role { return context.media[role]?.hasAudio == hasAudio }
            return context.media.values.contains { $0.hasAudio == hasAudio }
        case .minDimensions:
            guard let width = rule.minWidth, let height = rule.minHeight, width > 0, height > 0 else { return false }
            let assets = rule.role.flatMap { context.media[$0] }.map { [$0] } ?? Array(context.media.values)
            return !assets.isEmpty && assets.allSatisfy { $0.dimensions.width >= width && $0.dimensions.height >= height }
        case .confirmedTarget:
            guard let target = context.target else { return false }
            return target.confirmed && target.isInNormalizedBounds && target.coordinateSpace == "normalized-frame"
        }
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
