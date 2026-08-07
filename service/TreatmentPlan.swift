import Foundation

/// How strongly the user wants the treatment to read.
public enum TreatmentIntensity: String, Codable, CaseIterable, Sendable {
    case barelyThere = "barely_there"
    case restrained
    case present
    case strong
    case bold
}

/// A creative dimension a treatment can act on.
///
/// Two options are only meaningfully different if they differ on at least two
/// of these. Different names, seeds, or slider nudges are not diversity, and
/// enumerating the axes is what makes that rule checkable rather than a
/// judgement call.
public enum TreatmentDimension: String, Codable, CaseIterable, Sendable {
    case motionLanguage = "motion_language"
    case transitionMechanism = "transition_mechanism"
    case spatialDepthMethod = "spatial_depth_method"
    case paletteContrast = "palette_contrast"
    case texture
    case typography
    case soundTreatment = "sound_treatment"
    case representation
}

/// The user's wording and what it was understood to mean, kept separately.
///
/// The original phrasing survives every revision. "Less magical, but keep the
/// depth" has to be able to revise the atmosphere reading without touching the
/// depth reading, which is impossible once poetic language has been collapsed
/// into a single preset.
public struct TreatmentIntent: Codable, Equatable, Sendable {
    /// Exactly what the user typed. Never normalized, never overwritten.
    public let originalWording: String
    public var emotional: String?
    public var motion: String?
    public var transition: String?
    public var colorLook: String?
    public var texture: String?
    public var typography: String?
    public var sound: String?
    public var intensity: TreatmentIntensity
    /// Readings the planner considered but did not choose, kept so a later
    /// "no, more like X" can promote one instead of starting over.
    public var alternateReadings: [String]
    /// Things the user asked to keep untouched, in their words.
    public var preservationRequests: [String]
    /// Things the user explicitly ruled out.
    public var prohibitedChanges: [String]

    public init(
        originalWording: String,
        emotional: String? = nil,
        motion: String? = nil,
        transition: String? = nil,
        colorLook: String? = nil,
        texture: String? = nil,
        typography: String? = nil,
        sound: String? = nil,
        intensity: TreatmentIntensity = .restrained,
        alternateReadings: [String] = [],
        preservationRequests: [String] = [],
        prohibitedChanges: [String] = []
    ) {
        self.originalWording = originalWording
        self.emotional = emotional
        self.motion = motion
        self.transition = transition
        self.colorLook = colorLook
        self.texture = texture
        self.typography = typography
        self.sound = sound
        self.intensity = intensity
        self.alternateReadings = alternateReadings
        self.preservationRequests = preservationRequests
        self.prohibitedChanges = prohibitedChanges
    }
}

/// What the user gets to change afterwards, stated rather than implied.
public enum TreatmentEditability: String, Codable, Sendable {
    case finalCutNative = "final_cut_native"
    case framesmithRegeneration = "framesmith_regeneration"
    case fixed
}

public enum TreatmentAdmissionError: Error, LocalizedError, Equatable, Sendable {
    case structureDrifted(String)
    case cardNotExecutable(String, reason: String)
    case cardUnknown(String)
    case effectPlanRejected(String)
    case unapprovedCost(String)
    case structureTouchingTechnique(String)

    public var errorDescription: String? {
        switch self {
        case .structureDrifted(let detail): return "The editorial structure changed after this treatment was planned: \(detail)"
        case .cardNotExecutable(let id, let reason): return "Technique \(id) cannot run: \(reason)"
        case .cardUnknown(let id): return "Technique \(id) is not in the catalog"
        case .effectPlanRejected(let detail): return "The underlying effect plan was rejected: \(detail)"
        case .unapprovedCost(let detail): return "This treatment needs approval first: \(detail)"
        case .structureTouchingTechnique(let id): return "Technique \(id) would change your edit, so it cannot be applied as a treatment"
        }
    }
}

