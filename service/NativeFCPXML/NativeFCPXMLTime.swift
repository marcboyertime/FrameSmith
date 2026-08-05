import Foundation

/// Rational time in the form Final Cut writes it.
///
/// Every observation here comes from the ground-truth capture analysed in
/// `docs/LIVING_STILL_GROUND_TRUTH.md`, not from the DTD, which types every
/// time attribute as bare `CDATA`.
public struct NativeFCPXMLTime: Equatable, Hashable, Sendable {
    public let numerator: Int
    public let timescale: Int

    public init(numerator: Int, timescale: Int) {
        precondition(timescale > 0, "timescale must be positive")
        self.numerator = numerator
        self.timescale = timescale
    }

    /// Final Cut collapses a whole number of seconds to `"4s"` and otherwise
    /// leaves the fraction **unreduced**: it wrote `2594592000/720000s`, not
    /// the reduced equivalent. Reducing would still parse, but the probe is
    /// meant to reproduce the observed construction rather than an equivalent
    /// one, so this does not reduce either.
    public var attributeValue: String {
        if numerator % timescale == 0 { return "\(numerator / timescale)s" }
        return "\(numerator)/\(timescale)s"
    }

    public var seconds: Double { Double(numerator) / Double(timescale) }

    public static func seconds(_ count: Int, timescale: Int = NativeFCPXMLTimescale.clip) -> NativeFCPXMLTime {
        NativeFCPXMLTime(numerator: count * timescale, timescale: timescale)
    }

    public static let zero = NativeFCPXMLTime.seconds(0)

    /// Exact only when the target timescale is a multiple of this one, which
    /// is true for every conversion the emitters perform (3000 → 720000).
    public func converted(toTimescale target: Int) -> NativeFCPXMLTime {
        guard target != timescale else { return self }
        precondition(target % timescale == 0, "inexact timescale conversion \(timescale) → \(target)")
        return NativeFCPXMLTime(numerator: numerator * (target / timescale), timescale: target)
    }

    public static func + (lhs: NativeFCPXMLTime, rhs: NativeFCPXMLTime) -> NativeFCPXMLTime {
        let target = max(lhs.timescale, rhs.timescale)
        let left = lhs.converted(toTimescale: target)
        let right = rhs.converted(toTimescale: target)
        return NativeFCPXMLTime(numerator: left.numerator + right.numerator, timescale: target)
    }
}

/// The two timescales the capture used. Final Cut did not pick one and stay
/// with it: clip geometry is in 3000 and every keyframe time is in 720000.
public enum NativeFCPXMLTimescale {
    /// Clip offsets, durations, and `frameDuration`.
    public static let clip = 3000
    /// Keyframe times. 720000 = 30 fps × 24000.
    public static let keyframe = 720000
}

/// An integer frame rate and the conversions that depend on it.
public struct NativeFCPXMLFrameRate: Equatable, Sendable {
    public let framesPerSecond: Int

    public init(framesPerSecond: Int) {
        precondition(framesPerSecond > 0, "frame rate must be positive")
        self.framesPerSecond = framesPerSecond
    }

    public static let thirty = NativeFCPXMLFrameRate(framesPerSecond: 30)

    /// `100/3000s` at 30 fps — the observed form, not the reduced `1/30s`.
    public func frameDuration(timescale: Int = NativeFCPXMLTimescale.clip) -> NativeFCPXMLTime {
        precondition(timescale % framesPerSecond == 0, "timescale \(timescale) cannot express \(framesPerSecond) fps exactly")
        return NativeFCPXMLTime(numerator: timescale / framesPerSecond, timescale: timescale)
    }

    public func time(frames: Int, timescale: Int = NativeFCPXMLTimescale.clip) -> NativeFCPXMLTime {
        precondition(timescale % framesPerSecond == 0, "timescale \(timescale) cannot express \(framesPerSecond) fps exactly")
        return NativeFCPXMLTime(numerator: frames * (timescale / framesPerSecond), timescale: timescale)
    }

    public func frames(seconds: Double) -> Int {
        Int((seconds * Double(framesPerSecond)).rounded())
    }
}

