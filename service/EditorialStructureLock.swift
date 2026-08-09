import Foundation

/// Lossless timeline time.  Frame counts are retained for compatibility, while
/// this value prevents a 23.976/29.97 source from being rounded into a different
/// editorial decision.
public struct RationalTime: Codable, Equatable, Sendable, Hashable, Comparable {
    public let numerator: Int64
    public let denominator: Int64
    public init(_ numerator: Int64, _ denominator: Int64 = 1) {
        // This API predates throwing construction.  Preserve every
        // representable ratio, but canonicalize a zero denominator or a ratio
        // whose positive canonical form cannot fit in Int64 to zero rather
        // than trapping.  Decoding is stricter and rejects those inputs.
        let normalized = RationalTime.normalized(numerator, denominator) ?? (0, 1)
        self.numerator = normalized.numerator
        self.denominator = normalized.denominator
    }
    public static func < (lhs: RationalTime, rhs: RationalTime) -> Bool {
        if lhs.numerator == rhs.numerator && lhs.denominator == rhs.denominator { return false }
        let leftNegative = lhs.numerator < 0, rightNegative = rhs.numerator < 0
        if leftNegative != rightNegative { return leftNegative }
        if lhs.numerator == 0 || rhs.numerator == 0 { return lhs.numerator == 0 && rhs.numerator != 0 }
        let positive = RationalTime.positiveLess(RationalTime.magnitude(lhs.numerator), UInt64(lhs.denominator), RationalTime.magnitude(rhs.numerator), UInt64(rhs.denominator))
        return leftNegative ? !positive : positive
    }
    private enum CodingKeys: String, CodingKey { case numerator, denominator }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); let n = try c.decode(Int64.self, forKey: .numerator); let d = try c.decode(Int64.self, forKey: .denominator)
        guard let normalized = RationalTime.normalized(n, d) else {
            throw DecodingError.dataCorruptedError(forKey: .denominator, in: c, debugDescription: "rational time cannot be represented with a positive Int64 denominator")
        }
        numerator = normalized.numerator
        denominator = normalized.denominator
    }
    private static func magnitude(_ value: Int64) -> UInt64 { value < 0 ? (~UInt64(bitPattern: value)) &+ 1 : UInt64(value) }
    private static func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 { b == 0 ? max(1, a) : gcd(b, a % b) }
    private static func normalized(_ numerator: Int64, _ denominator: Int64) -> (numerator: Int64, denominator: Int64)? {
        guard denominator != 0 else { return nil }
        let divisor = gcd(magnitude(numerator), magnitude(denominator))
        // `Int64.min / Int64.min` is exactly one, even though its unsigned
        // common divisor is one larger than Int64.max.
        if divisor == UInt64(Int64.max) + 1 {
            return numerator == Int64.min && denominator == Int64.min ? (1, 1) : nil
        }
        let divisor64 = Int64(divisor)
        let sign: Int64 = denominator < 0 ? -1 : 1
        let normalizedNumerator = (numerator / divisor64).multipliedReportingOverflow(by: sign)
        let normalizedDenominator = (denominator / divisor64).multipliedReportingOverflow(by: sign)
        guard !normalizedNumerator.overflow, !normalizedDenominator.overflow else { return nil }
        return (normalizedNumerator.partialValue, normalizedDenominator.partialValue)
    }
    /// Exact continued-fraction comparison for positive fractions. It never
    /// multiplies numerators/denominators and therefore cannot overflow.
    private static func positiveLess(_ a0: UInt64, _ b0: UInt64, _ c0: UInt64, _ d0: UInt64) -> Bool {
        var a = a0, b = b0, c = c0, d = d0, inverted = false
        while true {
            let qa = a / b, qc = c / d
            if qa != qc { return inverted ? qa > qc : qa < qc }
            let ra = a % b, rc = c % d
            if ra == 0 || rc == 0 {
                if ra == 0 && rc == 0 { return false }
                let result = ra == 0
                return inverted ? !result : result
            }
            (a, b, c, d) = (b, ra, d, rc)
            inverted.toggle()
        }
    }
}

