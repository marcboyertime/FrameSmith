import Foundation

public enum EditorialKnowledgeCatalogError: Error, LocalizedError, Equatable, Sendable {
    case unreadableDirectory(URL)
    case malformedCard(String, String)
    case duplicateID(String)
    case unknownSource(cardID: String, sourceID: String)
    case executableClaimWithoutImplementation(String)
    case livenessDisagreement(cardID: String, parameter: String)
    case strictSchemaViolation(cardID: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableDirectory(let url): return "Technique card directory is unreadable: \(url.path)"
        case .malformedCard(let file, let detail): return "Malformed technique card \(file): \(detail)"
        case .duplicateID(let id): return "Duplicate technique card id: \(id)"
        case .unknownSource(let cardID, let sourceID):
            return "Card \(cardID) cites source \(sourceID), which is not in the source catalog"
        case .executableClaimWithoutImplementation(let id):
            return "Card \(id) claims status 'validated' but its validation record says it is not implemented and visually verified. A source describing a technique does not validate it."
        case .livenessDisagreement(let cardID, let parameter):
            return "Card \(cardID) presents parameter '\(parameter)' as live, which disagrees with the registry"
        case .strictSchemaViolation(let cardID, let detail):
            return "Card \(cardID) violates the strict technique-card contract: \(detail)"
        }
    }
}

/// Loads, validates, and selectively retrieves technique cards.
///
/// Two properties this type exists to guarantee:
///
/// 1. **It never lies about what is runnable.** A card is only returned as
///    executable when its status is `validated`, it is treatment-only, and its
///    required capabilities are currently admitted. Those are checked at
///    retrieval, not at load, so a Final Cut update that revokes a contract
///    silently removes options rather than offering broken ones.
/// 2. **It needs no network.** The catalog is bundled JSON. The 153-source
///    atlas is a retrieval map for *humans and agents doing research*, not a
///    runtime dependency — nothing here fetches anything.
public struct EditorialKnowledgeCatalog: Sendable {
    public let cards: [TechniqueCard]
    /// Source IDs known to the catalog, used to reject invented provenance.
    public let knownSourceIDs: Set<String>

    public init(cards: [TechniqueCard], knownSourceIDs: Set<String> = []) {
        self.cards = cards
        self.knownSourceIDs = knownSourceIDs
    }

