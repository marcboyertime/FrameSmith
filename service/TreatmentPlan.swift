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
    case mediaDrifted(String)
    case cardVersionDrifted(String)
    case safetyBlocked(String)
    case impactEvidenceMissing(String)
    case treatmentContractRejected(String)

    public var errorDescription: String? {
        switch self {
        case .structureDrifted(let detail): return "The editorial structure changed after this treatment was planned: \(detail)"
        case .cardNotExecutable(let id, let reason): return "Technique \(id) cannot run: \(reason)"
        case .cardUnknown(let id): return "Technique \(id) is not in the catalog"
        case .effectPlanRejected(let detail): return "The underlying effect plan was rejected: \(detail)"
        case .unapprovedCost(let detail): return "This treatment needs approval first: \(detail)"
        case .structureTouchingTechnique(let id): return "Technique \(id) would change your edit, so it cannot be applied as a treatment"
        case .mediaDrifted(let detail): return "The admitted media changed: \(detail)"
        case .cardVersionDrifted(let id): return "Technique \(id) changed after this option was generated"
        case .safetyBlocked(let detail): return "Treatment blocked by safety: \(detail)"
        case .impactEvidenceMissing(let detail): return "Treatment has no admissible protected-region impact evidence: \(detail)"
        case .treatmentContractRejected(let detail): return "Treatment contract rejected: \(detail)"
        }
    }
}

/// Repository-specific validator for the exact JSON emitted by `TreatmentPlan`.
/// It deliberately validates only the checked-in contract subset; it does not
/// represent itself as a general JSON Schema implementation.
public struct TreatmentPlanContractValidator: @unchecked Sendable {
    public let schemaID: String
    public let schemaVersion: String
    public let schemaDigest: String
    private let validator: PlanSchemaValidator

    public init(schemaURL: URL) throws {
        let data = try Data(contentsOf: schemaURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["$id"] as? String, let version = object["x-framesmith-contract-version"] as? String else {
            throw PlanSchemaValidationError.invalidSchema("TreatmentPlan contract needs immutable id and version")
        }
        schemaID = id; schemaVersion = version; schemaDigest = ContentHasher.sha256(data)
        validator = try PlanSchemaValidator(schemaURL: schemaURL)
    }

    public func validateEncoded(_ treatment: TreatmentPlan) throws -> TreatmentContractValidationSnapshot {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try validate(encoder.encode(treatment))
    }

    public func validate(_ data: Data) throws -> TreatmentContractValidationSnapshot {
        try validator.validate(data)
        return TreatmentContractValidationSnapshot(schemaID: schemaID, schemaVersion: schemaVersion, schemaDigest: schemaDigest, valid: true)
    }

    public static func discover() throws -> TreatmentPlanContractValidator {
        let manager = FileManager.default
        let candidates = [URL(fileURLWithPath: manager.currentDirectoryPath).appendingPathComponent("schemas/treatment-plan.schema.json"), URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("schemas/treatment-plan.schema.json")]
        guard let url = candidates.first(where: { manager.fileExists(atPath: $0.path) }) else { throw PlanSchemaValidationError.schemaUnreadable("treatment-plan.schema.json not found") }
        return try TreatmentPlanContractValidator(schemaURL: url)
    }
}

public struct TreatmentContractValidationSnapshot: Codable, Equatable, Sendable {
    public let schemaID: String
    public let schemaVersion: String
    public let schemaDigest: String
    public let valid: Bool
}

public struct AdmittedTechniqueCardSnapshot: Codable, Equatable, Sendable {
    public let card: TechniqueCard
    public let evaluation: TechniqueCardEvaluation
    public let cost: TechniqueCost?
    public let provenance: [TechniqueProvenance]
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
    /// Stable content identity for an option. It is not an execution operation
    /// ID; selection/refinement mints that later at the irreversible boundary.
    public let optionID: String
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
    public var techniqueCardVersions: [String: Int]
    public var constructionSignature: String

    public init(
        id: UUID = UUID(), optionID: String? = nil,
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
        provenanceSummary: [String] = [], techniqueCardVersions: [String: Int] = [:], constructionSignature: String? = nil
    ) {
        self.optionID = optionID ?? TreatmentIdentity.digest(["legacy-option", structureFingerprint, name, effectPlan.effectID.rawValue, TreatmentIdentity.constructionSignature(for: effectPlan)])
        self.id = optionID.map(TreatmentIdentity.stableUUID) ?? id
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
        self.techniqueCardVersions = techniqueCardVersions
        self.constructionSignature = constructionSignature ?? TreatmentIdentity.constructionSignature(for: effectPlan)
    }