public struct LockedClipPlacement: Codable, Equatable, Sendable {
    public let sourceIdentity: SourceIdentity
    public let index: Int
    public let timelineStartFrame: Int
    public let durationFrames: Int
    public let sourceStartFrame: Int
    public let speedMultiplier: Double
    public let audioSyncOffsetFrames: Int
    public let timelineStart: RationalTime
    public let duration: RationalTime
    public let sourceStart: RationalTime
    // These are intentionally not part of the wire format.  A caller that
    // omitted a rational time asked us to derive it from the frame count;
    // supplying even the historical raw-frame shorthand is an explicit claim
    // that must survive validation unchanged.
    fileprivate let hasExplicitTimelineStart: Bool
    fileprivate let hasExplicitDuration: Bool
    fileprivate let hasExplicitSourceStart: Bool

    public init(sourceIdentity: SourceIdentity, index: Int, timelineStartFrame: Int, durationFrames: Int, sourceStartFrame: Int = 0, speedMultiplier: Double = 1.0, audioSyncOffsetFrames: Int = 0, timelineStart: RationalTime? = nil, duration: RationalTime? = nil, sourceStart: RationalTime? = nil) {
        self.sourceIdentity = sourceIdentity; self.index = index; self.timelineStartFrame = timelineStartFrame; self.durationFrames = durationFrames; self.sourceStartFrame = sourceStartFrame; self.speedMultiplier = speedMultiplier; self.audioSyncOffsetFrames = audioSyncOffsetFrames
        self.hasExplicitTimelineStart = timelineStart != nil
        self.hasExplicitDuration = duration != nil
        self.hasExplicitSourceStart = sourceStart != nil
        self.timelineStart = timelineStart ?? RationalTime(Int64(timelineStartFrame))
        self.duration = duration ?? RationalTime(Int64(durationFrames))
        self.sourceStart = sourceStart ?? RationalTime(Int64(sourceStartFrame))
    }
    private enum CodingKeys: String, CodingKey { case sourceIdentity, index, timelineStartFrame, durationFrames, sourceStartFrame, speedMultiplier, audioSyncOffsetFrames, timelineStart, duration, sourceStart }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sourceIdentity: try c.decode(SourceIdentity.self, forKey: .sourceIdentity),
            index: try c.decode(Int.self, forKey: .index),
            timelineStartFrame: try c.decode(Int.self, forKey: .timelineStartFrame),
            durationFrames: try c.decode(Int.self, forKey: .durationFrames),
            sourceStartFrame: try c.decode(Int.self, forKey: .sourceStartFrame),
            speedMultiplier: try c.decode(Double.self, forKey: .speedMultiplier),
            audioSyncOffsetFrames: try c.decode(Int.self, forKey: .audioSyncOffsetFrames),
            timelineStart: try c.decode(RationalTime.self, forKey: .timelineStart),
            duration: try c.decode(RationalTime.self, forKey: .duration),
            sourceStart: try c.decode(RationalTime.self, forKey: .sourceStart)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sourceIdentity, forKey: .sourceIdentity); try c.encode(index, forKey: .index); try c.encode(timelineStartFrame, forKey: .timelineStartFrame)
        try c.encode(durationFrames, forKey: .durationFrames); try c.encode(sourceStartFrame, forKey: .sourceStartFrame); try c.encode(speedMultiplier, forKey: .speedMultiplier)
        try c.encode(audioSyncOffsetFrames, forKey: .audioSyncOffsetFrames); try c.encode(timelineStart, forKey: .timelineStart); try c.encode(duration, forKey: .duration); try c.encode(sourceStart, forKey: .sourceStart)
    }
    public static func == (lhs: LockedClipPlacement, rhs: LockedClipPlacement) -> Bool {
        lhs.sourceIdentity == rhs.sourceIdentity && lhs.index == rhs.index && lhs.timelineStartFrame == rhs.timelineStartFrame && lhs.durationFrames == rhs.durationFrames && lhs.sourceStartFrame == rhs.sourceStartFrame && lhs.speedMultiplier == rhs.speedMultiplier && lhs.audioSyncOffsetFrames == rhs.audioSyncOffsetFrames && lhs.timelineStart == rhs.timelineStart && lhs.duration == rhs.duration && lhs.sourceStart == rhs.sourceStart
    }
    public var timelineEndFrame: Int { timelineStartFrame + durationFrames }
}

public struct ProtectedRegion: Codable, Equatable, Sendable {
    public let identifier: String; public let x: Double; public let y: Double; public let width: Double; public let height: Double; public let maximumOccludedFraction: Double
    public init(identifier: String, x: Double, y: Double, width: Double, height: Double, maximumOccludedFraction: Double = 0) { self.identifier = identifier; self.x = x; self.y = y; self.width = width; self.height = height; self.maximumOccludedFraction = maximumOccludedFraction }
}

