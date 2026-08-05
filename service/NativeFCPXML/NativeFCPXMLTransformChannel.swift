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

    /// Vertical offset, with the axis flip.
    ///
    /// Final Cut's `position` Y is **positive-up**: entering `+200 px` moved the
    /// image up and left black along the bottom of the frame (observed, see
    /// `docs/ROTATION_GROUND_TRUTH.md`). Normalized image coordinates are
    /// positive-down, so a plan that wants the framing to move *down* must emit
    /// a *negative* Y.
    ///
    /// Getting this backwards produces valid FCPXML that pans the wrong way, so
    /// the flip lives here rather than at each call site.
    public static func positionY(fromHeightFraction fraction: Double, height: Int) -> Double {
        -position(fromPixels: fraction * Double(height), frameHeight: height)
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
/// - `rotation` is a single param like `scale`, but with a **scalar** value and
///   **no `key` attribute**, in plain degrees.
/// - `anchor` is not a param at all. When static it is a space-separated pair
///   **attribute on `<adjust-transform>` itself**, in percent of frame height
///   like `position`.
///
/// Four properties, three shapes. There is no rule to infer here, which is the
/// argument for capturing each rather than generalising from the last one.
///
/// ## Static versus animated
///
/// Two independent captures agree:
///
/// > **Static → attribute on the effect element. Animated → `<param>` child.**
///
/// Only the observed halves are representable here. `rotation` is offered
/// animated only, `anchor` static only — those are the forms Final Cut wrote.
/// A static rotation attribute and an animated anchor param are both *likely*
/// to follow the rule, but neither has been seen, and this project does not
/// emit constructions it has not observed.
public struct NativeFCPXMLTransformChannel: Equatable, Sendable {
    public var positionX: [NativeFCPXMLKeyframe]
    public var positionY: [NativeFCPXMLKeyframe]
    public var scale: [NativeFCPXMLKeyframe]
    /// Animated rotation, in degrees. Observed form.
    public var rotation: [NativeFCPXMLKeyframe]
    /// Static anchor as (x, y) in percent of frame height. Observed form.
    public var anchor: (x: Double, y: Double)?
    /// Static position as (x, y) in percent of frame height — the paired
    /// attribute form. Mutually exclusive with `positionX`/`positionY`.
    public var staticPosition: (x: Double, y: Double)?

    public init(
        positionX: [NativeFCPXMLKeyframe] = [],
        positionY: [NativeFCPXMLKeyframe] = [],
        scale: [NativeFCPXMLKeyframe] = [],
        rotation: [NativeFCPXMLKeyframe] = [],
        anchor: (x: Double, y: Double)? = nil,
        staticPosition: (x: Double, y: Double)? = nil
    ) {
        precondition(
            staticPosition == nil || (positionX.isEmpty && positionY.isEmpty),
            "position is either static (attribute) or animated (param), never both"
        )
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotation = rotation
        self.anchor = anchor
        self.staticPosition = staticPosition
    }

    public static func == (lhs: NativeFCPXMLTransformChannel, rhs: NativeFCPXMLTransformChannel) -> Bool {
        lhs.positionX == rhs.positionX
            && lhs.positionY == rhs.positionY
            && lhs.scale == rhs.scale
            && lhs.rotation == rhs.rotation
            && lhs.anchor?.x == rhs.anchor?.x
            && lhs.anchor?.y == rhs.anchor?.y
            && lhs.staticPosition?.x == rhs.staticPosition?.x
            && lhs.staticPosition?.y == rhs.staticPosition?.y
    }

    public var isEmpty: Bool {
        positionX.isEmpty && positionY.isEmpty && scale.isEmpty && rotation.isEmpty
            && anchor == nil && staticPosition == nil
    }

    /// `nil` when nothing is set, so a caller composing channels does not
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

        // No `key` attribute: the capture wrote `<param name="rotation">` bare,
        // unlike position's keyed X/Y sub-params.
        if !rotation.isEmpty {
            children.append(NativeFCPXMLNode("param", attributes: [("name", "rotation")], children: [.keyframeAnimation(rotation)]))
        }

        // Attribute order follows the capture: Final Cut wrote `position`
        // before `anchor` on the one element carrying both concepts.
        var attributes: [(name: String, value: String)] = []
        if let staticPosition {
            attributes.append(("position", NativeFCPXMLNumber.pair(staticPosition.x, staticPosition.y)))
        }
        if let anchor {
            attributes.append(("anchor", NativeFCPXMLNumber.pair(anchor.x, anchor.y)))
        }

        return NativeFCPXMLNode("adjust-transform", attributes: attributes, children: children)
    }

    /// The targeted rotate/zoom channel: an animated rotation and scale with a
    /// position track that keeps the chosen point converging toward centre.
    ///
    /// Targeting is done by **position compensation**, not by moving the
    /// anchor — `SpatialTransformMath.targetedCompensation` already solves for
    /// the translation that places the source point at its desired position
    /// after scale and rotation. That keeps the emitter inside observed
    /// territory: an animated anchor has never been captured, whereas animated
    /// position, scale, and rotation all have.
    ///
    /// `recipe.translation` is a normalized frame offset (x against width, y
    /// against height, positive-down). Both axes convert to percent of frame
    /// height, and Y additionally flips — see `NativeFCPXMLTransformUnits`.
    /// `clipDurationFrames` exists to keep the final keyframe **inside** the
    /// clip.
    ///
    /// A 120-frame clip addresses frames 0…119; a keyframe at 4 s is frame 120,
    /// one past the end. The first rotate/zoom probe emitted exactly that, and
    /// Final Cut accepted it — the document is valid and the animation looks
    /// right, because frame 119 is 99.2% of the way through. But the playhead
    /// cannot park on that keyframe, so the user cannot select or edit it, and
    /// the Inspector shows base values instead of the animated ones there.
    ///
    /// `LivingStillProbeTimeline` avoids this by construction with
    /// `durationFrames - 1`. Clamping here makes the same guarantee for a
    /// recipe whose duration is expressed in seconds.
    public static func targetedRotateZoom(
        recipe: TargetedTransformKeyframeRecipe,
        rate: NativeFCPXMLFrameRate,
        origin: NativeFCPXMLTimingOrigin,
        width: Int,
        height: Int,
        clipDurationFrames: Int? = nil
    ) -> NativeFCPXMLTransformChannel {
        let lastAddressableFrame = clipDurationFrames.map { $0 - 1 }
        func time(_ seconds: Double) -> NativeFCPXMLTime {
            var frame = rate.frames(seconds: seconds)
            if let lastAddressableFrame { frame = min(frame, lastAddressableFrame) }
            return origin.keyframeTime(frame: frame, rate: rate)
        }

        let startTime = time(recipe.start.timeSeconds)
        let endTime = time(recipe.end.timeSeconds)

        let positionX = [
            NativeFCPXMLKeyframe(time: startTime, value: NativeFCPXMLNumber.string(
                NativeFCPXMLTransformUnits.position(fromWidthFraction: recipe.start.translation.x, width: width, height: height))),
            NativeFCPXMLKeyframe(time: endTime, value: NativeFCPXMLNumber.string(
                NativeFCPXMLTransformUnits.position(fromWidthFraction: recipe.end.translation.x, width: width, height: height)))
        ]
        let positionY = [
            NativeFCPXMLKeyframe(time: startTime, value: NativeFCPXMLNumber.string(
                NativeFCPXMLTransformUnits.positionY(fromHeightFraction: recipe.start.translation.y, height: height))),
            NativeFCPXMLKeyframe(time: endTime, value: NativeFCPXMLNumber.string(
                NativeFCPXMLTransformUnits.positionY(fromHeightFraction: recipe.end.translation.y, height: height)))
        ]
        let scale = [
            NativeFCPXMLKeyframe(time: startTime, value: NativeFCPXMLNumber.pair(recipe.start.scale, recipe.start.scale)),
            NativeFCPXMLKeyframe(time: endTime, value: NativeFCPXMLNumber.pair(recipe.end.scale, recipe.end.scale))
        ]
        let rotation = [
            NativeFCPXMLKeyframe(time: startTime, value: NativeFCPXMLNumber.string(recipe.start.rotationDegrees)),
            NativeFCPXMLKeyframe(time: endTime, value: NativeFCPXMLNumber.string(recipe.end.rotationDegrees))
        ]

        return NativeFCPXMLTransformChannel(
            positionX: positionX,
            positionY: positionY,
            scale: scale,
            rotation: rotation
        )
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
