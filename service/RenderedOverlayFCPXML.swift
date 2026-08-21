import Foundation

/// Writes the shared rendered-treatment construction:
///
/// - the admitted original remains the spine clip and keeps its audio;
/// - one video-only, opaque treatment movie is connected above it for the
///   exact same duration;
/// - no opacity dip, color approximation, or second render is introduced.
///
/// Living Still v2 and Old Television deliberately share this boundary. Their
/// pixels differ; their editorial-preservation and FCPXML semantics do not.
public enum RenderedOverlayFCPXML {
    public static func document(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        preparedAsset: RenderedEffectAsset,
        publishedPreparedURL: URL,
        durationFrames: Int,
        version: String
    ) throws -> String {
        guard let base = media[.primary], let baseURL = publishedMediaURLs[.primary] else {
            throw StandaloneExportError.missingMedia(.primary)
        }
        guard durationFrames > 0 else {
            throw StandaloneExportError.invalidRecipe("rendered treatment duration must contain at least one frame")
        }
        try preparedAsset.validate(plan: plan, media: media)
        guard preparedAsset.fps == NativeFCPXMLFrameRate.thirty.framesPerSecond,
              preparedAsset.frameCount == durationFrames else {
            throw StandaloneExportError.admittedArtifactMismatch("rendered treatment timing does not match the 30 fps project")
        }

        let rate = NativeFCPXMLFrameRate.thirty
        let duration = rate.time(frames: durationFrames)
        let renderedResources = NativeFCPXMLMovieResources(
            formatID: "r1",
            assetID: "r3",
            name: preparedAsset.url.lastPathComponent,
            mediaURL: publishedPreparedURL,
            sourceDuration: duration,
            hasAudio: false
        )
        let renderedLayer = NativeFCPXMLConnectedLayer(
            ref: "r3",
            lane: 1,
            offsetWithinParent: .zero,
            name: preparedAsset.url.lastPathComponent,
            start: .zero,
            duration: duration
        )

        let spineChild: NativeFCPXMLNode
        var resources: [NativeFCPXMLNode]
        switch base.kind {
        case .still:
            let original = NativeFCPXMLStillResources(
                sequenceFormatID: "r1",
                assetID: "r2",
                stillFormatID: "r6",
                name: base.itemID,
                mediaURL: baseURL,
                width: base.dimensions.width,
                height: base.dimensions.height,
                frameRate: rate
            )
            spineChild = original.videoNode(
                offset: .zero,
                duration: duration,
                children: [renderedLayer.node]
            )
            resources = original.resourceNodes
        case .movie:
            if let sourceSeconds = base.durationSeconds,
               rate.frames(seconds: sourceSeconds) < durationFrames {
                throw StandaloneExportError.sourceDurationExceeded
            }
            let sourceFrames = base.durationSeconds.map { rate.frames(seconds: $0) } ?? durationFrames
            let original = NativeFCPXMLMovieResources(
                formatID: "r1",
                assetID: "r2",
                name: base.itemID,
                mediaURL: baseURL,
                sourceDuration: rate.time(frames: sourceFrames),
                hasAudio: base.hasAudio
            )
            spineChild = original.assetClipNode(
                offset: .zero,
                start: .zero,
                duration: duration,
                connectedLayers: [renderedLayer]
            )
            resources = [original.formatNode, original.assetNode]
        }
        resources.append(renderedResources.assetNode)

        let name = StandaloneFCPXMLExportBuilder.projectName(for: plan)
        return NativeFCPXMLDocument(
            version: version,
            resources: resources,
            eventName: name,
            projectName: name,
            sequenceFormatID: "r1",
            sequenceDuration: duration,
            spineChildren: [spineChild]
        ).xmlString
    }
}
