import Foundation

/// Why a candidate treatment was not shown.
///
/// Kept rather than discarded so a short option list can explain itself. "Only
/// two options" with reasons is useful; "only two options" alone looks broken.
public struct RejectedCandidate: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case techniqueUnavailable(String)
        case wouldChangeEditorialStructure(String)
        case mediaUnsuitable(String)
        case safetyBlocked(String)
        case redundantWith(String)
        case costNotApproved(String)
    }
    public let name: String
    public let reason: Reason

    public var explanation: String {
        switch reason {
        case .techniqueUnavailable(let detail): return "\(name): \(detail)"
        case .wouldChangeEditorialStructure(let detail): return "\(name) would change your edit — \(detail)"
        case .mediaUnsuitable(let detail): return "\(name) does not suit this media: \(detail)"
        case .safetyBlocked(let detail): return "\(name) blocked for safety: \(detail)"
        case .redundantWith(let other): return "\(name) was too similar to \(other)"
        case .costNotApproved(let detail): return "\(name) needs approval: \(detail)"
        }
    }
}

/// What the generator produced, including what it refused and why.
public struct TreatmentOptionSet: Sendable {
    public let options: [TreatmentPlan]
    public let rejected: [RejectedCandidate]
    /// The structure every option preserves. All options share this exactly.
    public let structureFingerprint: String
    /// Present when fewer than three honest options existed.
    public let shortfallExplanation: String?

    public init(options: [TreatmentPlan], rejected: [RejectedCandidate], structureFingerprint: String, shortfallExplanation: String?) {
        self.options = options
        self.rejected = rejected
        self.structureFingerprint = structureFingerprint
        self.shortfallExplanation = shortfallExplanation
    }
}

/// Diversity anchors. **Not style presets.**
///
/// The anchors describe how far a treatment leans from the most restrained
/// reading of the request, not a fixed intensity. A sacred or sorrowful moment
/// can have three subtle options and a comic one three energetic options —
/// `adaptedIntensity(from:)` is what makes that true rather than aspirational.
public enum TreatmentAnchor: String, CaseIterable, Sendable {
    case quiet, expressive, bold

    public var displayName: String {
        switch self {
        case .quiet: return "Quiet / Cinematic"
        case .expressive: return "Expressive / Thematic"
        case .bold: return "Bold / Experimental"
        }
    }

    /// Leans from the user's own intensity rather than overriding it.
    ///
    /// A `barelyThere` request yields barely-there, restrained, present — three
    /// genuinely subtle choices. A `bold` request yields present, strong, bold.
    /// The anchor moves the option *relative* to what was asked for.
    public func adaptedIntensity(from requested: TreatmentIntensity) -> TreatmentIntensity {
        let ladder = TreatmentIntensity.allCases
        guard let base = ladder.firstIndex(of: requested) else { return requested }
        let offset: Int
        switch self {
        case .quiet: offset = 0
        case .expressive: offset = 1
        case .bold: offset = 2
        }
        return ladder[min(base + offset, ladder.count - 1)]
    }
}

/// Builds up to three materially different, executable treatments that leave
/// the user's edit exactly as they made it.
///
/// The hard guarantees, in order of importance:
///
/// 1. **Every option carries the input structure fingerprint.** Not a
///    recomputed one — the one the caller locked. An option that cannot claim
///    it is dropped rather than shown.
/// 2. **Safety and structure blockers outrank aesthetic score.** A candidate
///    that would touch the edit or trip a safety card is removed before ranking
///    happens at all, so a high-scoring unsafe option can never win.
/// 3. **Fewer than three rather than padding.** Three renamed versions of one
///    effect is worse than one honest option, because it costs the user
///    attention and teaches them the feature is noise.
/// 4. **Deterministic.** Same evidence, same catalog, same seed → same options.
///    Randomness may explore candidates; it may not make results unreproducible.
public struct TreatmentOptionGenerator: Sendable {
    public let catalog: EditorialKnowledgeCatalog
    public let admittedCapabilities: Set<String>
    public let maximumOptions: Int

    public init(catalog: EditorialKnowledgeCatalog, admittedCapabilities: Set<String>, maximumOptions: Int = 3) {
        self.catalog = catalog
        self.admittedCapabilities = admittedCapabilities
        self.maximumOptions = maximumOptions
    }

