import Foundation

/// One keyframe. `curve` and `interp` are omitted unless set, because Final
/// Cut omitted them on every animated keyframe in the capture.
public struct NativeFCPXMLKeyframe: Equatable, Sendable {
    public let time: NativeFCPXMLTime
    public let value: String
    public let curve: String?
    public let interp: String?

    public init(time: NativeFCPXMLTime, value: String, curve: String? = nil, interp: String? = nil) {
        self.time = time
        self.value = value
        self.curve = curve
        self.interp = interp
    }

    public var node: NativeFCPXMLNode {
        var attributes: [(name: String, value: String)] = [("time", time.attributeValue), ("value", value)]
        if let interp { attributes.append(("interp", interp)) }
        if let curve { attributes.append(("curve", curve)) }
        return NativeFCPXMLNode("keyframe", attributes: attributes)
    }
}

extension NativeFCPXMLNode {
    static func keyframeAnimation(_ keyframes: [NativeFCPXMLKeyframe]) -> NativeFCPXMLNode {
        NativeFCPXMLNode("keyframeAnimation", children: keyframes.map(\.node))
    }
}

/// Unit conversion for `adjust-transform/@position`.
///
/// The inspector displays pixels. The XML does not. Entering `38.4 px` on a
/// 1920×1080 project produced `3.55556`, which is `38.4 / 1080 × 100` — percent
/// of frame **height**, for both axes. Emitting the inspector's own number
/// would pan 10.8× too far *and import cleanly*, so this conversion is the
/// difference between a correct result and a silently wrong one.
public enum NativeFCPXMLTransformUnits {
    public static func position(fromPixels pixels: Double, frameHeight: Int) -> Double {
        precondition(frameHeight > 0, "frame height must be positive")
        return pixels / Double(frameHeight) * 100
    }

    /// Plans store pan as a fraction of image **width**; the XML wants percent
    /// of **height**. Both dimensions are therefore required.
    public static func position(fromWidthFraction fraction: Double, width: Int, height: Int) -> Double {
        position(fromPixels: fraction * Double(width), frameHeight: height)
    }
}

/// `<adjust-transform>` — position and scale.
///
/// The two do **not** share a shape, and that asymmetry is the whole reason
/// this type exists rather than a generic parameter writer:
///
/// - `position` splits into nested `X` (`key="1"`) and `Y` (`key="2"`)
///   sub-params, each carrying its own independent `keyframeAnimation`.
/// - `scale` stays a single param whose keyframe values are space-separated
///   pairs, `"1 1"` → `"1.08 1.08"`.
///
/// Rotation is deliberately absent. Its encoding has not been observed, and
/// `native.targeted_rotate_zoom` must capture it the same way this was
/// captured before emitting one. Guessing it would produce the confound this
/// whole approach exists to avoid.
public struct NativeFCPXMLTransformChannel: Equatable, Sendable {
    public var positionX: [NativeFCPXMLKeyframe]
    public var positionY: [NativeFCPXMLKeyframe]
    public var scale: [NativeFCPXMLKeyframe]

    public init(positionX: [NativeFCPXMLKeyframe] = [], positionY: [NativeFCPXMLKeyframe] = [], scale: [NativeFCPXMLKeyframe] = []) {
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
    }

    public var isEmpty: Bool { positionX.isEmpty && positionY.isEmpty && scale.isEmpty }

    /// `nil` when nothing is animated, so a caller composing channels does not
    /// emit an empty intrinsic that Final Cut never wrote.
    public var node: NativeFCPXMLNode? {
        guard !isEmpty else { return nil }
        var children: [NativeFCPXMLNode] = []

        if !positionX.isEmpty || !positionY.isEmpty {
            var position = NativeFCPXMLNode("param", attributes: [("name", "position")])
            if !positionX.isEmpty {
                position.append(NativeFCPXMLNode("param", attributes: [("name", "X"), ("key", "1")], children: [.keyframeAnimation(positionX)]))
            }
            if !positionY.isEmpty {
                position.append(NativeFCPXMLNode("param", attributes: [("name", "Y"), ("key", "2")], children: [.keyframeAnimation(positionY)]))
            }
            children.append(position)
        }

        if !scale.isEmpty {
            children.append(NativeFCPXMLNode("param", attributes: [("name", "scale")], children: [.keyframeAnimation(scale)]))
        }

        return NativeFCPXMLNode("adjust-transform", children: children)
    }

    /// The push-in/pan of a living still: a two-keyframe pan on X, a held Y,
    /// and a two-keyframe uniform scale.
    ///
    /// Y is emitted as a single keyframe carrying `curve="linear"` because that
    /// is exactly what Final Cut wrote for an axis that never moves — it did
    /// not omit the axis.
    public static func pushInAndPan(
        startFrame: Int,
        endFrame: Int,
        rate: NativeFCPXMLFrameRate,
        panXFraction: Double,
        panYFraction: Double,
        scaleStart: Double,
        scaleEnd: Double,
        width: Int,
        height: Int
    ) -> NativeFCPXMLTransformChannel {
        let start = NativeFCPXMLStillTiming.keyframeTime(frame: startFrame, rate: rate)
        let end = NativeFCPXMLStillTiming.keyframeTime(frame: endFrame, rate: rate)
        let endX = NativeFCPXMLTransformUnits.position(fromWidthFraction: panXFraction, width: width, height: height)
        let endY = NativeFCPXMLTransformUnits.position(fromWidthFraction: panYFraction, width: width, height: height)

        let positionX = [
            NativeFCPXMLKeyframe(time: start, value: NativeFCPXMLNumber.string(0)),
            NativeFCPXMLKeyframe(time: end, value: NativeFCPXMLNumber.string(endX))
        ]
        let positionY: [NativeFCPXMLKeyframe]
        if endY == 0 {
            positionY = [NativeFCPXMLKeyframe(time: start, value: NativeFCPXMLNumber.string(0), curve: "linear")]
        } else {
            positionY = [
                NativeFCPXMLKeyframe(time: start, value: NativeFCPXMLNumber.string(0)),
                NativeFCPXMLKeyframe(time: end, value: NativeFCPXMLNumber.string(endY))
            ]
        }
        let scale = [
            NativeFCPXMLKeyframe(time: start, value: NativeFCPXMLNumber.pair(scaleStart, scaleStart)),
            NativeFCPXMLKeyframe(time: end, value: NativeFCPXMLNumber.pair(scaleEnd, scaleEnd))
        ]
        return NativeFCPXMLTransformChannel(positionX: positionX, positionY: positionY, scale: scale)
    }
}
