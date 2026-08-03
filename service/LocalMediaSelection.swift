import Foundation

public enum LocalMediaRole: String, Codable, CaseIterable, Sendable {
    case primary
    case outgoing
    case incoming
}

public struct LocalMediaSlot: Codable, Equatable, Sendable {
    public let role: LocalMediaRole
    public let media: LocalMediaAsset

    public init(role: LocalMediaRole, media: LocalMediaAsset) {
        self.role = role
        self.media = media
    }
}

public enum LocalMediaSelectionError: Error, LocalizedError, Equatable, Sendable {
    case missingRole(LocalMediaRole)
    case unexpectedRole(LocalMediaRole)
    case duplicateSource(String)

    public var errorDescription: String? {
        switch self {
        case .missingRole(let role): return "Local planning requires a \(role.rawValue) media source"
        case .unexpectedRole(let role): return "\(role.rawValue) media is not used by this workflow"
        case .duplicateSource(let path): return "A local source can fill only one role: \(path)"
        }
    }
}

/// A local file selection is intentionally distinct from a Final Cut timeline
/// selection. Its token has no spine or adjacency assertion; CapabilityGate
/// keeps every FCPXML operation closed for this evidence origin.
public struct LocalMediaSelection: Codable, Equatable, Sendable {
    public static let timelineID = "local-media-preview"

    public let slots: [LocalMediaSlot]
    public let token: SelectionToken

    public init(effectID: EffectID, primary: LocalMediaAsset?, outgoing: LocalMediaAsset?, incoming: LocalMediaAsset?) throws {
        switch effectID {
        case .naturalDissolve:
            guard primary == nil else { throw LocalMediaSelectionError.unexpectedRole(.primary) }
            guard let outgoing else { throw LocalMediaSelectionError.missingRole(.outgoing) }
            guard let incoming else { throw LocalMediaSelectionError.missingRole(.incoming) }
            try Self.requireDistinct([outgoing, incoming])
            slots = [LocalMediaSlot(role: .outgoing, media: outgoing), LocalMediaSlot(role: .incoming, media: incoming)]
            token = Self.token(type: .twoAdjacentClips, media: [outgoing, incoming])
        case .targetedRotateZoom, .oldTelevision, .livingStill:
            guard let primary else { throw LocalMediaSelectionError.missingRole(.primary) }
            guard outgoing == nil else { throw LocalMediaSelectionError.unexpectedRole(.outgoing) }
            guard incoming == nil else { throw LocalMediaSelectionError.unexpectedRole(.incoming) }
            slots = [LocalMediaSlot(role: .primary, media: primary)]
            token = Self.token(type: .singleClip, media: [primary])
        }
    }

    private static func requireDistinct(_ media: [LocalMediaAsset]) throws {
        if Set(media.map(\.canonicalPath)).count != media.count {
            throw LocalMediaSelectionError.duplicateSource(media[0].canonicalPath)
        }
    }

    private static func token(type: SelectionType, media: [LocalMediaAsset]) -> SelectionToken {
        let revisionMaterial = media.map { "\($0.canonicalPath)|\($0.sha256)" }.joined(separator: "\n")
        let revision = "local-\(ContentHasher.sha256(Data(revisionMaterial.utf8)))"
        return SelectionToken(
            tokenID: "local-media-\(ContentHasher.sha256(Data(revisionMaterial.utf8)).prefix(24))",
            selectionType: type,
            timelineID: timelineID,
            clipIDs: media.map(\.itemID),
            sourceIdentities: media.map(\.sourceIdentity),
            revision: revision,
            isSpine: false,
            adjacent: false
        )
    }
}