/// Computed by the actual treatment construction, never copied from a lock.
public struct ProtectedRegionImpactEvidence: Codable, Equatable, Sendable {
    public let identifier: String; public let occludedFraction: Double; public let croppedFraction: Double
    public init(identifier: String, occludedFraction: Double, croppedFraction: Double = 0) { self.identifier = identifier; self.occludedFraction = occludedFraction; self.croppedFraction = croppedFraction }
    public var lostFraction: Double { max(occludedFraction, croppedFraction) }
}

public struct AuthorizedStructuralDelta: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case reorder, remove, substitute, retime, changeDuration, changeEditPoint, changeSync }
    public let kind: Kind
    public let affectedClipIndices: [Int]
    public let userRequest: String
    /// Canonical field-value transition.  An authorization without these exact
    /// values is deliberately inert; it can be displayed but cannot waive a lock.
    public let beforeValue: String?
    public let afterValue: String?
    public init(kind: Kind, affectedClipIndices: [Int], userRequest: String, beforeValue: String? = nil, afterValue: String? = nil) { self.kind = kind; self.affectedClipIndices = affectedClipIndices; self.userRequest = userRequest; self.beforeValue = beforeValue; self.afterValue = afterValue }
}

public enum EditorialStructureViolation: Error, LocalizedError, Equatable, Sendable {
    case invalidClipIndices
    case invalidSourceIdentity(index: Int)
    case invalidTiming(index: Int)
    case clipCountChanged(locked: Int, candidate: Int)
    case clipReordered(index: Int, lockedItem: String, candidateItem: String)
    case mediaSubstituted(index: Int, lockedDigest: String, candidateDigest: String)
    case durationChanged(index: Int, locked: Int, candidate: Int)
    case editPointMoved(index: Int, locked: Int, candidate: Int)
    case sourceRangeChanged(index: Int, locked: Int, candidate: Int)
    case retimed(index: Int, locked: Double, candidate: Double)
    case syncChanged(index: Int, locked: Int, candidate: Int)
    case protectedRegionEvidenceMissing(String)
    case protectedRegionLost(identifier: String, occluded: Double, allowed: Double)
    case authorizationMutated
    case fingerprintMismatch(expected: String, actual: String)
    case narrationChanged
    case musicStructureChanged
    public var errorDescription: String? {
        switch self {
        case .clipCountChanged: return "Clip count changed. FrameSmith may not add or remove your clips."
        case .clipReordered(let index, _, _): return "Clip order changed at position \(index + 1). Your ordering is yours."
        case .mediaSubstituted(let index, _, _): return "Different media at position \(index + 1)."
        case .durationChanged(let index, let locked, let candidate): return "Clip \(index + 1) duration changed from \(locked) to \(candidate) frames."
        case .editPointMoved(let index, let locked, let candidate): return "Clip \(index + 1) start moved from frame \(locked) to \(candidate)."
        case .sourceRangeChanged(let index, _, _): return "Clip \(index + 1) source in-point moved."
        case .retimed(let index, _, _): return "Clip \(index + 1) speed changed."
        case .syncChanged(let index, _, _): return "Clip \(index + 1) audio sync changed."
        case .protectedRegionLost(let identifier, _, _): return "Protected region '\(identifier)' would be lost beyond its tolerance."
        case .protectedRegionEvidenceMissing(let identifier): return "Protected region '\(identifier)' has no computed impact evidence."
        case .fingerprintMismatch: return "The editorial structure changed after planning began."
        case .narrationChanged: return "Narration is protected and may not be rewritten or moved."
        case .musicStructureChanged: return "Music structure is protected and may not be restructured."
        case .invalidClipIndices: return "Clip indices must be unique and contiguous in supplied editorial order."
        case .invalidSourceIdentity(let index): return "Clip \(index + 1) has an incomplete source identity."
        case .invalidTiming(let index): return "Clip \(index + 1) has invalid rational timing."
        case .authorizationMutated: return "A candidate tried to alter the director's authorization."
        }
    }
}

public struct EditorialStructureLock: Codable, Equatable, Sendable {
    /// Supplied order is intentionally retained.  Invalid order is refused by
    /// validation rather than silently "fixed" by sorting.
    public let clips: [LockedClipPlacement]
    public let protectedRegions: [ProtectedRegion]
    public let narrationDigest: String?
    public let musicStructureDigest: String?
    public let authorizedDeltas: [AuthorizedStructuralDelta]
    public let frameRate: Int
    public let frameDuration: RationalTime