/// A semantic treatment: what the user meant, how it will be achieved, and what
/// it is allowed to touch.
///
/// This sits **above** `EffectPlan` rather than replacing it. The effect plan
/// carries validated parameters and drives the shared emitter construction; the
/// treatment plan carries meaning, provenance, and the editorial constraints
/// that make the whole thing safe. Destroying the effect plan would throw away
/// the admission, registry, and FCPXML evidence systems that took Phase 1 to
/// build.
public struct TreatmentPlan: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    /// Ties this treatment to the exact editorial structure it was planned
    /// against. Verified again before preview and before export.
    public let structureFingerprint: String
    public var intent: TreatmentIntent
    /// A short creative name, for the option card.
    public var name: String
    /// One sentence describing the idea.
    public var idea: String
    /// Plain-language descriptions of what changes. Three to six of them.
    public var changes: [String]
    /// What is explicitly preserved, for the user-facing card.
    public var preserved: [String]
    public var techniqueCardIDs: [String]
    /// The concrete, validated effect plan this treatment executes through.
    public var effectPlan: EffectPlan
    public var editability: TreatmentEditability
    public var previewFidelity: PreviewFidelity
    /// Which dimensions this treatment acts on. Diversity is measured on these.
    public var dimensions: Set<TreatmentDimension>
    public var estimatedLatency: TechniqueCost.Latency
    public var monetary: TechniqueCost.Monetary
    public var privacy: TechniqueCost.Privacy
    /// Card IDs plus the sources behind their claims, for the advanced view.
    public var provenanceSummary: [String]

    public init(
        id: UUID = UUID(),
        structureFingerprint: String,
        intent: TreatmentIntent,
        name: String,
        idea: String,
        changes: [String],
        preserved: [String] = [],
        techniqueCardIDs: [String],
        effectPlan: EffectPlan,
        editability: TreatmentEditability,
        previewFidelity: PreviewFidelity,
        dimensions: Set<TreatmentDimension>,
        estimatedLatency: TechniqueCost.Latency = .instant,
        monetary: TechniqueCost.Monetary = .free,
        privacy: TechniqueCost.Privacy = .localOnly,
        provenanceSummary: [String] = []
    ) {
        self.id = id
        self.structureFingerprint = structureFingerprint
        self.intent = intent
        self.name = name
        self.idea = idea
        self.changes = changes
        self.preserved = preserved
        self.techniqueCardIDs = techniqueCardIDs
        self.effectPlan = effectPlan
        self.editability = editability
        self.previewFidelity = previewFidelity
        self.dimensions = dimensions
        self.estimatedLatency = estimatedLatency
        self.monetary = monetary
        self.privacy = privacy
        self.provenanceSummary = provenanceSummary
    }

    /// Revises one semantic dimension without disturbing the others.
    ///
    /// This is the point of keeping intent as separate fields: "less magical,
    /// but keep the depth" adjusts `emotional` and `intensity` while leaving
    /// `motion` alone. A single collapsed preset cannot express that.
    /// `originalWording` is `let`, so a revision physically cannot overwrite
    /// what the user actually said — only the derived readings move.
    public func revising(_ change: (inout TreatmentIntent) -> Void) -> TreatmentPlan {
        var copy = self
        change(&copy.intent)
        return copy
    }

    /// Material difference on at least two dimensions.
    ///
    /// Deliberately not "any difference": two options that vary only in
    /// intensity along one axis are the same idea twice, and offering them as a
    /// choice wastes the user's attention.
    public func differsMaterially(from other: TreatmentPlan) -> Bool {
        dimensions.symmetricDifference(other.dimensions).count >= 2
            || (dimensions != other.dimensions && Set(techniqueCardIDs) != Set(other.techniqueCardIDs)
                && dimensions.symmetricDifference(other.dimensions).count >= 1
                && effectPlan.effectID != other.effectPlan.effectID)
    }
}

/// Revalidates everything before a treatment is allowed to produce output.
///
/// Called before preview and again before export, because the structure can
/// drift between the two — media can be re-admitted, a plan revised, a Final Cut
/// update can revoke a contract.
public struct TreatmentAdmission: Sendable {
    public let lock: EditorialStructureLock
    public let catalog: EditorialKnowledgeCatalog
    public let admittedCapabilities: Set<String>

    public init(lock: EditorialStructureLock, catalog: EditorialKnowledgeCatalog, admittedCapabilities: Set<String>) {
        self.lock = lock
        self.catalog = catalog
        self.admittedCapabilities = admittedCapabilities
    }

    public func admit(_ treatment: TreatmentPlan) throws {
        // 1. The user's edit is still what it was.
        do {
            try lock.validateFingerprint(treatment.structureFingerprint)
        } catch {
            throw TreatmentAdmissionError.structureDrifted(error.localizedDescription)
        }

        // 2. Every technique still exists, is still executable, and still does
        //    not touch the edit.
        for id in treatment.techniqueCardIDs {
            guard let card = catalog.card(id: id) else { throw TreatmentAdmissionError.cardUnknown(id) }
            guard card.lockedStructureEffect == .none else {
                throw TreatmentAdmissionError.structureTouchingTechnique(id)
            }
            guard card.isExecutable(admittedCapabilities: admittedCapabilities) else {
                throw TreatmentAdmissionError.cardNotExecutable(
                    id, reason: card.unavailabilityReason(admittedCapabilities: admittedCapabilities) ?? "unavailable"
                )
            }
        }

        // 3. Cost and privacy are disclosed and approved.
        guard treatment.monetary == .free, treatment.privacy == .localOnly else {
            throw TreatmentAdmissionError.unapprovedCost(
                "\(treatment.name) would \(treatment.monetary == .paid ? "incur a paid call" : "upload media")"
            )
        }
    }
}