    /// One internal candidate before ranking and diversity selection.
    private struct Candidate {
        let anchor: TreatmentAnchor
        let card: TechniqueCard
        let plan: TreatmentPlan
        let score: Double
    }

    public func generate(
        lock: EditorialStructureLock,
        media: [LocalMediaRole: LocalMediaAsset],
        intent: TreatmentIntent,
        basePlans: [EffectID: EffectPlan],
        seed: UInt64 = 0
    ) -> TreatmentOptionSet {
        let fingerprint = lock.fingerprint
        var rejected: [RejectedCandidate] = []
        var candidates: [Candidate] = []

        // Deliberately more internal candidates than will be shown: every
        // executable card crossed with every anchor. Selection happens after,
        // so a strong-but-similar pair can be resolved on merit rather than by
        // whichever was generated first.
        let retrieved = catalog.retrieve(.init(
            intentTags: Set(intent.intentTags),
            admittedCapabilities: admittedCapabilities,
            executableOnly: true,
            limit: 32
        ))

        // Anything relevant but unavailable becomes an explanation, not silence.
        for (card, reason) in catalog.unavailable(for: .init(admittedCapabilities: admittedCapabilities)) {
            switch card.status {
            case .unsupported, .experimental:
                rejected.append(.init(name: card.name, reason: .techniqueUnavailable(reason)))
            case .referenceOnly:
                continue // knowledge, never a candidate; listing it is noise
            case .validated:
                rejected.append(.init(
                    name: card.name,
                    reason: card.lockedStructureEffect == .none
                        ? .techniqueUnavailable(reason)
                        : .wouldChangeEditorialStructure(reason)
                ))
            }
        }

        for card in retrieved {
            // Structure-touching techniques never reach ranking.
            guard card.lockedStructureEffect == .none else {
                rejected.append(.init(name: card.name, reason: .wouldChangeEditorialStructure("it is not treatment-only")))
                continue
            }
            // Cost and privacy are blockers, not tie-breakers.
            if card.expectedCost?.monetary == .paid || card.expectedCost?.privacy == .uploadsMedia {
                rejected.append(.init(name: card.name, reason: .costNotApproved("paid or uploading techniques need approval first")))
                continue
            }
            guard let effectID = card.construction.requiredEffectID.flatMap(EffectID.init(identifier:)),
                  let base = basePlans[effectID] else {
                rejected.append(.init(name: card.name, reason: .techniqueUnavailable("no validated plan exists for this effect with the supplied media")))
                continue
            }
            guard suits(card: card, media: media) else {
                rejected.append(.init(name: card.name, reason: .mediaUnsuitable("its prerequisites are not met by the supplied media")))
                continue
            }

            for anchor in TreatmentAnchor.allCases {
                let plan = makeTreatment(
                    anchor: anchor, card: card, base: base, intent: intent, fingerprint: fingerprint
                )
                candidates.append(.init(anchor: anchor, card: card, plan: plan, score: score(card: card, anchor: anchor, intent: intent)))
            }
        }

        // Deterministic ordering before selection. The seed perturbs only the
        // tie-break, never the ranking, so results stay reproducible.
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let left = stableTiebreak(lhs, seed: seed)
            let right = stableTiebreak(rhs, seed: seed)
            if left != right { return left < right }
            return lhs.plan.name < rhs.plan.name
        }

        // Diversity selection: an option joins only if it differs materially
        // from every option already chosen.
        var chosen: [TreatmentPlan] = []
        for candidate in ordered {
            guard chosen.count < maximumOptions else { break }
            if let clash = chosen.first(where: { !candidate.plan.differsMaterially(from: $0) }) {
                rejected.append(.init(name: candidate.plan.name, reason: .redundantWith(clash.name)))
                continue
            }
            chosen.append(candidate.plan)
        }

        // Every option must carry the caller's fingerprint. A mismatch here
        // would be an internal bug, and shipping it would be worse than showing
        // one fewer option.
        let verified = chosen.filter { $0.structureFingerprint == fingerprint }
        if verified.count != chosen.count {
            for dropped in chosen where dropped.structureFingerprint != fingerprint {
                rejected.append(.init(name: dropped.name, reason: .wouldChangeEditorialStructure("its structure fingerprint did not match the locked edit")))
            }
        }

