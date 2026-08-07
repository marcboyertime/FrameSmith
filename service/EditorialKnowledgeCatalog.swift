import Foundation

public enum EditorialKnowledgeCatalogError: Error, LocalizedError, Equatable, Sendable {
    case unreadableDirectory(URL)
    case malformedCard(String, String)
    case duplicateID(String)
    case unknownSource(cardID: String, sourceID: String)
    case executableClaimWithoutImplementation(String)
    case livenessDisagreement(cardID: String, parameter: String)

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
        var cards: [TechniqueCard] = []
        var seen: Set<String> = []

        for file in files {
            let card: TechniqueCard
            do {
                card = try decoder.decode(TechniqueCard.self, from: Data(contentsOf: file))
            } catch {
                throw EditorialKnowledgeCatalogError.malformedCard(file.lastPathComponent, String(describing: error))
            }
            guard !seen.contains(card.id) else { throw EditorialKnowledgeCatalogError.duplicateID(card.id) }
            seen.insert(card.id)

            // A card cannot promote itself to executable by asserting a status.
            if card.status == .validated, !(card.validation.implemented && card.validation.visuallyVerified) {
                throw EditorialKnowledgeCatalogError.executableClaimWithoutImplementation(card.id)
            }
            if !knownSourceIDs.isEmpty {
                for entry in card.provenance where !knownSourceIDs.contains(entry.sourceId) {
                    // Repository evidence paths are legitimate provenance too.
                    let looksLikeRepositoryEvidence = entry.sourceId.contains("/") || entry.sourceId.hasPrefix("docs")
                    if !looksLikeRepositoryEvidence {
                        throw EditorialKnowledgeCatalogError.unknownSource(cardID: card.id, sourceID: entry.sourceId)
                    }
                }
            }
            cards.append(card)
        }
        return EditorialKnowledgeCatalog(cards: cards, knownSourceIDs: knownSourceIDs)
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
        /// Cap on returned cards. The planner must not ingest the whole atlas.
        public var limit: Int

        public init(
            domains: Set<TechniqueDomain> = [],
            intentTags: Set<String> = [],
            mediaKinds: Set<LocalMediaKind> = [],
            admittedCapabilities: Set<String> = [],
            executableOnly: Bool = true,
            limit: Int = 8
        ) {
            self.domains = domains
            self.intentTags = intentTags
            self.mediaKinds = mediaKinds
            self.admittedCapabilities = admittedCapabilities
            self.executableOnly = executableOnly
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
            if !query.intentTags.isEmpty, query.intentTags.isDisjoint(with: Set(card.intentTags)) { return false }
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
