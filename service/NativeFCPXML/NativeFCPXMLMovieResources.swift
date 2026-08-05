import Foundation

/// Resources and spine construction for a **movie** clip.
///
/// This deliberately reproduces the construction the dissolve probes already
/// got admitted (`docs/ROUNDTRIP_MANUAL_PASS.md`), attribute for attribute:
///
/// ```xml
/// <format id="r1" name="FFVideoFormat1080p30"/>
/// <asset id="r2" name="clip-a.mov" start="0s" duration="8s" hasVideo="1" hasAudio="1"
///        format="r1" audioSources="1" audioChannels="2" audioRate="48000">
///     <media-rep kind="original-media" src="file://…"/>
/// </asset>
/// …
/// <asset-clip name="clip-a.mov" ref="r2" format="r1" offset="0s" start="0s" duration="8s" audioRole="dialogue"/>
/// ```
///
/// Two things are inherited rather than re-decided, because they are the parts
/// that already survived an import:
///
/// - The `<format>` is **name-only**. The still path writes width/height/colorSpace;
///   the admitted movie path does not, and this reproduces the admitted one.
/// - No `uid` on the asset and no `sig` on the `media-rep`. Final Cut assigns
///   both on ingest, and inventing them would assert an identity we were never
///   given.
///
/// Movie keyframe times use `NativeFCPXMLTimingOrigin.movie`, not the stills'
/// one-hour origin — see `docs/ROTATION_GROUND_TRUTH.md`.
public struct NativeFCPXMLMovieResources: Equatable, Sendable {
    public let formatID: String
    public let assetID: String
    public let name: String
    public let mediaURL: URL
    public let formatName: String
    public let sourceDuration: NativeFCPXMLTime
    public let hasAudio: Bool

    public init(
        formatID: String,
        assetID: String,
        name: String,
        mediaURL: URL,
        formatName: String = "FFVideoFormat1080p30",
        sourceDuration: NativeFCPXMLTime,
        hasAudio: Bool = true
    ) {
        self.formatID = formatID
        self.assetID = assetID
        self.name = name
        self.mediaURL = mediaURL
        self.formatName = formatName
        self.sourceDuration = sourceDuration
        self.hasAudio = hasAudio
    }

    public var formatNode: NativeFCPXMLNode {
        NativeFCPXMLNode("format", attributes: [("id", formatID), ("name", formatName)])
    }

    public var assetNode: NativeFCPXMLNode {
        var attributes: [(name: String, value: String)] = [
            ("id", assetID),
            ("name", name),
            ("start", NativeFCPXMLTime.zero.attributeValue),
            ("duration", sourceDuration.attributeValue),
            ("hasVideo", "1")
        ]
        if hasAudio { attributes.append(("hasAudio", "1")) }
        attributes.append(("format", formatID))
        if hasAudio {
            let audioAttributes: [(name: String, value: String)] = [
                ("audioSources", "1"),
                ("audioChannels", "2"),
                ("audioRate", "48000")
            ]
            attributes.append(contentsOf: audioAttributes)
        }
        return NativeFCPXMLNode(
            "asset",
            attributes: attributes,
            children: [
                NativeFCPXMLNode("media-rep", attributes: [
                    ("kind", "original-media"),
                    ("src", mediaURL.absoluteString)
                ])
            ]
        )
    }

    /// A spine `asset-clip`.
    ///
    /// The three child groups are separate parameters rather than one array
    /// because the DTD fixes their order and getting it wrong is a hard
    /// validation failure, not a silent one:
    ///
    /// ```
    /// (note?, (conform-rate?, timeMap?),
    ///  ((object-tracker?, adjust-crop?, …, adjust-transform?, adjust-blend?, …), …),
    ///  (audio | video | clip | title | …)*,      ← connected clips
    ///  (marker | …)*, audio-channel-source*,
    ///  (filter-video | filter-video-mask)*,      ← filters, after connected clips
    ///  filter-audio*, metadata?)
    /// ```
    ///
    /// The first old television probe emitted `adjust-blend, filter-video,
    /// video` and `xmllint` rejected it. Making the order a property of the API
    /// means no caller has to remember it. (This is one of the few things the
    /// DTD genuinely does catch — it constrains order, never semantics.)
    public func assetClipNode(
        offset: NativeFCPXMLTime,
        start: NativeFCPXMLTime = .zero,
        duration: NativeFCPXMLTime,
        intrinsics: [NativeFCPXMLNode] = [],
        connectedLayers: [NativeFCPXMLConnectedLayer] = [],
        filters: [NativeFCPXMLNode] = []
    ) -> NativeFCPXMLNode {
        NativeFCPXMLNode(
            "asset-clip",
            attributes: [
                ("name", name),
                ("ref", assetID),
                ("format", formatID),
                ("offset", offset.attributeValue),
                ("start", start.attributeValue),
                ("duration", duration.attributeValue),
                ("audioRole", "dialogue")
            ],
            children: intrinsics + connectedLayers.map(\.node) + filters
        )
    }
}
