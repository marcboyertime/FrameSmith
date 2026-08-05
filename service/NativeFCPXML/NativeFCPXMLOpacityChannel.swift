import Foundation

/// `<adjust-blend>` — opacity.
///
/// Observed shape: a single `<param name="amount">` carrying one
/// `keyframeAnimation`, with values on a 0–1 scale rather than the
/// inspector's 0–100 percent.
///
/// Unlike `position`, this param does **not** nest. The DTD permits the same
/// `param*` recursion for both; only the capture distinguishes them.
public struct NativeFCPXMLOpacityChannel: Equatable, Sendable {
    public var amount: [NativeFCPXMLKeyframe]

    public init(amount: [NativeFCPXMLKeyframe] = []) {
        self.amount = amount
    }

    public var isEmpty: Bool { amount.isEmpty }

    public var node: NativeFCPXMLNode? {
        guard !isEmpty else { return nil }
        return NativeFCPXMLNode("adjust-blend", children: [
            NativeFCPXMLNode("param", attributes: [("name", "amount")], children: [.keyframeAnimation(amount)])
        ])
    }

    /// A fade held at full opacity until `fadeStartFrame`, reaching
    /// `endOpacity` at `endFrame`.
    ///
    /// Only two keyframes are emitted. The composition model carries three
    /// (`0 / 3.65 / 4`), but Final Cut holds a parameter flat before its first
    /// keyframe, so an explicit one at frame 0 is redundant — the capture
    /// wrote two for exactly this shape.
    public static func fade(
        fadeStartFrame: Int,
        endFrame: Int,
        rate: NativeFCPXMLFrameRate,
        startOpacity: Double = 1,
        endOpacity: Double = 0
    ) -> NativeFCPXMLOpacityChannel {
        NativeFCPXMLOpacityChannel(amount: [
            NativeFCPXMLKeyframe(
                time: NativeFCPXMLStillTiming.keyframeTime(frame: fadeStartFrame, rate: rate),
                value: NativeFCPXMLNumber.string(startOpacity)
            ),
            NativeFCPXMLKeyframe(
                time: NativeFCPXMLStillTiming.keyframeTime(frame: endFrame, rate: rate),
                value: NativeFCPXMLNumber.string(endOpacity)
            )
        ])
    }
}