        // The anchor only earns a place in the name when it actually
        // distinguishes the options. Three cards all labelled "Quiet /
        // Cinematic" reads as a template and tells the user nothing.
        let named = label(verified, anchors: chosenAnchors(for: verified, among: ordered))

        return TreatmentOptionSet(
            options: named,
            rejected: rejected,
            structureFingerprint: fingerprint,
            shortfallExplanation: shortfall(count: named.count, rejected: rejected)
        )
    }

    private func chosenAnchors(for options: [TreatmentPlan], among candidates: [Candidate]) -> [UUID: TreatmentAnchor] {
        var map: [UUID: TreatmentAnchor] = [:]
        for option in options {
            if let match = candidates.first(where: { $0.plan.id == option.id }) { map[option.id] = match.anchor }
        }
        return map
    }

    private func label(_ options: [TreatmentPlan], anchors: [UUID: TreatmentAnchor]) -> [TreatmentPlan] {
        let distinct = Set(anchors.values)
        guard distinct.count > 1 else { return options }
        return options.map { option in
            guard let anchor = anchors[option.id] else { return option }
            var copy = option
            copy.name = "\(anchor.displayName) — \(option.name)"
            return copy
        }
    }

    // MARK: - Scoring

    /// Ranks on intent fidelity first, then reliability signals.
    ///
    /// Preview fidelity is weighted because an option the user cannot judge
    /// before committing is worth less than one they can, regardless of how
    /// good it might be.
    private func score(card: TechniqueCard, anchor: TreatmentAnchor, intent: TreatmentIntent) -> Double {
        var value = 0.0
        let tags = Set(intent.intentTags)
        value += Double(tags.intersection(Set(card.intentTags)).count) * 3.0      // intent fidelity
        value += card.construction.previewFidelity == .sharedConstruction ? 2.0 : 0
        value += card.editability.contains(.finalCutNative) ? 1.5 : 0
        value += card.validation.visuallyVerified ? 1.0 : 0
        value += card.expectedCost?.latency == .instant ? 0.5 : 0
        value -= Double(card.failureModes.count) * 0.1                            // artifact risk
        // Restraint is the default virtue; the bolder anchors have to earn it
        // through intent tags rather than being preferred outright.
        switch anchor {
        case .quiet: value += 0.75
        case .expressive: value += 0.25
        case .bold: value += 0
        }
        return value
    }

    private func stableTiebreak(_ candidate: Candidate, seed: UInt64) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(candidate.card.id)
        hasher.combine(candidate.anchor.rawValue)
        hasher.combine(seed)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    // MARK: - Candidate construction

    private func suits(card: TechniqueCard, media: [LocalMediaRole: LocalMediaAsset]) -> Bool {
        let kinds = Set(media.values.map(\.kind))
        // A card that names a still prerequisite needs a still present.
        if card.mediaPrerequisites.contains(where: { $0.lowercased().contains("still") }), !kinds.contains(.still) {
            return false
        }
        if card.mediaPrerequisites.contains(where: { $0.lowercased().contains("two adjacent") || $0.lowercased().contains("two clips") }) {
            return media.count >= 2
        }
        return true
    }

    private func makeTreatment(
        anchor: TreatmentAnchor,
        card: TechniqueCard,
        base: EffectPlan,
        intent: TreatmentIntent,
        fingerprint: String
    ) -> TreatmentPlan {
        var adapted = intent
        adapted.intensity = anchor.adaptedIntensity(from: intent.intensity)

        var plan = base
        plan.operationID = UUID()

        return TreatmentPlan(
            structureFingerprint: fingerprint,
            intent: adapted,
            name: card.name,
            idea: card.summary,
            changes: changes(for: card, anchor: anchor),
            preserved: [
                "Your clips, in your order",
                "Every edit point and clip duration",
                "Audio sync"
            ],
            techniqueCardIDs: [card.id],
            effectPlan: plan,
            editability: card.editability.contains(.finalCutNative) ? .finalCutNative : .framesmithRegeneration,
            previewFidelity: card.construction.previewFidelity,
            dimensions: dimensions(for: card, anchor: anchor),
            estimatedLatency: card.expectedCost?.latency ?? .instant,
            monetary: card.expectedCost?.monetary ?? .free,
            privacy: card.expectedCost?.privacy ?? .localOnly,
            provenanceSummary: card.provenance.map { "\($0.sourceId): \($0.claim)" }
        )
    }

    /// Deliberately does **not** repeat `card.summary`; that is already shown as
    /// the option's idea line, and printing it twice made the card read like a
    /// template rather than a description.
    private func changes(for card: TechniqueCard, anchor: TreatmentAnchor) -> [String] {
        var lines: [String] = []
        switch anchor {
        case .quiet: lines.append("Held deliberately under the threshold where the effect announces itself")
        case .expressive: lines.append("Pushed far enough to read as a choice rather than an accident")
        case .bold: lines.append("Taken to the strongest setting that still holds together")
        }
        if card.construction.previewFidelity == .indicative {
            lines.append("Preview shows direction only — the exact strength is not verified")
        }
        if !card.editability.contains(.finalCutNative) {
            lines.append("Adjustable by regenerating in FrameSmith rather than in Final Cut")
        }
        return lines
    }

    /// Which creative axes a candidate acts on. Diversity is measured here, so
    /// this has to reflect real differences rather than labels.
    private func dimensions(for card: TechniqueCard, anchor: TreatmentAnchor) -> Set<TreatmentDimension> {
        var set: Set<TreatmentDimension> = []
        switch card.domain {
        case .motion:
            set.insert(.motionLanguage)
            if card.intentTags.contains("eye-trace") || card.intentTags.contains("directed") { set.insert(.spatialDepthMethod) }
        case .transition:
            set.insert(.transitionMechanism)
        case .look:
            set.insert(.paletteContrast)
            set.insert(.texture)
        case .typography: set.insert(.typography)
        case .audio: set.insert(.soundTreatment)
        case .safety, .analysis, .process: break
        }
        // A bolder anchor changes the representation the user ends up with,
        // which is itself a dimension the contract lists.
        if anchor == .bold { set.insert(.representation) }
        return set
    }

    private func shortfall(count: Int, rejected: [RejectedCandidate]) -> String? {
        guard count < maximumOptions else { return nil }
        if count == 0 {
            return "No treatment can run on this media with the currently admitted Final Cut capabilities."
        }
        let unavailable = rejected.filter { if case .techniqueUnavailable = $0.reason { return true }; return false }
        let detail = unavailable.isEmpty
            ? "the remaining candidates were too similar to be a real choice"
            : "the other candidates are not available yet"
        return "Showing \(count) option\(count == 1 ? "" : "s") rather than \(maximumOptions), because \(detail). Padding the list with near-duplicates would waste your attention."
    }
}

