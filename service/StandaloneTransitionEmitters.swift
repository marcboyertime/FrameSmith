import Foundation

/// Reasons a transition or overlay cannot be built from a given plan.
///
/// These are refusals, not fallbacks. The director-control contract forbids
/// moving an edit point or trimming a clip to make an effect fit, so a
/// transition with insufficient handle has to fail loudly rather than quietly
/// shorten itself into something the user did not ask for.
public enum StandaloneCompositionError: Error, LocalizedError, Equatable, Sendable {
    case insufficientHandle(side: String, availableFrames: Int, requiredFrames: Int)
    case transitionLongerThanClip(durationFrames: Int, clipFrames: Int)
    case missingSecondClip
    case overlayOutlivesParent(overlayEndFrame: Int, parentFrames: Int)

    public var errorDescription: String? {
        switch self {
        case .insufficientHandle(let side, let available, let required):
            return "The \(side) clip has \(available) frames of unused source but this transition needs \(required). Your edit point will not move — shorten the transition or use a clip with more handle."
        case .transitionLongerThanClip(let duration, let clip):
            return "A \(duration)-frame transition does not fit a \(clip)-frame clip."
        case .missingSecondClip:
            return "A dissolve needs two clips. Add an incoming clip."
        case .overlayOutlivesParent(let end, let parent):
            return "The overlay would end at frame \(end) but its clip is \(parent) frames long."
        }
    }
}

// MARK: - Natural dissolve

/// Generalizes the admitted cross-dissolve construction from validated registry values.
///
/// Until now this construction existed only inside `FCPXMLRoundTripSpikeBuilder`,
/// which builds one fixed probe timeline to ask a question. That is why the
/// technique card read `unsupported` despite the contract being admitted — the
/// semantics were proven but nothing could emit the registry's canonical plan.
///
/// All four admitted construction rules are reproduced exactly:
///
/// 1. a real `<effect>` resource carrying the Cross Dissolve UID;
/// 2. a `<filter-video>` on the transition referencing it;
/// 3. the transition offset at `cut − duration/2`;
/// 4. adjacent clips **butt-joined** at the cut, with unused source beyond it.
///
/// Rule 4 is the one that bites: overlapping the clips is also DTD-valid and is
/// silently re-flowed by Final Cut, which is how revision 3 failed.
public struct NaturalDissolveStandaloneEmitter: StandaloneEffectEmitter {
    public let effectID: EffectID = .naturalDissolve
    public init() {}

    /// Frame-quantized geometry for one dissolve, or a refusal.
    public struct Geometry: Equatable, Sendable {
        public let rate: NativeFCPXMLFrameRate
        public let outgoingFrames: Int
        public let incomingFrames: Int
        public let transitionFrames: Int
        /// Timeline frame of the user's edit point. Never moved.
        public var cutFrame: Int { outgoingFrames }
        public var totalFrames: Int { outgoingFrames + incomingFrames }
        /// `cut − duration/2`, the admitted centred offset.
        public var transitionOffsetFrames: Int { cutFrame - transitionFrames / 2 }
        public var handleFrames: Int { transitionFrames / 2 }
    }