    public init(clips: [LockedClipPlacement], protectedRegions: [ProtectedRegion] = [], narrationDigest: String? = nil, musicStructureDigest: String? = nil, authorizedDeltas: [AuthorizedStructuralDelta] = [], frameRate: Int = 30, frameDuration: RationalTime? = nil) {
        let resolvedFrameDuration = frameDuration ?? RationalTime(1, Int64(max(1, frameRate)))
        // Older callers supplied only frame-count fields, whose historical
        // default rational values were the bare counts. Convert only fields
        // omitted by the caller; an explicit rational is never rewritten and
        // is rejected by `selfIntrinsicViolations()` if it disagrees with its
        // frame count.
        self.clips = clips.map { clip in
            let timelineStart = clip.hasExplicitTimelineStart ? clip.timelineStart : Self.time(forFrames: clip.timelineStartFrame, frameDuration: resolvedFrameDuration)
            let duration = clip.hasExplicitDuration ? clip.duration : Self.time(forFrames: clip.durationFrames, frameDuration: resolvedFrameDuration)
            let sourceStart = clip.hasExplicitSourceStart ? clip.sourceStart : Self.time(forFrames: clip.sourceStartFrame, frameDuration: resolvedFrameDuration)
            return LockedClipPlacement(
                sourceIdentity: clip.sourceIdentity, index: clip.index,
                timelineStartFrame: clip.timelineStartFrame, durationFrames: clip.durationFrames,
                sourceStartFrame: clip.sourceStartFrame, speedMultiplier: clip.speedMultiplier,
                audioSyncOffsetFrames: clip.audioSyncOffsetFrames, timelineStart: timelineStart,
                duration: duration, sourceStart: sourceStart
            )
        }
        self.protectedRegions = protectedRegions; self.narrationDigest = narrationDigest; self.musicStructureDigest = musicStructureDigest; self.authorizedDeltas = authorizedDeltas; self.frameRate = frameRate; self.frameDuration = resolvedFrameDuration
    }
    public static func establish(orderedMedia: [LocalMediaAsset], clipDurationFrames: [Int], frameRate: Int = 30, protectedRegions: [ProtectedRegion] = []) -> EditorialStructureLock {
        var cursor = 0
        let clips = orderedMedia.enumerated().map { index, asset -> LockedClipPlacement in
            let duration = index < clipDurationFrames.count ? clipDurationFrames[index] : 0
            defer { cursor += duration }
            return LockedClipPlacement(sourceIdentity: asset.sourceIdentity, index: index, timelineStartFrame: cursor, durationFrames: duration)
        }
        return EditorialStructureLock(clips: clips, protectedRegions: protectedRegions, frameRate: frameRate)
    }
    public var fingerprint: String { ContentHasher.sha256(Data(canonicalMaterial.utf8)) }
    private var canonicalMaterial: String {
        let clipValues = clips.map { c in ["clip", "\(c.index)", c.sourceIdentity.itemID, c.sourceIdentity.canonicalPath, c.sourceIdentity.sha256, "\(c.timelineStart.numerator)/\(c.timelineStart.denominator)", "\(c.duration.numerator)/\(c.duration.denominator)", "\(c.sourceStart.numerator)/\(c.sourceStart.denominator)", String(c.speedMultiplier.bitPattern), "\(c.audioSyncOffsetFrames)"].joined(separator: "\u{1f}") }
        let regions = protectedRegions.sorted { $0.identifier < $1.identifier }.map { "region\u{1f}\($0.identifier)\u{1f}\($0.x.bitPattern)\u{1f}\($0.y.bitPattern)\u{1f}\($0.width.bitPattern)\u{1f}\($0.height.bitPattern)\u{1f}\($0.maximumOccludedFraction.bitPattern)" }
        let narration = narrationDigest ?? ""
        let music = musicStructureDigest ?? ""
        return (["frame\u{1f}\(frameDuration.numerator)/\(frameDuration.denominator)"] + clipValues + regions + ["narration\u{1f}\(narration)", "music\u{1f}\(music)"]).joined(separator: "\u{1e}")
    }
    public func violations(comparedTo candidate: EditorialStructureLock, impactEvidence: [ProtectedRegionImpactEvidence]? = nil) -> [EditorialStructureViolation] {
        var found = selfIntrinsicViolations()
        found.append(contentsOf: candidate.selfIntrinsicViolations())
        if frameRate != candidate.frameRate || frameDuration != candidate.frameDuration { found.append(.invalidTiming(index: -1)) }
        if protectedRegions != candidate.protectedRegions { found.append(.protectedRegionEvidenceMissing("protected-region definition drift")) }
        if candidate.authorizedDeltas != authorizedDeltas { found.append(.authorizationMutated) }
        guard clips.count == candidate.clips.count else { return found + [.clipCountChanged(locked: clips.count, candidate: candidate.clips.count)] }
        for (locked, other) in zip(clips, candidate.clips) {
            let index = locked.index
            if locked.sourceIdentity != other.sourceIdentity {
                if clips.contains(where: { $0.sourceIdentity == other.sourceIdentity }) { found.append(.clipReordered(index: index, lockedItem: locked.sourceIdentity.itemID, candidateItem: other.sourceIdentity.itemID)) }
                else { found.append(.mediaSubstituted(index: index, lockedDigest: locked.sourceIdentity.sha256, candidateDigest: other.sourceIdentity.sha256)) }
            }
            compare(locked.durationFrames, other.durationFrames, kind: .changeDuration, index: index, violation: .durationChanged(index: index, locked: locked.durationFrames, candidate: other.durationFrames), into: &found)
            compare(locked.timelineStartFrame, other.timelineStartFrame, kind: .changeEditPoint, index: index, violation: .editPointMoved(index: index, locked: locked.timelineStartFrame, candidate: other.timelineStartFrame), into: &found)
            compare(locked.sourceStartFrame, other.sourceStartFrame, kind: .changeEditPoint, index: index, violation: .sourceRangeChanged(index: index, locked: locked.sourceStartFrame, candidate: other.sourceStartFrame), into: &found)
            if locked.speedMultiplier != other.speedMultiplier, !authorizes(.retime, index, before: exact(locked.speedMultiplier), after: exact(other.speedMultiplier)) { found.append(.retimed(index: index, locked: locked.speedMultiplier, candidate: other.speedMultiplier)) }
            compare(locked.audioSyncOffsetFrames, other.audioSyncOffsetFrames, kind: .changeSync, index: index, violation: .syncChanged(index: index, locked: locked.audioSyncOffsetFrames, candidate: other.audioSyncOffsetFrames), into: &found)
            if locked.timelineStart != other.timelineStart, !authorizes(.changeEditPoint, index, before: "timing", after: "timing") { found.append(.invalidTiming(index: index)) }
            if locked.duration != other.duration, !authorizes(.changeDuration, index, before: String(locked.durationFrames), after: String(other.durationFrames)) { found.append(.invalidTiming(index: index)) }
            if locked.sourceStart != other.sourceStart, !authorizes(.changeEditPoint, index, before: String(locked.sourceStartFrame), after: String(other.sourceStartFrame)) { found.append(.invalidTiming(index: index)) }
        }
        if narrationDigest != candidate.narrationDigest { found.append(.narrationChanged) }; if musicStructureDigest != candidate.musicStructureDigest { found.append(.musicStructureChanged) }
        if !protectedRegions.isEmpty {
            guard let evidence = impactEvidence else { found.append(contentsOf: protectedRegions.map { .protectedRegionEvidenceMissing($0.identifier) }); return found }
            for region in protectedRegions { guard let impact = evidence.first(where: { $0.identifier == region.identifier }) else { found.append(.protectedRegionEvidenceMissing(region.identifier)); continue }; if !impact.lostFraction.isFinite || impact.lostFraction > region.maximumOccludedFraction { found.append(.protectedRegionLost(identifier: region.identifier, occluded: impact.lostFraction, allowed: region.maximumOccludedFraction)) } }
        }
        return found
    }
    public func validate(_ candidate: EditorialStructureLock, impactEvidence: [ProtectedRegionImpactEvidence]? = nil) throws { if let first = violations(comparedTo: candidate, impactEvidence: impactEvidence).first { throw first } }
    public func validateFingerprint(_ claimed: String) throws { guard claimed == fingerprint else { throw EditorialStructureViolation.fingerprintMismatch(expected: fingerprint, actual: claimed) } }
    public func humanReadableDiff(comparedTo candidate: EditorialStructureLock) -> String { let found = violations(comparedTo: candidate); return found.isEmpty ? "No change to your clips, order, timing, or sync." : found.map { "• \($0.errorDescription ?? String(describing: $0))" }.joined(separator: "\n") }
    private func selfIntrinsicViolations() -> [EditorialStructureViolation] {
        var result: [EditorialStructureViolation] = []
        if frameRate <= 0 || frameDuration.numerator <= 0 || frameDuration.denominator <= 0 || clips.map(\.index) != Array(clips.indices) { result.append(.invalidClipIndices) }
        let names = protectedRegions.map(\.identifier)
        if Set(names).count != names.count || protectedRegions.contains(where: { $0.identifier.isEmpty || !$0.x.isFinite || !$0.y.isFinite || !$0.width.isFinite || !$0.height.isFinite || !$0.maximumOccludedFraction.isFinite || $0.x < 0 || $0.y < 0 || $0.width <= 0 || $0.height <= 0 || $0.x + $0.width > 1 || $0.y + $0.height > 1 || !(0...1).contains($0.maximumOccludedFraction) }) { result.append(.invalidClipIndices) }
        // `frameRate` is the legacy nominal integer (24/30/60), while
        // `frameDuration` is authoritative and may represent an exact NTSC
        // rate such as 1001/30000.  Require the exact reciprocal to round to
        // that nominal integer without converting either side through Double.
        let twiceDenominator = frameDuration.denominator.multipliedReportingOverflow(by: 2)
        let lowerRate = Int64(frameRate).multipliedReportingOverflow(by: 2)
        let upperRate = lowerRate.partialValue.addingReportingOverflow(1)
        let lowerNominal = lowerRate.partialValue.subtractingReportingOverflow(1)
        let lowerBound = lowerNominal.partialValue.multipliedReportingOverflow(by: frameDuration.numerator)
        let upperBound = upperRate.partialValue.multipliedReportingOverflow(by: frameDuration.numerator)
        let rateMatchesFrameDuration = frameRate > 0
            && !twiceDenominator.overflow && !lowerRate.overflow
            && !upperRate.overflow && !lowerNominal.overflow
            && !lowerBound.overflow && !upperBound.overflow
            && twiceDenominator.partialValue >= lowerBound.partialValue
            && twiceDenominator.partialValue < upperBound.partialValue
        if !rateMatchesFrameDuration { result.append(.invalidTiming(index: -1)) }
        for clip in clips {
            if clip.sourceIdentity.itemID.isEmpty || clip.sourceIdentity.canonicalPath.isEmpty || clip.sourceIdentity.sha256.count != 64 { result.append(.invalidSourceIdentity(index: clip.index)) }
            let countsMatchRationals = clip.timelineStart == Self.time(forFrames: clip.timelineStartFrame, frameDuration: frameDuration)
                && clip.duration == Self.time(forFrames: clip.durationFrames, frameDuration: frameDuration)
                && clip.sourceStart == Self.time(forFrames: clip.sourceStartFrame, frameDuration: frameDuration)
            if clip.durationFrames < 0 || clip.timelineStartFrame < 0 || clip.sourceStartFrame < 0 || !clip.speedMultiplier.isFinite || clip.speedMultiplier <= 0 || clip.duration.numerator < 0 || !countsMatchRationals { result.append(.invalidTiming(index: clip.index)) }
        }
        return result
    }
    private static func time(forFrames frames: Int, frameDuration: RationalTime) -> RationalTime {
        let product = Int64(frames).multipliedReportingOverflow(by: frameDuration.numerator)
        // An overflowing frame count cannot agree with a valid rational lock;
        // retain a sentinel so intrinsic validation fails without trapping on
        // untrusted decoded timeline data.
        guard !product.overflow else { return RationalTime(Int64.max) }
        return RationalTime(product.partialValue, frameDuration.denominator)
    }
    private func compare<T: Equatable>(_ before: T, _ after: T, kind: AuthorizedStructuralDelta.Kind, index: Int, violation: EditorialStructureViolation, into found: inout [EditorialStructureViolation]) { if before != after, !authorizes(kind, index, before: String(describing: before), after: String(describing: after)) { found.append(violation) } }
    private func authorizes(_ kind: AuthorizedStructuralDelta.Kind, _ index: Int, before: String, after: String) -> Bool { authorizedDeltas.contains { $0.kind == kind && $0.affectedClipIndices == [index] && $0.beforeValue == before && $0.afterValue == after && !$0.userRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    private func exact(_ value: Double) -> String { String(value.bitPattern) }
}