private extension TreatmentIntent {
    /// Intent tags derived from the user's own wording plus explicit readings.
    var intentTags: [String] {
        var tags: [String] = []
        let text = ([originalWording, emotional, motion, transition, colorLook, texture]
            .compactMap { $0 }).joined(separator: " ").lowercased()
        let vocabulary: [String: String] = [
            "quiet": "quiet", "still": "quiet", "calm": "quiet", "gentle": "restrained",
            "subtle": "restrained", "restrain": "restrained", "cinematic": "cinematic",
            "contempl": "contemplative", "sad": "contemplative", "sorrow": "contemplative",
            "bold": "bold", "strong": "bold", "energetic": "bold", "dramatic": "expressive",
            "atmospher": "atmosphere", "moody": "atmosphere", "dream": "expressive",
            "focus": "emphasis", "attention": "emphasis", "point": "emphasis",
            "old": "period", "vintage": "period", "retro": "period",
            "invisible": "invisible", "seamless": "invisible", "motivated": "motivated"
        ]
        for (needle, tag) in vocabulary where text.contains(needle) { tags.append(tag) }
        switch intensity {
        case .barelyThere, .restrained: tags.append("restrained")
        case .present: break
        case .strong, .bold: tags.append("bold")
        }
        return Array(Set(tags))
    }
}