    /// Builds geometry and refuses anything that would require moving the cut.
    ///
    /// `outgoingSourceFrames` / `incomingSourceFrames` are the **full** source
    /// durations; the difference between those and the used portion is the
    /// handle available to the transition.
    public static func geometry(
        rate: NativeFCPXMLFrameRate,
        outgoingFrames: Int,
        incomingFrames: Int,
        transitionFrames requested: Int,
        outgoingSourceFrames: Int,
        incomingSourceStartFrame: Int
    ) throws -> Geometry {
        // Even durations keep the half-duration on a whole frame, so the
        // centred offset stays frame-aligned rather than ambiguous.
        let transitionFrames = max(2, requested - (requested % 2))
        guard transitionFrames <= outgoingFrames, transitionFrames <= incomingFrames else {
            throw StandaloneCompositionError.transitionLongerThanClip(
                durationFrames: transitionFrames,
                clipFrames: min(outgoingFrames, incomingFrames)
            )
        }
        let handle = transitionFrames / 2

        let outgoingHandle = outgoingSourceFrames - outgoingFrames
        guard outgoingHandle >= handle else {
            throw StandaloneCompositionError.insufficientHandle(
                side: "outgoing", availableFrames: max(0, outgoingHandle), requiredFrames: handle
            )
        }
        guard incomingSourceStartFrame >= handle else {
            throw StandaloneCompositionError.insufficientHandle(
                side: "incoming", availableFrames: max(0, incomingSourceStartFrame), requiredFrames: handle
            )
        }
        return Geometry(
            rate: rate,
            outgoingFrames: outgoingFrames,
            incomingFrames: incomingFrames,
            transitionFrames: transitionFrames
        )
    }

    public func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels {
        guard let outgoing = media[.outgoing] ?? media[.primary] else {
            throw StandaloneExportError.missingMedia(.outgoing)
        }
        guard media[.incoming] != nil else { throw StandaloneCompositionError.missingSecondClip }
        let geometry = try planGeometry(plan: plan, media: media)

        return NativeFCPXMLEffectChannels(
            transform: NativeFCPXMLTransformChannel(),
            opacity: NativeFCPXMLOpacityChannel(),
            saturation: nil,
            durationSeconds: Double(geometry.totalFrames) / Double(geometry.rate.framesPerSecond),
            origin: outgoing.kind == .still ? .still : .movieFromZero,
            frameWidth: outgoing.dimensions.width,
            frameHeight: outgoing.dimensions.height,
            transition: NativeFCPXMLTransitionDescriptor(
                cutFrame: geometry.cutFrame,
                durationFrames: geometry.transitionFrames,
                outgoingDurationFrames: geometry.outgoingFrames,
                incomingDurationFrames: geometry.incomingFrames
            )
        )
    }