    private enum CodingKeys: String, CodingKey {
        case id, optionID, structureFingerprint, intent, name, idea, changes, preserved
        case techniqueCardIDs, effectPlan, editability, previewFidelity, dimensions
        case estimatedLatency, monetary, privacy, provenanceSummary, techniqueCardVersions
        case constructionSignature
    }

    /// Set iteration is intentionally randomized by Swift.  Treatment options
    /// are persisted and signed as whole artifacts, so encode semantic
    /// dimensions in their stable wire order rather than accepting a
    /// process-dependent `Set` representation.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(optionID, forKey: .optionID)
        try container.encode(structureFingerprint, forKey: .structureFingerprint)
        try container.encode(intent, forKey: .intent)
        try container.encode(name, forKey: .name)
        try container.encode(idea, forKey: .idea)
        try container.encode(changes, forKey: .changes)
        try container.encode(preserved, forKey: .preserved)
        try container.encode(techniqueCardIDs, forKey: .techniqueCardIDs)
        try container.encode(effectPlan, forKey: .effectPlan)
        try container.encode(editability, forKey: .editability)
        try container.encode(previewFidelity, forKey: .previewFidelity)
        try container.encode(dimensions.sorted { $0.rawValue < $1.rawValue }, forKey: .dimensions)
        try container.encode(estimatedLatency, forKey: .estimatedLatency)
        try container.encode(monetary, forKey: .monetary)
        try container.encode(privacy, forKey: .privacy)
        try container.encode(provenanceSummary, forKey: .provenanceSummary)
        try container.encode(techniqueCardVersions, forKey: .techniqueCardVersions)
        try container.encode(constructionSignature, forKey: .constructionSignature)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        optionID = try container.decode(String.self, forKey: .optionID)
        structureFingerprint = try container.decode(String.self, forKey: .structureFingerprint)
        intent = try container.decode(TreatmentIntent.self, forKey: .intent)
        name = try container.decode(String.self, forKey: .name)
        idea = try container.decode(String.self, forKey: .idea)
        changes = try container.decode([String].self, forKey: .changes)
        preserved = try container.decode([String].self, forKey: .preserved)
        techniqueCardIDs = try container.decode([String].self, forKey: .techniqueCardIDs)
        effectPlan = try container.decode(EffectPlan.self, forKey: .effectPlan)
        editability = try container.decode(TreatmentEditability.self, forKey: .editability)
        previewFidelity = try container.decode(PreviewFidelity.self, forKey: .previewFidelity)
        dimensions = Set(try container.decode([TreatmentDimension].self, forKey: .dimensions))
        estimatedLatency = try container.decode(TechniqueCost.Latency.self, forKey: .estimatedLatency)
        monetary = try container.decode(TechniqueCost.Monetary.self, forKey: .monetary)
        privacy = try container.decode(TechniqueCost.Privacy.self, forKey: .privacy)
        provenanceSummary = try container.decode([String].self, forKey: .provenanceSummary)
        techniqueCardVersions = try container.decode([String: Int].self, forKey: .techniqueCardVersions)
        constructionSignature = try container.decode(String.self, forKey: .constructionSignature)
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
        // Parameters describe a construction; they are not independent creative
        // axes.  Counting changed keys used to present slider nudges as diverse
        // choices.  Only the semantic dimensions declared on each treatment
        // may establish variety, while the signature still proves the builds
        // are actually distinct.
        let semanticDifferences = dimensions.symmetricDifference(other.dimensions).count
        return constructionSignature != other.constructionSignature
            && semanticDifferences >= 2
    }