    /// Loads every `*.json` in a directory, deterministically ordered by file
    /// name so two runs produce the same catalog.
    public static func load(
        from directory: URL,
        knownSourceIDs: Set<String> = []
    ) throws -> EditorialKnowledgeCatalog {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            throw EditorialKnowledgeCatalogError.unreadableDirectory(directory)
        }
        let files = entries.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        let decoder = JSONDecoder()
        let effectiveSources: Set<String> = knownSourceIDs.isEmpty
            ? sourceIDs(fromCSV: directory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/editorial-intelligence/sources.csv"))
            : knownSourceIDs
        var cards: [TechniqueCard] = []
        var seen: Set<String> = []

        for file in files {
            let card: TechniqueCard
            let object: [String: Any]
            do {
                let data = try Data(contentsOf: file)
                guard let decodedObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw EditorialKnowledgeCatalogError.malformedCard(file.lastPathComponent, "root is not an object") }
                object = decodedObject
                card = try decoder.decode(TechniqueCard.self, from: data)
            } catch {
                throw EditorialKnowledgeCatalogError.malformedCard(file.lastPathComponent, String(describing: error))
            }
            guard !seen.contains(card.id) else { throw EditorialKnowledgeCatalogError.duplicateID(card.id) }
            seen.insert(card.id)

            // A card cannot promote itself to executable by asserting a status.
            if card.status == .validated, !(card.validation.implemented && card.validation.visuallyVerified) {
                throw EditorialKnowledgeCatalogError.executableClaimWithoutImplementation(card.id)
            }
            // Provenance is fail-closed.  An empty source set means no source
            // has been verified, not that every source is implicitly trusted.
            for entry in card.provenance where !effectiveSources.contains(entry.sourceId) {
                guard !effectiveSources.isEmpty,
                      isVerifiedRepositoryEvidence(entry.sourceId, relativeTo: directory) else {
                    throw EditorialKnowledgeCatalogError.unknownSource(cardID: card.id, sourceID: entry.sourceId)
                }
            }
            try validateStrictObject(object, file: file.lastPathComponent)
            try validateStrictSemantics(card)
            cards.append(card)
        }
        return EditorialKnowledgeCatalog(cards: cards, knownSourceIDs: effectiveSources)
    }

    private static func validateStrictObject(_ object: [String: Any], file: String) throws {
        let required: Set<String> = ["id", "version", "name", "domain", "status", "summary", "creativeJobs", "intentTags", "mediaPrerequisites", "refusalConditions", "prerequisiteRules", "refusalRules", "lockedStructureEffect", "construction", "parameters", "qualityChecks", "failureModes", "safety", "riskGates", "safetyGates", "editability", "expectedCost", "provenance", "validation"]
        let unknown = Set(object.keys).subtracting(required.union(["conflicts", "notes"]))
        guard unknown.isEmpty else { throw EditorialKnowledgeCatalogError.malformedCard(file, "unknown keys: \(unknown.sorted())") }
        guard required.isSubset(of: Set(object.keys)) else { throw EditorialKnowledgeCatalogError.malformedCard(file, "missing keys: \(required.subtracting(object.keys).sorted())") }
        try validateClosedNestedObjects(object, file: file)
    }

    private static func validateClosedNestedObjects(_ object: [String: Any], file: String) throws {
        func rejectUnknown(_ value: Any?, allowed: Set<String>, path: String) throws {
            guard let dictionary = value as? [String: Any] else {
                throw EditorialKnowledgeCatalogError.malformedCard(file, "\(path) is not an object")
            }
            let unknown = Set(dictionary.keys).subtracting(allowed)
            guard unknown.isEmpty else {
                throw EditorialKnowledgeCatalogError.malformedCard(file, "unknown keys in \(path): \(unknown.sorted())")
            }
        }
        func rejectUnknownArray(_ value: Any?, allowed: Set<String>, path: String) throws {
            guard let array = value as? [Any] else {
                throw EditorialKnowledgeCatalogError.malformedCard(file, "\(path) is not an array")
            }
            for (index, item) in array.enumerated() {
                try rejectUnknown(item, allowed: allowed, path: "\(path)[\(index)]")
            }
        }

        try rejectUnknown(object["construction"], allowed: ["preferredBackends", "fallbackBackends", "requiredCapabilities", "requiredEffectID", "previewFidelity"], path: "construction")
        try rejectUnknownArray(object["parameters"], allowed: ["key", "type", "unit", "range", "default", "liveness"], path: "parameters")
        try rejectUnknownArray(object["prerequisiteRules"], allowed: ["kind", "mediaKind", "role", "count", "hasAudio", "minWidth", "minHeight"], path: "prerequisiteRules")
        try rejectUnknownArray(object["refusalRules"], allowed: ["kind", "mediaKind", "role", "count", "hasAudio", "minWidth", "minHeight"], path: "refusalRules")
        try rejectUnknownArray(object["riskGates"], allowed: ["category", "level", "decision", "basis"], path: "riskGates")
        try rejectUnknownArray(object["safetyGates"], allowed: ["category", "level", "decision", "basis"], path: "safetyGates")
        try rejectUnknown(object["expectedCost"], allowed: ["latency", "monetary", "privacy"], path: "expectedCost")
        try rejectUnknownArray(object["provenance"], allowed: ["sourceId", "claim", "sourceRole", "confidence"], path: "provenance")
        try rejectUnknown(object["validation"], allowed: ["implemented", "visuallyVerified", "finalCutEvidence", "verifiedOn", "notes"], path: "validation")
        if object["conflicts"] != nil {
            try rejectUnknownArray(object["conflicts"], allowed: ["description", "sourceIds", "resolution"], path: "conflicts")
        }
    }

    private static func isVerifiedRepositoryEvidence(_ sourceID: String, relativeTo directory: URL) -> Bool {
        guard sourceID.hasPrefix("docs/") else { return false }
        let root = directory.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL
        let docsRoot = root.appendingPathComponent("docs", isDirectory: true).standardizedFileURL
        let candidate = root.appendingPathComponent(sourceID).standardizedFileURL
        guard candidate.path.hasPrefix(docsRoot.path + "/") else { return false }
        let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }
    private static func validateStrictSemantics(_ card: TechniqueCard) throws {
        func fail(_ detail: String) throws { throw EditorialKnowledgeCatalogError.strictSchemaViolation(cardID: card.id, detail: detail) }
        guard !card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !card.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { try fail("name and summary must be nonempty"); return }
        guard !card.mediaPrerequisites.isEmpty, !(card.refusalConditions ?? []).isEmpty, !(card.safety ?? []).isEmpty else { try fail("media prerequisites, refusal conditions, and safety explanations must be explicit"); return }
        guard !card.prerequisiteRules.isEmpty, !card.riskGates.isEmpty, !card.safetyGates.isEmpty else { try fail("typed prerequisite, risk, and safety rules are required"); return }
        guard (card.riskGates + card.safetyGates).allSatisfy({ !$0.basis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { try fail("every risk and safety gate needs an evidence basis"); return }
        for rule in card.prerequisiteRules + card.refusalRules {
            switch rule.kind {
            case .mediaKind: guard rule.mediaKind != nil else { try fail("media_kind requires mediaKind"); return }
            case .requiredRole: guard rule.role != nil else { try fail("required_role requires role"); return }
            case .roleCount: guard let count = rule.count, count >= 0 else { try fail("role_count requires a nonnegative count"); return }
            case .audioPresence: guard rule.hasAudio != nil else { try fail("audio_presence requires hasAudio"); return }
            case .minDimensions: guard (rule.minWidth ?? 0) > 0, (rule.minHeight ?? 0) > 0 else { try fail("min_dimensions requires positive dimensions"); return }
            case .confirmedTarget: break
            }
        }
        guard let cost = card.expectedCost, cost.latency != nil, cost.monetary != nil, cost.privacy != nil else { try fail("expectedCost must name latency, monetary, and privacy"); return }
        guard !card.provenance.isEmpty, card.provenance.allSatisfy({ !$0.claim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { try fail("claim-level provenance is required"); return }
        for parameter in card.parameters {
            guard !parameter.key.isEmpty, parameter.liveness != nil else { try fail("parameter metadata is incomplete"); return }
            guard parameter.defaultValue != nil else { try fail("parameter \(parameter.key) has no default"); return }
            if parameter.type == .float || parameter.type == .int || parameter.type == .duration { guard parameter.unit != nil, parameter.range?.count == 2 else { try fail("parameter \(parameter.key) needs units and bounds"); return } }
        }
        if card.status == .validated { guard card.construction.requiredEffectID != nil, !card.validation.finalCutEvidence.orEmpty.isEmpty, !card.validation.verifiedOn.orEmpty.isEmpty else { try fail("validated card needs an effect and implementation evidence distinct from prose"); return } }
    }

    /// Reads the source IDs out of the bundled catalog CSV so provenance can be
    /// checked against something real rather than trusted.
    public static func sourceIDs(fromCSV url: URL) -> Set<String> {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var ids: Set<String> = []
        for (offset, line) in text.split(separator: "\n").enumerated() where offset > 0 {
            if let first = line.split(separator: ",").first {
                ids.insert(String(first).trimmingCharacters(in: CharacterSet(charactersIn: "\" ")))
            }
        }
        return ids
    }

    // MARK: - Retrieval

    /// What a caller is looking for. Every field narrows; none widens.
    public struct Query: Sendable {
        public var domains: Set<TechniqueDomain>
        public var intentTags: Set<String>
        public var mediaKinds: Set<LocalMediaKind>
        public var admittedCapabilities: Set<String>
        /// When true, only cards that can actually be run are returned.
        public var executableOnly: Bool
        /// Whether an intent-tag match is **required** or merely preferred.
        ///
        /// Defaults to preferred. A hard filter looks reasonable and behaves
        /// badly: the user writes "give this some atmosphere", no validated card
        /// happens to carry that exact tag, and the result is zero options
        /// despite several techniques being perfectly runnable. Ranking by
        /// overlap keeps the best match first without letting vocabulary gaps
        /// empty the list.
        public var requireIntentMatch: Bool
        /// Cap on returned cards. The planner must not ingest the whole atlas.
        public var limit: Int

        public init(
            domains: Set<TechniqueDomain> = [],
            intentTags: Set<String> = [],
            mediaKinds: Set<LocalMediaKind> = [],
            admittedCapabilities: Set<String> = [],
            executableOnly: Bool = true,
            requireIntentMatch: Bool = false,
            limit: Int = 8
        ) {
            self.domains = domains
            self.intentTags = intentTags
            self.mediaKinds = mediaKinds
            self.admittedCapabilities = admittedCapabilities
            self.executableOnly = executableOnly
            self.requireIntentMatch = requireIntentMatch
            self.limit = limit
        }
    }

    /// Returns a small, deterministically ordered set.
    ///
    /// Ordering is by intent-match strength then card id — never by anything
    /// time- or randomness-dependent, so the same query always produces the same
    /// list. Option generation depends on that determinism.
    public func retrieve(_ query: Query) -> [TechniqueCard] {
        let matches = cards.filter { card in
            if !query.domains.isEmpty, !query.domains.contains(card.domain) { return false }
            if query.executableOnly, !card.isExecutable(admittedCapabilities: query.admittedCapabilities) { return false }
            if !query.mediaKinds.isEmpty, !card.requiredMediaKinds.isEmpty, card.requiredMediaKinds.isDisjoint(with: query.mediaKinds) { return false }
            if query.requireIntentMatch, !query.intentTags.isEmpty,
               query.intentTags.isDisjoint(with: Set(card.intentTags)) { return false }
            return true
        }
        return matches
            .sorted { lhs, rhs in
                let left = query.intentTags.intersection(Set(lhs.intentTags)).count
                let right = query.intentTags.intersection(Set(rhs.intentTags)).count
                if left != right { return left > right }
                return lhs.id < rhs.id
            }
            .prefix(query.limit)
            .map { $0 }
    }

    public func card(id: String) -> TechniqueCard? { cards.first { $0.id == id } }

    /// Cards that would be relevant but cannot run, with the reason — so the UI
    /// can say why an option set is small instead of silently padding it.
    public func unavailable(for query: Query) -> [(card: TechniqueCard, reason: String)] {
        cards.compactMap { card in
            if !query.domains.isEmpty, !query.domains.contains(card.domain) { return nil }
            guard let reason = card.unavailabilityReason(admittedCapabilities: query.admittedCapabilities) else { return nil }
            return (card, reason)
        }
        .sorted { $0.card.id < $1.card.id }
    }
}

private extension Optional where Wrapped == [String] { var orEmpty: [String] { self ?? [] } }