    private func planGeometry(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> Geometry {
        let rate = NativeFCPXMLFrameRate.thirty
        guard let outgoing = media[.outgoing] ?? media[.primary],
              let incoming = media[.incoming] else {
            throw StandaloneCompositionError.missingSecondClip
        }

        let outgoingSourceFrames = outgoing.durationSeconds.map { rate.frames(seconds: $0) } ?? 240
        let incomingSourceFrames = incoming.durationSeconds.map { rate.frames(seconds: $0) } ?? 240

        // The plan may only supply the registry's frame-count parameter. There
        // is deliberately no duration-seconds compatibility path or fallback:
        // an incomplete or forged plan must not silently become a one-second
        // dissolve.
        guard let requestedValue = plan.parameters["durationFrames"]?.numberValue,
              requestedValue.isFinite,
              requestedValue.rounded() == requestedValue,
              (1...120).contains(requestedValue) else {
            throw StandaloneExportError.invalidRecipe(
                "Natural Dissolve requires a finite integral durationFrames value in 1...120"
            )
        }
        let requestedFrames = Int(requestedValue)

        // Reserve half the transition as handle on each side, so the visible
        // clip lengths shrink rather than the cut moving. `geometry` owns the
        // admitted even-frame quantization, so reserve against that same result.
        let quantizedFrames = max(2, requestedFrames - (requestedFrames % 2))
        let handle = quantizedFrames / 2
        let outgoingVisible = max(1, outgoingSourceFrames - handle)
        let incomingVisible = max(1, incomingSourceFrames - handle)

        return try Self.geometry(
            rate: rate,
            outgoingFrames: outgoingVisible,
            incomingFrames: incomingVisible,
            transitionFrames: requestedFrames,
            outgoingSourceFrames: outgoingSourceFrames,
            incomingSourceStartFrame: handle
        )
    }

    public func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String {
        guard let outgoing = media[.outgoing] ?? media[.primary],
              let outgoingURL = publishedMediaURLs[.outgoing] ?? publishedMediaURLs[.primary] else {
            throw StandaloneExportError.missingMedia(.outgoing)
        }
        guard let incoming = media[.incoming], let incomingURL = publishedMediaURLs[.incoming] else {
            throw StandaloneCompositionError.missingSecondClip
        }
        let geometry = try planGeometry(plan: plan, media: media)
        let rate = geometry.rate

        let outgoingResources = NativeFCPXMLMovieResources(
            formatID: "r1", assetID: "r2", name: outgoing.itemID, mediaURL: outgoingURL,
            sourceDuration: rate.time(frames: outgoing.durationSeconds.map { rate.frames(seconds: $0) } ?? 240),
            hasAudio: outgoing.hasAudio
        )
        let incomingResources = NativeFCPXMLMovieResources(
            formatID: "r1", assetID: "r3", name: incoming.itemID, mediaURL: incomingURL,
            sourceDuration: rate.time(frames: incoming.durationSeconds.map { rate.frames(seconds: $0) } ?? 240),
            hasAudio: incoming.hasAudio
        )

        // Rule 4: butt-joined at the cut. The incoming clip starts in its source
        // at `handle` so the transition has material to work with on that side.
        let outgoingClip = outgoingResources.assetClipNode(
            offset: .zero,
            start: .zero,
            duration: rate.time(frames: geometry.outgoingFrames)
        )
        let incomingClip = incomingResources.assetClipNode(
            offset: rate.time(frames: geometry.cutFrame),
            start: rate.time(frames: geometry.handleFrames),
            duration: rate.time(frames: geometry.incomingFrames)
        )

        // Rules 1–3: a real effect resource, a filter-video referencing it, and
        // the centred offset.
        let transition = NativeFCPXMLNode(
            "transition",
            attributes: [
                ("name", RoundTripSpikeCrossDissolve.name),
                ("offset", rate.time(frames: geometry.transitionOffsetFrames).attributeValue),
                ("duration", rate.time(frames: geometry.transitionFrames).attributeValue)
            ],
            children: [
                NativeFCPXMLNode(
                    "filter-video",
                    attributes: [("ref", "r4"), ("name", RoundTripSpikeCrossDissolve.name)],
                    children: [
                        NativeFCPXMLNode("param", attributes: [("name", "Look"), ("key", "1"), ("value", "11 (Video)")]),
                        NativeFCPXMLNode("param", attributes: [("name", "Amount"), ("key", "2"), ("value", "50")]),
                        NativeFCPXMLNode("param", attributes: [("name", "Ease"), ("key", "50"), ("value", "2 (In & Out)")]),
                        NativeFCPXMLNode("param", attributes: [("name", "Ease Amount"), ("key", "51"), ("value", "0")])
                    ]
                )
            ]
        )

        let effect = NativeFCPXMLNode("effect", attributes: [
            ("id", "r4"), ("name", RoundTripSpikeCrossDissolve.name), ("uid", RoundTripSpikeCrossDissolve.uid)
        ])
        let name = StandaloneFCPXMLExportBuilder.projectName(for: plan)
        return NativeFCPXMLDocument(
            version: version,
            resources: [outgoingResources.formatNode, outgoingResources.assetNode, incomingResources.assetNode, effect],
            eventName: name,
            projectName: name,
            sequenceFormatID: "r1",
            sequenceDuration: rate.time(frames: geometry.totalFrames),
            spineChildren: [outgoingClip, transition, incomingClip]
        ).xmlString
    }
}

// MARK: - Old television

/// Produces one professional CRT movie and seals that exact movie to preview
/// and export. The admitted source stays untouched underneath it, including
/// its original audio; the generated layer is opaque and video-only.
public struct OldTelevisionStandaloneEmitter: StandaloneRenderedEffectEmitter {
    public let effectID: EffectID = .oldTelevision
    public init() {}