    public func actualConstructionDifferenceCount(from other: TreatmentPlan) -> Int {
        var count = effectPlan.effectID != other.effectPlan.effectID ? 1 : 0
        let keys = Set(effectPlan.parameters.keys).union(other.effectPlan.parameters.keys)
        count += keys.filter { effectPlan.parameters[$0] != other.effectPlan.parameters[$0] }.count
        if effectPlan.normalizedPoint != other.effectPlan.normalizedPoint { count += 1 }
        if effectPlan.representation != other.effectPlan.representation { count += 1 }
        if effectPlan.selectionToken.sourceIdentities != other.effectPlan.selectionToken.sourceIdentities { count += 1 }
        return count
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
    public let registry: EffectRegistry
    public let approvedRiskCategories: Set<TechniqueRiskCategory>
    public let treatmentContractValidator: TreatmentPlanContractValidator?

    public init(lock: EditorialStructureLock, catalog: EditorialKnowledgeCatalog, admittedCapabilities: Set<String>, registry: EffectRegistry, approvedRiskCategories: Set<TechniqueRiskCategory> = [], treatmentContractValidator: TreatmentPlanContractValidator? = nil) {
        self.lock = lock
        self.catalog = catalog
        self.admittedCapabilities = admittedCapabilities
        self.registry = registry
        self.approvedRiskCategories = approvedRiskCategories
        self.treatmentContractValidator = treatmentContractValidator
    }

    /// The admission boundary deliberately requires current structure, media,
    /// and computed impact evidence. A stale option alone is never executable.
    @discardableResult public func admit(_ treatment: TreatmentPlan, currentStructure: EditorialStructureLock, media: [LocalMediaRole: LocalMediaAsset], impactEvidence: [ProtectedRegionImpactEvidence]) throws -> AdmittedTreatmentExecution {
        let contract: TreatmentContractValidationSnapshot
        do { contract = try (treatmentContractValidator ?? .discover()).validateEncoded(treatment) }
        catch { throw TreatmentAdmissionError.treatmentContractRejected(error.localizedDescription) }
        // 1. The user's edit is still what it was.
        do {
            try lock.validateFingerprint(treatment.structureFingerprint)
            try lock.validate(currentStructure, impactEvidence: impactEvidence)
        } catch {
            throw TreatmentAdmissionError.structureDrifted(error.localizedDescription)
        }

        // 2. Every technique still exists, is still executable, and still does
        //    not touch the edit.
        var cardSnapshots: [AdmittedTechniqueCardSnapshot] = []
        for id in treatment.techniqueCardIDs {
            guard let card = catalog.card(id: id) else { throw TreatmentAdmissionError.cardUnknown(id) }
            guard card.lockedStructureEffect == .none else {
                throw TreatmentAdmissionError.structureTouchingTechnique(id)
            }
            guard card.construction.requiredEffectID == treatment.effectPlan.effectID.rawValue else {
                throw TreatmentAdmissionError.effectPlanRejected(
                    "\(id) requires \(card.construction.requiredEffectID ?? "no executable effect"), not \(treatment.effectPlan.effectID.rawValue)"
                )
            }
            guard card.isExecutable(admittedCapabilities: admittedCapabilities) else {
                throw TreatmentAdmissionError.cardNotExecutable(
                    id, reason: card.unavailabilityReason(admittedCapabilities: admittedCapabilities) ?? "unavailable"
                )
            }
            guard treatment.techniqueCardVersions[id] == card.version else { throw TreatmentAdmissionError.cardVersionDrifted(id) }
            guard treatment.estimatedLatency == card.expectedCost?.latency,
                  treatment.monetary == card.expectedCost?.monetary,
                  treatment.privacy == card.expectedCost?.privacy else { throw TreatmentAdmissionError.unapprovedCost("the card cost/privacy snapshot drifted") }
            let evaluation = card.evaluate(in: .init(media: media, target: treatment.effectPlan.normalizedPoint, approvedRiskCategories: approvedRiskCategories))
            switch evaluation.executableDecision {
            case .allowedAutomatically: break
            case .requiresUserApproval: throw TreatmentAdmissionError.unapprovedCost("\(id) needs approval for its declared risk or safety gate")
            case .refused: throw TreatmentAdmissionError.safetyBlocked("\(id) failed a typed prerequisite, refusal, risk, or safety gate")
            }
            cardSnapshots.append(.init(card: card, evaluation: evaluation, cost: card.expectedCost, provenance: card.provenance))
        }

        // 3. Cost and privacy are disclosed and approved.
        guard treatment.monetary == .free, treatment.privacy == .localOnly else {
            throw TreatmentAdmissionError.unapprovedCost(
                "\(treatment.name) would \(treatment.monetary == .paid ? "incur a paid call" : "upload media")"
            )
        }
        let execution = ValidatedPlanExecution(registry: registry)
        let channels: NativeFCPXMLEffectChannels
        do {
            try execution.validate(plan: treatment.effectPlan, media: media)
            guard let emitter = execution.catalog.emitter(for: treatment.effectPlan.effectID) else { throw TreatmentAdmissionError.effectPlanRejected("no emitter registered") }
            channels = try emitter.channels(plan: treatment.effectPlan, media: media)
        } catch { throw TreatmentAdmissionError.effectPlanRejected(error.localizedDescription) }
        // Duration is an editorial fact.  Do not round a binary floating-point
        // value into a frame count: the lock already carries the exact rational
        // time for every clip and its exact frameDuration.  A channel duration
        // that cannot be represented as a finite decimal rational is refused
        // rather than being silently rounded onto a neighbouring frame.
        var lockedFrames = 0
        var frameCountOverflowed = false
        for clip in lock.clips {
            let sum = lockedFrames.addingReportingOverflow(clip.durationFrames)
            frameCountOverflowed = frameCountOverflowed || sum.overflow
            lockedFrames = sum.partialValue
        }
        let lockedProduct = Int64(lockedFrames).multipliedReportingOverflow(by: lock.frameDuration.numerator)
        guard !frameCountOverflowed, !lockedProduct.overflow,
              let emittedDuration = exactDecimalDuration(channels.durationSeconds),
              RationalTime(lockedProduct.partialValue, lock.frameDuration.denominator) == emittedDuration else {
            let lockedDuration = frameCountOverflowed || lockedProduct.overflow
                ? "unrepresentable"
                : "\(RationalTime(lockedProduct.partialValue, lock.frameDuration.denominator).numerator)/\(RationalTime(lockedProduct.partialValue, lock.frameDuration.denominator).denominator)s"
            throw TreatmentAdmissionError.effectPlanRejected(
                "construction duration \(channels.durationSeconds)s does not exactly match the director-locked rational duration \(lockedDuration)"
            )
        }
        if cardSnapshots.contains(where: { $0.card.id == "look.crt.old_television.v1" }) {
            // The validated CRT card declares no connected overlay, and the
            // current viewer has no shared-construction preview for one.
            guard channels.overlay == nil else {
                throw TreatmentAdmissionError.safetyBlocked("CRT automatic admission refuses connected overlays because this card declares none and the current viewer cannot preview one")
            }
            guard permitsAutomaticCRTBase(channels) else {
                throw TreatmentAdmissionError.safetyBlocked("CRT automatic admission is limited to the measured 4s full→0.82→full base dip; repeated or stronger flicker requires remeasurement")
            }
        }
        let signature = TreatmentIdentity.constructionSignature(for: treatment.effectPlan)
        guard signature == treatment.constructionSignature else { throw TreatmentAdmissionError.effectPlanRejected("construction signature changed") }
        let channelSnapshot = AdmittedChannelSnapshot(channels: channels)
        let definition = try? registry.definition(for: treatment.effectPlan.effectID)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let registryDigest = definition.flatMap { try? encoder.encode($0) }.map(ContentHasher.sha256) ?? ""
        return AdmittedTreatmentExecution(treatment: treatment, structure: currentStructure, media: media, admittedCapabilities: admittedCapabilities, constructionSignature: TreatmentIdentity.digest([signature, channelSnapshot.canonicalPayload]), channels: channelSnapshot, cards: cardSnapshots, contract: contract, registryEffectID: treatment.effectPlan.effectID.rawValue, registryDigest: registryDigest, emitterAvailable: true)
    }

    func isBoundedCRTBase(_ channels: NativeFCPXMLEffectChannels) -> Bool {
        let keyframes = channels.opacity.amount
        guard keyframes.count == 3,
              keyframes.map(\.value) == ["1", "0.82", "1"] else { return false }
        let seconds = keyframes.map { $0.time.seconds - keyframes[0].time.seconds }
        return seconds == [0, 0.5, 1] && channels.durationSeconds == 4
    }

    func permitsAutomaticCRTBase(_ channels: NativeFCPXMLEffectChannels) -> Bool {
        channels.overlay == nil && isBoundedCRTBase(channels)
    }

    /// Converts the channel's serialised duration to an exact base-10 rational
    /// without multiplying or rounding a `Double` into frames.  The shortest
    /// Swift representation is bounded to a small decimal exponent; values
    /// outside Int64 range simply fail admission.
    private func exactDecimalDuration(_ value: Double) -> RationalTime? {
        guard value.isFinite, value >= 0 else { return nil }
        var text = String(value)
        var exponent = 0
        if let marker = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            exponent = Int(text[text.index(after: marker)...]) ?? 0
            text = String(text[..<marker])
        }
        let negative = text.hasPrefix("-")
        if negative { text.removeFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let whole = String(parts.first ?? "")
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let digits = whole + fraction
        guard !digits.isEmpty, let unsigned = Int64(digits) else { return nil }
        let signed = negative ? -unsigned : unsigned
        let decimalPlaces = fraction.count - exponent
        if decimalPlaces >= 0 {
            guard decimalPlaces < 19 else { return nil }
            return RationalTime(signed, Int64.pow10(decimalPlaces))
        }
        let multiplier = Int64.pow10(-decimalPlaces)
        let product = signed.multipliedReportingOverflow(by: multiplier)
        return product.overflow ? nil : RationalTime(product.partialValue)
    }
}

private extension Int64 {
    static func pow10(_ exponent: Int) -> Int64 {
        guard exponent >= 0 && exponent < 19 else { return 0 }
        var result: Int64 = 1
        for _ in 0..<exponent { result *= 10 }
        return result
    }
}

/// The sole safe hand-off to preview, compare, refine, package, or export.
/// All fields are immutable snapshots of the same admission event.
public struct AdmittedChannelSnapshot: Codable, Equatable, Sendable {
    public struct Time: Codable, Equatable, Sendable { public let numerator: Int; public let timescale: Int; init(_ value: NativeFCPXMLTime) { numerator = value.numerator; timescale = value.timescale } }
    public struct Keyframe: Codable, Equatable, Sendable { public let time: Time; public let value: String; public let curve: String?; public let interp: String?; init(_ value: NativeFCPXMLKeyframe) { time = Time(value.time); self.value = value.value; curve = value.curve; interp = value.interp } }
    public struct Point: Codable, Equatable, Sendable { public let x: Double; public let y: Double }
    public struct Transform: Codable, Equatable, Sendable { public let positionX: [Keyframe]; public let positionY: [Keyframe]; public let scale: [Keyframe]; public let rotation: [Keyframe]; public let anchor: Point?; public let staticPosition: Point? }
    public struct Opacity: Codable, Equatable, Sendable { public let amount: [Keyframe]; public let staticAmount: Double?; public let blendAttribute: String? }
    public struct Transition: Codable, Equatable, Sendable { public let cutFrame: Int; public let durationFrames: Int; public let outgoingDurationFrames: Int; public let incomingDurationFrames: Int }
    public struct Overlay: Codable, Equatable, Sendable { public let startFrameWithinParent: Int; public let durationFrames: Int; public let opacity: Double; public let blendAttribute: String? }
    public enum Origin: Codable, Equatable, Sendable { case still; case movie(startSeconds: Int) }
    public let transform: Transform
    public let opacity: Opacity
    public let transition: Transition?
    public let overlay: Overlay?
    public let saturation: Double?
    public let durationSeconds: Double
    public let origin: Origin
    public let frameWidth: Int
    public let frameHeight: Int
    public let canonicalPayload: String
    public let digest: String
    public init(channels: NativeFCPXMLEffectChannels) {
        transform = Transform(positionX: channels.transform.positionX.map(Keyframe.init), positionY: channels.transform.positionY.map(Keyframe.init), scale: channels.transform.scale.map(Keyframe.init), rotation: channels.transform.rotation.map(Keyframe.init), anchor: channels.transform.anchor.map { Point(x: $0.x, y: $0.y) }, staticPosition: channels.transform.staticPosition.map { Point(x: $0.x, y: $0.y) })
        opacity = Opacity(amount: channels.opacity.amount.map(Keyframe.init), staticAmount: channels.opacity.staticAmount, blendAttribute: channels.opacity.mode?.attributeValue)
        transition = channels.transition.map { Transition(cutFrame: $0.cutFrame, durationFrames: $0.durationFrames, outgoingDurationFrames: $0.outgoingDurationFrames, incomingDurationFrames: $0.incomingDurationFrames) }
        overlay = channels.overlay.map { Overlay(startFrameWithinParent: $0.startFrameWithinParent, durationFrames: $0.durationFrames, opacity: $0.opacity, blendAttribute: $0.blendMode?.attributeValue) }
        saturation = channels.saturation; durationSeconds = channels.durationSeconds; frameWidth = channels.frameWidth; frameHeight = channels.frameHeight
        switch channels.origin { case .still: origin = .still; case .movie(let startSeconds): origin = .movie(startSeconds: startSeconds) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body = SnapshotBody(transform: transform, opacity: opacity, transition: transition, overlay: overlay, saturation: saturation, durationSeconds: durationSeconds, origin: origin, frameWidth: frameWidth, frameHeight: frameHeight)
        canonicalPayload = String(data: (try? encoder.encode(body)) ?? Data(), encoding: .utf8) ?? ""
        self.digest = ContentHasher.sha256(Data(canonicalPayload.utf8))
    }
    private struct SnapshotBody: Codable { let transform: Transform; let opacity: Opacity; let transition: Transition?; let overlay: Overlay?; let saturation: Double?; let durationSeconds: Double; let origin: Origin; let frameWidth: Int; let frameHeight: Int }
    public func matches(_ channels: NativeFCPXMLEffectChannels) -> Bool { self == AdmittedChannelSnapshot(channels: channels) }

    /// Rehydrates the admitted construction without asking an emitter to make a
    /// second, potentially different interpretation of the treatment. Preview
    /// and comparison use this exact representation; export separately checks
    /// that its emitter still produces it before it writes anything.
    public func materializedChannels() -> NativeFCPXMLEffectChannels {
        func time(_ value: Time) -> NativeFCPXMLTime {
            NativeFCPXMLTime(numerator: value.numerator, timescale: value.timescale)
        }
        func keyframe(_ value: Keyframe) -> NativeFCPXMLKeyframe {
            NativeFCPXMLKeyframe(time: time(value.time), value: value.value, curve: value.curve, interp: value.interp)
        }
        let transform = NativeFCPXMLTransformChannel(
            positionX: transform.positionX.map(keyframe), positionY: transform.positionY.map(keyframe),
            scale: transform.scale.map(keyframe), rotation: transform.rotation.map(keyframe),
            anchor: transform.anchor.map { ($0.x, $0.y) }, staticPosition: transform.staticPosition.map { ($0.x, $0.y) }
        )
        let opacity = NativeFCPXMLOpacityChannel(
            amount: opacity.amount.map(keyframe), staticAmount: opacity.staticAmount,
            mode: opacity.blendAttribute.map(NativeFCPXMLBlendMode.captured)
        )
        let rebuiltTransition = transition.map {
            NativeFCPXMLTransitionDescriptor(cutFrame: $0.cutFrame, durationFrames: $0.durationFrames, outgoingDurationFrames: $0.outgoingDurationFrames, incomingDurationFrames: $0.incomingDurationFrames)
        }
        let rebuiltOverlay = overlay.map {
            NativeFCPXMLOverlayDescriptor(startFrameWithinParent: $0.startFrameWithinParent, durationFrames: $0.durationFrames, opacity: $0.opacity, blendMode: $0.blendAttribute.map(NativeFCPXMLBlendMode.captured))
        }
        let rebuiltOrigin: NativeFCPXMLTimingOrigin
        switch origin { case .still: rebuiltOrigin = .still; case .movie(let startSeconds): rebuiltOrigin = .movie(startSeconds: startSeconds) }
        return NativeFCPXMLEffectChannels(transform: transform, opacity: opacity, saturation: saturation, durationSeconds: durationSeconds, origin: rebuiltOrigin, frameWidth: frameWidth, frameHeight: frameHeight, transition: rebuiltTransition, overlay: rebuiltOverlay)
    }
}

public struct AdmittedTreatmentExecution: Sendable, Equatable {
    public let treatment: TreatmentPlan
    public let structure: EditorialStructureLock
    public let media: [LocalMediaRole: LocalMediaAsset]
    public let admittedCapabilities: Set<String>
    public let constructionSignature: String
    public let channels: AdmittedChannelSnapshot
    public let admittedAtFingerprint: String
    public let cards: [AdmittedTechniqueCardSnapshot]
    public let contract: TreatmentContractValidationSnapshot
    public let registryEffectID: String
    public let registryDigest: String
    public let emitterAvailable: Bool
    public init(treatment: TreatmentPlan, structure: EditorialStructureLock, media: [LocalMediaRole: LocalMediaAsset], admittedCapabilities: Set<String>, constructionSignature: String, channels: AdmittedChannelSnapshot, cards: [AdmittedTechniqueCardSnapshot], contract: TreatmentContractValidationSnapshot, registryEffectID: String, registryDigest: String, emitterAvailable: Bool) {
        self.treatment = treatment; self.structure = structure; self.media = media; self.admittedCapabilities = admittedCapabilities; self.constructionSignature = constructionSignature; self.channels = channels; self.admittedAtFingerprint = structure.fingerprint; self.cards = cards; self.contract = contract; self.registryEffectID = registryEffectID; self.registryDigest = registryDigest; self.emitterAvailable = emitterAvailable
    }
    /// This is the only moment an execution operation ID is minted.
    public func selectingForExecution() -> EffectPlan { var plan = treatment.effectPlan; plan.operationID = UUID(); return plan }
}