/// Timing peculiar to still images.
public enum NativeFCPXMLStillTiming {
    /// Final Cut gives an imported still a nominal one-hour source start and
    /// writes every keyframe as an absolute offset from it. A keyframe emitted
    /// at `0s` lands an hour before the clip. Observed, not chosen.
    public static let sourceStartSeconds = 3600

    public static var sourceStart: NativeFCPXMLTime {
        .seconds(sourceStartSeconds)
    }

    /// Absolute keyframe time for a frame index measured from the clip's first
    /// frame, in the 720000 timescale the capture used throughout.
    public static func keyframeTime(frame: Int, rate: NativeFCPXMLFrameRate) -> NativeFCPXMLTime {
        NativeFCPXMLTime.seconds(sourceStartSeconds, timescale: NativeFCPXMLTimescale.keyframe)
            + rate.time(frames: frame, timescale: NativeFCPXMLTimescale.keyframe)
    }
}

/// Where a clip's keyframe times are measured from.
///
/// This distinction was **not** visible from the living still work alone. That
/// capture showed keyframes offset from a one-hour origin and it was reasonable
/// to read the rule as "keyframe times are absolute source time". The rotation
/// capture (`docs/ROTATION_GROUND_TRUTH.md`) disproved the general form: a movie
/// clip whose asset is `start="0s"` got keyframes at `0s` and `2s`.
///
/// So the origin is a property of the **media kind**, and an emitter that
/// hardcoded the still form would place every movie keyframe an hour early —
/// in a document that imports without complaint.
///
/// The origin is also *not derivable from the asset*: the connected-layer
/// capture showed a still whose asset declared `start="0s"` while its clip
/// referenced `3602.9s`. Final Cut applies the convention; it does not store it.
public enum NativeFCPXMLTimingOrigin: Equatable, Sendable {
    /// Stills get a nominal one-hour source start.
    case still
    /// Movies carry real source time. The captured clip's asset was `start="0s"`.
    case movie(startSeconds: Int)

    public static let movieFromZero = NativeFCPXMLTimingOrigin.movie(startSeconds: 0)

    public var sourceStartSeconds: Int {
        switch self {
        case .still: return NativeFCPXMLStillTiming.sourceStartSeconds
        case .movie(let seconds): return seconds
        }
    }

    public var sourceStart: NativeFCPXMLTime {
        .seconds(sourceStartSeconds)
    }

    /// Absolute keyframe time for a frame index measured from the clip's first
    /// frame.
    ///
    /// Both cases use the 720000 keyframe timescale. For the still that is
    /// observed directly. For the movie it is a *choice*: the capture's
    /// keyframes landed on whole seconds (`0s`, `2s`), which render identically
    /// from any timescale, so the underlying one was not observable. A movie
    /// keyframe on a fractional frame will therefore be emitted as
    /// `n/720000s`, which is well-formed rational time but not a reproduction
    /// of anything captured. Recorded as a limitation rather than hidden.
    public func keyframeTime(frame: Int, rate: NativeFCPXMLFrameRate) -> NativeFCPXMLTime {
        NativeFCPXMLTime.seconds(sourceStartSeconds, timescale: NativeFCPXMLTimescale.keyframe)
            + rate.time(frames: frame, timescale: NativeFCPXMLTimescale.keyframe)
    }
}

/// Number formatting that matches the capture's precision.
public enum NativeFCPXMLNumber {
    /// `3.5555555…` → `"3.55556"`, `1.08` → `"1.08"`, `1.0` → `"1"`.
    ///
    /// Five decimal places is what Final Cut emitted for the derived position
    /// value; trailing zeros are trimmed because it wrote `1`, not `1.00000`.
    public static func string(_ value: Double, maximumFractionDigits: Int = 5) -> String {
        let rounded = (value * pow(10, Double(maximumFractionDigits))).rounded() / pow(10, Double(maximumFractionDigits))
        if rounded == rounded.rounded(), abs(rounded) < 1e15 {
            return String(Int(rounded))
        }
        var text = String(format: "%.\(maximumFractionDigits)f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// A paired value such as `"1 1"` or `"1.08 1.08"`.
    public static func pair(_ x: Double, _ y: Double, maximumFractionDigits: Int = 5) -> String {
        "\(string(x, maximumFractionDigits: maximumFractionDigits)) \(string(y, maximumFractionDigits: maximumFractionDigits))"
    }
}