    private struct Settings {
        let rate = NativeFCPXMLFrameRate.thirty
        let durationFrames: Int
        let profile: OldTelevisionProfile
        let intensity: Double
        let scanlineStrength: Double
        let noiseStrength: Double
        let syncInstability: Double
        let chromaSeparation: Double
        let bloomStrength: Double
        let vignetteStrength: Double
        let ghostingStrength: Double
        let flickerStrength: Double
        let seed: Int
        let outputLongEdge: Int
    }

    private func settings(plan: EffectPlan) throws -> Settings {
        let requiredKeys: Set<String> = [
            "durationSeconds", "profile", "intensity", "scanlineStrength",
            "noiseStrength", "syncInstability", "chromaSeparation",
            "bloomStrength", "vignetteStrength", "ghostingStrength",
            "flickerStrength", "seed", "outputLongEdge", "fps",
            "renderMethod", "preserveOriginal"
        ]
        guard Set(plan.parameters.keys) == requiredKeys else {
            throw StandaloneExportError.invalidRecipe("Old Television parameters must exactly match the production registry")
        }
        func number(_ key: String, minimum: Double, maximum: Double) throws -> Double {
            guard let value = plan.parameters[key]?.numberValue,
                  value.isFinite,
                  (minimum...maximum).contains(value) else {
                throw StandaloneExportError.invalidRecipe("Old Television \(key) must be a finite number in \(minimum)...\(maximum)")
            }
            return value
        }
        func integer(_ key: String, minimum: Int, maximum: Int) throws -> Int {
            guard let raw = plan.parameters[key]?.numberValue,
                  raw.isFinite, raw.rounded() == raw,
                  raw >= Double(minimum), raw <= Double(maximum) else {
                throw StandaloneExportError.invalidRecipe("Old Television \(key) must be an integer in \(minimum)...\(maximum)")
            }
            return Int(raw)
        }
        let rate = NativeFCPXMLFrameRate.thirty
        let duration = rate.frames(seconds: try number("durationSeconds", minimum: 0.1, maximum: 30))
        guard duration > 0 else {
            throw StandaloneExportError.invalidRecipe("Old Television duration contains no frames")
        }
        let profile: OldTelevisionProfile
        switch plan.parameters["profile"]?.stringValue {
        case "broadcast-mono": profile = .broadcastMono
        case "color-crt": profile = .colorCRT
        default: throw StandaloneExportError.invalidRecipe("Old Television profile is unsupported")
        }
        guard plan.parameters["fps"] == .integer(30),
              plan.parameters["renderMethod"] == .string("ffmpeg-crt-v2"),
              plan.parameters["preserveOriginal"] == .boolean(true) else {
            throw StandaloneExportError.invalidRecipe("Old Television renderer invariants drifted")
        }
        return Settings(
            durationFrames: duration,
            profile: profile,
            intensity: try number("intensity", minimum: 0, maximum: 1),
            scanlineStrength: try number("scanlineStrength", minimum: 0, maximum: 1),
            noiseStrength: try number("noiseStrength", minimum: 0, maximum: 1),
            syncInstability: try number("syncInstability", minimum: 0, maximum: 1),
            chromaSeparation: try number("chromaSeparation", minimum: 0, maximum: 1),
            bloomStrength: try number("bloomStrength", minimum: 0, maximum: 1),
            vignetteStrength: try number("vignetteStrength", minimum: 0, maximum: 1),
            ghostingStrength: try number("ghostingStrength", minimum: 0, maximum: 1),
            flickerStrength: try number("flickerStrength", minimum: 0, maximum: 1),
            seed: try integer("seed", minimum: 0, maximum: Int(Int32.max)),
            outputLongEdge: try integer("outputLongEdge", minimum: 640, maximum: 3840)
        )
    }

