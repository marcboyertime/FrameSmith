import Foundation

/// One clip's editorial placement, as the user established it.
///
/// Every field here is something the **user** decided and FrameSmith may not
/// change: which media, where it sits, how long it runs, where it starts in its
/// source, and how its audio lines up. Treatment work animates, composites, and
/// colours *around* these values.
public struct LockedClipPlacement: Codable, Equatable, Sendable {
    /// Stable identity of the admitted media, including its content digest.
    public let sourceIdentity: SourceIdentity
    /// Position in the user's ordering, from 0.
    public let index: Int
    /// Where the clip begins on the timeline, in frames.
    public let timelineStartFrame: Int
    /// How long the clip runs, in frames. This is the edit point pair.
    public let durationFrames: Int
    /// Where the visible portion begins inside the source, in frames.
    public let sourceStartFrame: Int
    /// Playback rate. 1.0 is unretimed; anything else is a retime the user chose.
    public let speedMultiplier: Double
    /// Audio offset relative to picture, in frames. Non-zero is a deliberate slip.
    public let audioSyncOffsetFrames: Int

    public init(
        sourceIdentity: SourceIdentity,
        index: Int,
        timelineStartFrame: Int,
        durationFrames: Int,
        sourceStartFrame: Int = 0,
        speedMultiplier: Double = 1.0,
        audioSyncOffsetFrames: Int = 0
    ) {
        self.sourceIdentity = sourceIdentity
        self.index = index
        self.timelineStartFrame = timelineStartFrame
        self.durationFrames = durationFrames
        self.sourceStartFrame = sourceStartFrame
        self.speedMultiplier = speedMultiplier
        self.audioSyncOffsetFrames = audioSyncOffsetFrames
    }

    /// The frame where this clip ends — the edit point with whatever follows.
    public var timelineEndFrame: Int { timelineStartFrame + durationFrames }
}

/// A region of frame the user marked as protected — a face, a sign, a subject.
///
/// Treatment may move things *around* it but must not crop or occlude it beyond
/// the stated tolerance. Normalized 0–1 against the frame.
public struct ProtectedRegion: Codable, Equatable, Sendable {
    public let identifier: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    /// How much of the region may be lost before this is a violation, 0–1.
    public let maximumOccludedFraction: Double

    public init(
        identifier: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        maximumOccludedFraction: Double = 0
    ) {
        self.identifier = identifier
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.maximumOccludedFraction = maximumOccludedFraction
    }
}

/// A structural change the user **explicitly** asked for.
///
/// Normally empty. Its presence is the only thing that lets a treatment alter
/// locked structure, and it has to name exactly what was authorized — a blanket
/// "user said yes" is not representable here on purpose.
public struct AuthorizedStructuralDelta: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case reorder, remove, substitute, retime, changeDuration, changeEditPoint, changeSync
    }
    public let kind: Kind
    public let affectedClipIndices: [Int]
    /// The user's own words authorizing it, kept so the authorization can be
    /// audited rather than inferred.
    public let userRequest: String

    public init(kind: Kind, affectedClipIndices: [Int], userRequest: String) {
        self.kind = kind
        self.affectedClipIndices = affectedClipIndices
        self.userRequest = userRequest
    }
}

public enum EditorialStructureViolation: Error, LocalizedError, Equatable, Sendable {
    case clipCountChanged(locked: Int, candidate: Int)
    case clipReordered(index: Int, lockedItem: String, candidateItem: String)
    case mediaSubstituted(index: Int, lockedDigest: String, candidateDigest: String)
    case durationChanged(index: Int, locked: Int, candidate: Int)
    case editPointMoved(index: Int, locked: Int, candidate: Int)
    case sourceRangeChanged(index: Int, locked: Int, candidate: Int)
    case retimed(index: Int, locked: Double, candidate: Double)
    case syncChanged(index: Int, locked: Int, candidate: Int)
    case protectedRegionLost(identifier: String, occluded: Double, allowed: Double)
    case fingerprintMismatch(expected: String, actual: String)
    case narrationChanged
    case musicStructureChanged

