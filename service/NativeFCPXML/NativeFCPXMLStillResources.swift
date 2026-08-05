import Foundation

/// Resource and timeline construction for a still image.
///
/// A still is not an `asset-clip`. Revision 1 of the dissolve probe crashed
/// Final Cut inside `addAssetClip:`, and a still takes a different path
/// entirely: `<video>`, referencing an asset that carries `duration="0s"` and
/// its own rate-undefined format. All of it observed, see
/// `docs/LIVING_STILL_GROUND_TRUTH.md`.
public struct NativeFCPXMLStillResources: Equatable, Sendable {
    public let sequenceFormatID: String
    public let assetID: String
    public let stillFormatID: String
    public let name: String
    public let mediaURL: URL
    public let width: Int
    public let height: Int
    public let frameRate: NativeFCPXMLFrameRate

    public init(
        sequenceFormatID: String,
        assetID: String,
        stillFormatID: String,
        name: String,
        mediaURL: URL,
        width: Int,
        height: Int,
        frameRate: NativeFCPXMLFrameRate
    ) {
        self.sequenceFormatID = sequenceFormatID
        self.assetID = assetID
        self.stillFormatID = stillFormatID
        self.name = name
        self.mediaURL = mediaURL
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }

    /// `FFVideoFormat1080p30` with an explicit `frameDuration`, as captured.
    public var sequenceFormatNode: NativeFCPXMLNode {
        NativeFCPXMLNode("format", attributes: [
            ("id", sequenceFormatID),
            ("name", "FFVideoFormat1080p30"),
            ("frameDuration", frameRate.frameDuration().attributeValue),
            ("width", String(width)),
            ("height", String(height)),
            ("colorSpace", "1-1-1 (Rec. 709)")
        ])
    }

    /// A still gets a *second* format with no `frameDuration` at all. Reusing
    /// the sequence format here would be a different construction from the one
    /// Final Cut wrote.
    public var stillFormatNode: NativeFCPXMLNode {
        NativeFCPXMLNode("format", attributes: [
            ("id", stillFormatID),
            ("name", "FFVideoFormatRateUndefined"),
            ("width", String(width)),
            ("height", String(height)),
            ("colorSpace", "1-13-1")
        ])
    }

    /// `duration="0s"` is not a mistake: Final Cut treats a still as having no
    /// intrinsic duration and takes the length from the `<video>` element.
    ///
    /// The capture also carried `uid` and a `media-rep sig`. Both are library
    /// identifiers Final Cut assigns on ingest, so neither is emitted here —
    /// inventing them would assert an identity we have not been given.
    public var assetNode: NativeFCPXMLNode {
        NativeFCPXMLNode("asset", attributes: [
            ("id", assetID),
            ("name", name),
            ("start", NativeFCPXMLTime.zero.attributeValue),
            ("duration", NativeFCPXMLTime.zero.attributeValue),
            ("hasVideo", "1"),
            ("format", stillFormatID),
            ("videoSources", "1")
        ], children: [
            NativeFCPXMLNode("media-rep", attributes: [
                ("kind", "original-media"),
                ("src", NativeFCPXMLNode.fileURLString(mediaURL))
            ])
        ])
    }

    public var resourceNodes: [NativeFCPXMLNode] {
        [sequenceFormatNode, assetNode, stillFormatNode]
    }

    /// The spine element. `start` is the one-hour source origin; `<video>`
    /// takes no `format` attribute, which the DTD confirms.
    ///
    /// Children are appended by the caller in `%intrinsic-params-video;` order
    /// followed by `%video_filter_item;` — transform, then blend, then filters.
    public func videoNode(offset: NativeFCPXMLTime, duration: NativeFCPXMLTime, children: [NativeFCPXMLNode]) -> NativeFCPXMLNode {
        NativeFCPXMLNode("video", attributes: [
            ("ref", assetID),
            ("offset", offset.attributeValue),
            ("name", name),
            ("start", NativeFCPXMLStillTiming.sourceStart.attributeValue),
            ("duration", duration.attributeValue)
        ], children: children)
    }
}
