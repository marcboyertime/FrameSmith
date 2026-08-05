import Foundation

/// A clip connected above a spine clip — the construction `look.old_television`
/// needs for its overlays.
///
/// Captured 2026-08-05, `docs/CONNECTED_LAYERS_GROUND_TRUTH.md`:
///
/// ```xml
/// <asset-clip ref="r2" offset="0s" duration="8s" …>
///     <video ref="r3" lane="1" offset="2s" name="living-still"
///            start="10808700/3000s" duration="3s">
///         <adjust-blend amount="0.5" mode="14 (Overlay)"/>
///     </video>
/// </asset-clip>
/// ```
///
/// Three things about that are load-bearing and none were guessable:
///
/// 1. The connected clip is a **child** of the spine clip it attaches to, not a
///    sibling and not a separate spine.
/// 2. `lane="1"` for the first layer above. Lanes below are unobserved.
/// 3. **`offset` is measured from the parent clip's start, not from the
///    timeline origin.** This is the one most likely to ship a silent defect:
///    timeline-relative offsets are valid FCPXML, import without complaint, and
///    misplace every overlay attached to anything but the first clip.
public struct NativeFCPXMLConnectedLayer: Equatable, Sendable {
    /// Resource id of the media this layer shows.
    public let ref: String
    /// 1 for the first layer above the spine. Higher stacks further up.
    public let lane: Int
    /// Offset **from the parent clip's start**, not from the timeline origin.
    public let offsetWithinParent: NativeFCPXMLTime
    public let name: String
    /// Source in-point. For a still this sits on the 3600 s origin; for a movie
    /// it is real source time. See `NativeFCPXMLTimingOrigin`.
    public let start: NativeFCPXMLTime
    public let duration: NativeFCPXMLTime
    public let transform: NativeFCPXMLTransformChannel
    public let blend: NativeFCPXMLOpacityChannel
    /// Additional children (colour filters and the like), appended after the
    /// intrinsic channels in the order Final Cut writes them.
    public let extraChildren: [NativeFCPXMLNode]

    public init(
        ref: String,
        lane: Int = 1,
        offsetWithinParent: NativeFCPXMLTime,
        name: String,
        start: NativeFCPXMLTime,
        duration: NativeFCPXMLTime,
        transform: NativeFCPXMLTransformChannel = NativeFCPXMLTransformChannel(),
        blend: NativeFCPXMLOpacityChannel = NativeFCPXMLOpacityChannel(),
        extraChildren: [NativeFCPXMLNode] = []
    ) {
        precondition(lane >= 1, "connected layers observed only above the spine; lane must be >= 1")
        self.ref = ref
        self.lane = lane
        self.offsetWithinParent = offsetWithinParent
        self.name = name
        self.start = start
        self.duration = duration
        self.transform = transform
        self.blend = blend
        self.extraChildren = extraChildren
    }

    /// Builds the layer from a **timeline** time, converting to the
    /// parent-relative offset Final Cut expects.
    ///
    /// This exists so callers can think in timeline terms — which is how a plan
    /// describes an overlay — without each one re-deriving the subtraction and
    /// risking the sign. `parentStart` is the parent clip's own timeline offset.
    public static func atTimelineTime(
        ref: String,
        lane: Int = 1,
        timelineOffset: NativeFCPXMLTime,
        parentStart: NativeFCPXMLTime,
        name: String,
        start: NativeFCPXMLTime,
        duration: NativeFCPXMLTime,
        transform: NativeFCPXMLTransformChannel = NativeFCPXMLTransformChannel(),
        blend: NativeFCPXMLOpacityChannel = NativeFCPXMLOpacityChannel(),
        extraChildren: [NativeFCPXMLNode] = []
    ) -> NativeFCPXMLConnectedLayer {
        let scale = max(timelineOffset.timescale, parentStart.timescale)
        let within = NativeFCPXMLTime(
            numerator: timelineOffset.converted(toTimescale: scale).numerator
                - parentStart.converted(toTimescale: scale).numerator,
            timescale: scale
        )
        precondition(within.numerator >= 0, "a connected layer cannot start before its parent clip")
        return NativeFCPXMLConnectedLayer(
            ref: ref,
            lane: lane,
            offsetWithinParent: within,
            name: name,
            start: start,
            duration: duration,
            transform: transform,
            blend: blend,
            extraChildren: extraChildren
        )
    }

    /// Attribute order follows the capture exactly:
    /// `ref, lane, offset, name, start, duration`.
    public var node: NativeFCPXMLNode {
        var children: [NativeFCPXMLNode] = []
        if let transformNode = transform.node { children.append(transformNode) }
        if let blendNode = blend.node { children.append(blendNode) }
        children.append(contentsOf: extraChildren)

        return NativeFCPXMLNode(
            "video",
            attributes: [
                ("ref", ref),
                ("lane", String(lane)),
                ("offset", offsetWithinParent.attributeValue),
                ("name", name),
                ("start", start.attributeValue),
                ("duration", duration.attributeValue)
            ],
            children: children
        )
    }
}