    public var errorDescription: String? {
        switch self {
        case .clipCountChanged(let locked, let candidate):
            return "Clip count changed from \(locked) to \(candidate). FrameSmith may not add or remove your clips."
        case .clipReordered(let index, let lockedItem, let candidateItem):
            return "Clip order changed at position \(index + 1): expected \(lockedItem), found \(candidateItem). Your ordering is yours."
        case .mediaSubstituted(let index, let lockedDigest, let candidateDigest):
            return "Different media at position \(index + 1): \(lockedDigest.prefix(12))… became \(candidateDigest.prefix(12))…"
        case .durationChanged(let index, let locked, let candidate):
            return "Clip \(index + 1) duration changed from \(locked) to \(candidate) frames. Your edit points do not move."
        case .editPointMoved(let index, let locked, let candidate):
            return "Clip \(index + 1) start moved from frame \(locked) to \(candidate)."
        case .sourceRangeChanged(let index, let locked, let candidate):
            return "Clip \(index + 1) source in-point moved from frame \(locked) to \(candidate). That is a different piece of the take."
        case .retimed(let index, let locked, let candidate):
            return "Clip \(index + 1) speed changed from \(locked)× to \(candidate)×."
        case .syncChanged(let index, let locked, let candidate):
            return "Clip \(index + 1) audio sync changed from \(locked) to \(candidate) frames."
        case .protectedRegionLost(let identifier, let occluded, let allowed):
            return "Protected region '\(identifier)' would lose \(Int(occluded * 100))% of its area; the limit is \(Int(allowed * 100))%."
        case .fingerprintMismatch:
            return "The editorial structure changed after planning began."
        case .narrationChanged: return "Narration is protected and may not be rewritten or moved."
        case .musicStructureChanged: return "Music structure is protected and may not be restructured."
        }
    }
}

/// The user's editorial decisions, captured so they can be **checked** rather
/// than merely promised.
///
/// The contract in `docs/editorial-intelligence/DIRECTOR_CONTROL_CONTRACT.md`
/// says this must be machine-checkable and not only prompt prose. That is the
/// whole point of this type: a treatment generator that drifts gets refused by
/// code, not by an agent remembering a rule.
///
/// ## Why a fingerprint alone is not enough
///
/// `fingerprint` exists for cheap comparison, but `validate(_:)` compares
/// **fields**. A hash tells you *that* something changed; it cannot tell the
/// user *what* changed, and a user whose edit was silently restructured deserves
/// the specific sentence, not "mismatch". Hash equality is also not semantic
/// equality — two structures can hash differently for irrelevant reasons.
public struct EditorialStructureLock: Codable, Equatable, Sendable {
    public let clips: [LockedClipPlacement]
    public let protectedRegions: [ProtectedRegion]
    /// Narration content digest, when narration is present and protected.
    public let narrationDigest: String?
    /// Music structural digest, when music is present and protected.
    public let musicStructureDigest: String?
    /// Normally empty. Anything here was explicitly requested by the user.
    public let authorizedDeltas: [AuthorizedStructuralDelta]
    public let frameRate: Int

    public init(
        clips: [LockedClipPlacement],
        protectedRegions: [ProtectedRegion] = [],
        narrationDigest: String? = nil,
        musicStructureDigest: String? = nil,
        authorizedDeltas: [AuthorizedStructuralDelta] = [],
        frameRate: Int = 30
    ) {
        self.clips = clips.sorted { $0.index < $1.index }
        self.protectedRegions = protectedRegions
        self.narrationDigest = narrationDigest
        self.musicStructureDigest = musicStructureDigest
        self.authorizedDeltas = authorizedDeltas
        self.frameRate = frameRate
    }

    /// Establishes the lock from admitted media in the order the user supplied.
    ///
    /// Deliberately takes an ordered array rather than a dictionary: role maps
    /// have no order, and order is exactly what this type exists to protect.
    public static func establish(
        orderedMedia: [LocalMediaAsset],
        clipDurationFrames: [Int],
        frameRate: Int = 30,
        protectedRegions: [ProtectedRegion] = []
    ) -> EditorialStructureLock {
        var placements: [LockedClipPlacement] = []
        var cursor = 0
        for (index, asset) in orderedMedia.enumerated() {
            let duration = index < clipDurationFrames.count ? clipDurationFrames[index] : 0
            placements.append(LockedClipPlacement(
                sourceIdentity: asset.sourceIdentity,
                index: index,
                timelineStartFrame: cursor,
                durationFrames: duration
            ))
            cursor += duration
        }
        return EditorialStructureLock(
            clips: placements,
            protectedRegions: protectedRegions,
            frameRate: frameRate
        )
    }