    public func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels {
        guard let base = media[.primary] else { throw StandaloneExportError.missingMedia(.primary) }
        let settings = try settings(plan: plan)
        let origin: NativeFCPXMLTimingOrigin = base.kind == .still ? .still : .movieFromZero

        return NativeFCPXMLEffectChannels(
            transform: NativeFCPXMLTransformChannel(),
            opacity: NativeFCPXMLOpacityChannel(),
            saturation: nil,
            durationSeconds: Double(settings.durationFrames) / Double(settings.rate.framesPerSecond),
            origin: origin,
            frameWidth: base.dimensions.width,
            frameHeight: base.dimensions.height
        )
    }

    public func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String {
        throw StandaloneExportError.invalidRecipe("Old Television requires its checksum-bound prepared render")
    }

    public func prepareRenderedAsset(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        outputRoot: URL
    ) throws -> RenderedEffectAsset {
        guard let base = media[.primary] else { throw StandaloneExportError.missingMedia(.primary) }
        let settings = try settings(plan: plan)
        if base.kind == .movie, let sourceSeconds = base.durationSeconds,
           settings.rate.frames(seconds: sourceSeconds) < settings.durationFrames {
            throw StandaloneExportError.sourceDurationExceeded
        }
        let geometry = try RenderedOutputGeometry(
            source: base.dimensions,
            maximumLongEdge: settings.outputLongEdge
        )
        let request = OldTelevisionRenderRequest(
            sourceURL: URL(fileURLWithPath: base.canonicalPath),
            sourceSHA256: base.sha256,
            sourceKind: base.kind == .still ? .still : .movie,
            targetWidth: geometry.width,
            targetHeight: geometry.height,
            duration: OldTelevisionRational(Int64(settings.durationFrames), Int64(settings.rate.framesPerSecond)),
            frameRate: OldTelevisionRational(Int64(settings.rate.framesPerSecond)),
            profile: settings.profile,
            intensity: settings.intensity,
            scanlines: settings.scanlineStrength,
            noise: settings.noiseStrength,
            syncInstability: settings.syncInstability,
            chromaticSeparation: settings.chromaSeparation,
            bloom: settings.bloomStrength,
            vignette: settings.vignetteStrength,
            ghosting: settings.ghostingStrength,
            flicker: settings.flickerStrength,
            seed: settings.seed
        )
        let artifact: OldTelevisionRenderArtifact
        do {
            artifact = try OldTelevisionRenderAdapter().render(request, in: outputRoot)
        } catch {
            throw StandaloneExportError.invalidRecipe(error.localizedDescription)
        }
        return RenderedEffectAsset(
            url: artifact.url,
            sha256: artifact.sha256,
            constructionDigest: try RenderedConstructionIdentity.digest(plan: plan, media: media),
            rendererRecipeDigest: artifact.recipeDigest,
            sourceSHA256: base.sha256,
            width: artifact.width,
            height: artifact.height,
            fps: Int(artifact.frameRate.doubleValue.rounded()),
            frameCount: artifact.frameCount,
            durationSeconds: artifact.duration.doubleValue,
            codec: artifact.codec,
            pixelFormat: artifact.pixelFormat,
            videoOnly: artifact.videoOnly,
            provenance: [
                "renderer": OldTelevisionRenderAdapter.rendererVersion,
                "codecProfile": artifact.codecProfile,
                "profile": settings.profile.rawValue,
                "renderMethod": "ffmpeg-crt-v2"
            ]
        )
    }

    public func emitPreparedDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        preparedAsset: RenderedEffectAsset,
        publishedPreparedURL: URL,
        version: String
    ) throws -> String {
        let settings = try settings(plan: plan)
        return try RenderedOverlayFCPXML.document(
            plan: plan,
            media: media,
            publishedMediaURLs: publishedMediaURLs,
            preparedAsset: preparedAsset,
            publishedPreparedURL: publishedPreparedURL,
            durationFrames: settings.durationFrames,
            version: version
        )
    }
}