    /// A stable identifier for this structure, for attaching to treatment
    /// options and comparing cheaply. **Not** a substitute for `validate(_:)`.
    public var fingerprint: String {
        var parts: [String] = ["fr=\(frameRate)"]
        for clip in clips {
            parts.append([
                String(clip.index),
                clip.sourceIdentity.sha256,
                String(clip.timelineStartFrame),
                String(clip.durationFrames),
                String(clip.sourceStartFrame),
                String(format: "%.6f", clip.speedMultiplier),
                String(clip.audioSyncOffsetFrames)
            ].joined(separator: ":"))
        }
        for region in protectedRegions.sorted(by: { $0.identifier < $1.identifier }) {
            parts.append("region:\(region.identifier):\(region.x):\(region.y):\(region.width):\(region.height)")
        }
        if let narrationDigest { parts.append("narration:\(narrationDigest)") }
        if let musicStructureDigest { parts.append("music:\(musicStructureDigest)") }
        return ContentHasher.sha256(Data(parts.joined(separator: "|").utf8))
    }

    /// Field-by-field comparison against a candidate structure.
    ///
    /// Returns **every** violation rather than the first, because a user whose
    /// structure was mangled should see the whole diff in one pass instead of
    /// rerunning to discover the next problem.
    ///
    /// An authorized delta suppresses exactly the violations it names, for
    /// exactly the clips it names. It is not a general amnesty.
    public func violations(comparedTo candidate: EditorialStructureLock) -> [EditorialStructureViolation] {
        var found: [EditorialStructureViolation] = []

        guard clips.count == candidate.clips.count else {
            return [.clipCountChanged(locked: clips.count, candidate: candidate.clips.count)]
        }

        for (locked, other) in zip(clips, candidate.clips) {
            let index = locked.index

            if locked.sourceIdentity.sha256 != other.sourceIdentity.sha256 {
                // Same media present but at a different position is a reorder;
                // media that is not in the lock at all is a substitution. The
                // distinction matters because the sentences differ.
                if clips.contains(where: { $0.sourceIdentity.sha256 == other.sourceIdentity.sha256 }) {
                    found.append(.clipReordered(
                        index: index,
                        lockedItem: locked.sourceIdentity.itemID,
                        candidateItem: other.sourceIdentity.itemID
                    ))
                } else {
                    found.append(.mediaSubstituted(
                        index: index,
                        lockedDigest: locked.sourceIdentity.sha256,
                        candidateDigest: other.sourceIdentity.sha256
                    ))
                }
            }
            if locked.durationFrames != other.durationFrames, !authorizes(.changeDuration, index) {
                found.append(.durationChanged(index: index, locked: locked.durationFrames, candidate: other.durationFrames))
            }
            if locked.timelineStartFrame != other.timelineStartFrame, !authorizes(.changeEditPoint, index) {
                found.append(.editPointMoved(index: index, locked: locked.timelineStartFrame, candidate: other.timelineStartFrame))
            }
            if locked.sourceStartFrame != other.sourceStartFrame, !authorizes(.changeEditPoint, index) {
                found.append(.sourceRangeChanged(index: index, locked: locked.sourceStartFrame, candidate: other.sourceStartFrame))
            }
            if locked.speedMultiplier != other.speedMultiplier, !authorizes(.retime, index) {
                found.append(.retimed(index: index, locked: locked.speedMultiplier, candidate: other.speedMultiplier))
            }
            if locked.audioSyncOffsetFrames != other.audioSyncOffsetFrames, !authorizes(.changeSync, index) {
                found.append(.syncChanged(index: index, locked: locked.audioSyncOffsetFrames, candidate: other.audioSyncOffsetFrames))
            }
        }

        if narrationDigest != candidate.narrationDigest { found.append(.narrationChanged) }
        if musicStructureDigest != candidate.musicStructureDigest { found.append(.musicStructureChanged) }
        return found
    }

    public func validate(_ candidate: EditorialStructureLock) throws {
        let found = violations(comparedTo: candidate)
        if let first = found.first { throw first }
    }

    /// Confirms a treatment option is still describing the structure it was
    /// planned against. Cheap, and safe to call often.
    public func validateFingerprint(_ claimed: String) throws {
        guard claimed == fingerprint else {
            throw EditorialStructureViolation.fingerprintMismatch(expected: fingerprint, actual: claimed)
        }
    }

    /// Human-readable diff, for showing the user exactly what an internal
    /// candidate tried to do to their edit.
    public func humanReadableDiff(comparedTo candidate: EditorialStructureLock) -> String {
        let found = violations(comparedTo: candidate)
        guard !found.isEmpty else { return "No change to your clips, order, timing, or sync." }
        return found.map { "• " + ($0.errorDescription ?? String(describing: $0)) }.joined(separator: "\n")
    }

    private func authorizes(_ kind: AuthorizedStructuralDelta.Kind, _ index: Int) -> Bool {
        authorizedDeltas.contains { $0.kind == kind && $0.affectedClipIndices.contains(index) }
    }
}
