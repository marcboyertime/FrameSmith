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

/// Generalizes the admitted cross-dissolve construction to arbitrary plan values.
///
/// Until now this construction existed only inside `FCPXMLRoundTripSpikeBuilder`,
/// which builds one fixed probe timeline to ask a question. That is why the
/// technique card read `unsupported` despite the contract being admitted and
/// duration-editable — the semantics were proven but nothing could emit them
/// from a user's numbers.
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

        // Requested transition duration, in frames, from the plan.
        let requestedSeconds: Double
        if case .number(let value)? = plan.parameters["durationSeconds"] { requestedSeconds = value } else { requestedSeconds = 1.0 }
        let requestedFrames = max(2, rate.frames(seconds: requestedSeconds))

        // Reserve half the transition as handle on each side, so the visible
        // clip lengths shrink rather than the cut moving.
        let handle = requestedFrames / 2
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

/// Generalizes the admitted connected-overlay construction to plan values.
///
/// The base clip carries an animated opacity flicker and a Color Adjustments
/// filter; a connected `<video>` hangs above it in a blend mode. Every piece is
/// a construction Final Cut has already returned intact.
///
/// The overlay's `offset` is **parent-relative**, which is the finding most
/// likely to ship a silent defect: a timeline-relative offset is valid FCPXML
/// that imports without complaint and misplaces every overlay attached to
/// anything but the first clip.
public struct OldTelevisionStandaloneEmitter: StandaloneEffectEmitter {
    public let effectID: EffectID = .oldTelevision
    public init() {}

    private struct Settings {
        let rate = NativeFCPXMLFrameRate.thirty
        let durationFrames: Int
        let flickerFloor: Double
        let overlayOpacity: Double
        let overlayStartFrame: Int
        let overlayDurationFrames: Int
        let saturation: Double
    }

    private func settings(plan: EffectPlan) -> Settings {
        func number(_ key: String, _ fallback: Double) -> Double {
            if case .number(let value)? = plan.parameters[key] { return value }
            return fallback
        }
        let rate = NativeFCPXMLFrameRate.thirty
        let duration = max(2, rate.frames(seconds: number("durationSeconds", 4)))
        let overlayStart = min(max(0, rate.frames(seconds: number("overlayStartSeconds", 1))), duration - 1)
        let overlayDuration = min(max(1, rate.frames(seconds: number("overlayDurationSeconds", 2))), duration - overlayStart)
        return Settings(
            durationFrames: duration,
            flickerFloor: min(max(number("flickerFloor", 0.82), 0), 1),
            overlayOpacity: min(max(number("overlayOpacity", 0.5), 0), 1),
            overlayStartFrame: overlayStart,
            overlayDurationFrames: overlayDuration,
            saturation: number("saturation", NativeEffectProbeTimeline.saturation)
        )
    }

    public func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels {
        guard let base = media[.primary] else { throw StandaloneExportError.missingMedia(.primary) }
        let settings = settings(plan: plan)
        let origin: NativeFCPXMLTimingOrigin = base.kind == .still ? .still : .movieFromZero

        guard settings.overlayStartFrame + settings.overlayDurationFrames <= settings.durationFrames else {
            throw StandaloneCompositionError.overlayOutlivesParent(
                overlayEndFrame: settings.overlayStartFrame + settings.overlayDurationFrames,
                parentFrames: settings.durationFrames
            )
        }

        return NativeFCPXMLEffectChannels(
            transform: NativeFCPXMLTransformChannel(),
            opacity: flicker(settings: settings, origin: origin),
            saturation: settings.saturation,
            durationSeconds: Double(settings.durationFrames) / Double(settings.rate.framesPerSecond),
            origin: origin,
            frameWidth: base.dimensions.width,
            frameHeight: base.dimensions.height,
            overlay: media[.incoming] == nil ? nil : NativeFCPXMLOverlayDescriptor(
                startFrameWithinParent: settings.overlayStartFrame,
                durationFrames: settings.overlayDurationFrames,
                opacity: settings.overlayOpacity,
                blendMode: .overlay
            )
        )
    }

    /// Three keyframes: full, dip, full. The animated param form, which is what
    /// Final Cut writes for a value that moves.
    private func flicker(settings: Settings, origin: NativeFCPXMLTimingOrigin) -> NativeFCPXMLOpacityChannel {
        let rate = settings.rate
        let mid = max(1, settings.durationFrames / 8)
        return NativeFCPXMLOpacityChannel(amount: [
            NativeFCPXMLKeyframe(time: origin.keyframeTime(frame: 0, rate: rate), value: NativeFCPXMLNumber.string(1)),
            NativeFCPXMLKeyframe(time: origin.keyframeTime(frame: mid, rate: rate), value: NativeFCPXMLNumber.string(settings.flickerFloor)),
            NativeFCPXMLKeyframe(time: origin.keyframeTime(frame: mid * 2, rate: rate), value: NativeFCPXMLNumber.string(1))
        ])
    }

    public func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String {
        guard let base = media[.primary], let baseURL = publishedMediaURLs[.primary] else {
            throw StandaloneExportError.missingMedia(.primary)
        }
        let settings = settings(plan: plan)
        let built = try channels(plan: plan, media: media)
        let rate = settings.rate
        let duration = rate.time(frames: settings.durationFrames)

        var resources: [NativeFCPXMLNode] = []
        // The DTD orders %intrinsic-params-video; before %video_filter_item;,
        // and the movie resource type keeps them as separate arguments so a
        // caller cannot accidentally interleave them.
        var intrinsics: [NativeFCPXMLNode] = []
        if let node = built.opacity.node { intrinsics.append(node) }
        let filters = [NativeFCPXMLColorAdjustments.filterNode(ref: "r5", saturation: settings.saturation)]

        var connectedLayers: [NativeFCPXMLConnectedLayer] = []
        if let overlayAsset = media[.incoming], let overlayURL = publishedMediaURLs[.incoming] {
            let overlayResources = NativeFCPXMLStillResources(
                sequenceFormatID: "r1", assetID: "r3", stillFormatID: "r4",
                name: overlayAsset.itemID, mediaURL: overlayURL,
                width: overlayAsset.dimensions.width, height: overlayAsset.dimensions.height, frameRate: rate
            )
            resources.append(contentsOf: [overlayResources.assetNode, overlayResources.stillFormatNode])
            connectedLayers.append(NativeFCPXMLConnectedLayer(
                ref: "r3",
                lane: 1,
                offsetWithinParent: rate.time(frames: settings.overlayStartFrame),
                name: overlayAsset.itemID,
                start: NativeFCPXMLStillTiming.sourceStart,
                duration: rate.time(frames: settings.overlayDurationFrames),
                blend: .composite(opacity: settings.overlayOpacity, mode: .overlay)
            ))
        }

        let name = StandaloneFCPXMLExportBuilder.projectName(for: plan)
        let spineChild: NativeFCPXMLNode
        var allResources: [NativeFCPXMLNode]

        switch base.kind {
        case .movie:
            let baseResources = NativeFCPXMLMovieResources(
                formatID: "r1", assetID: "r2", name: base.itemID, mediaURL: baseURL,
                sourceDuration: rate.time(frames: base.durationSeconds.map { rate.frames(seconds: $0) } ?? settings.durationFrames),
                hasAudio: base.hasAudio
            )
            spineChild = baseResources.assetClipNode(
                offset: .zero,
                duration: duration,
                intrinsics: intrinsics,
                connectedLayers: connectedLayers,
                filters: filters
            )
            allResources = [baseResources.formatNode, baseResources.assetNode]
        case .still:
            let baseResources = NativeFCPXMLStillResources(
                sequenceFormatID: "r1", assetID: "r2", stillFormatID: "r6",
                name: base.itemID, mediaURL: baseURL,
                width: base.dimensions.width, height: base.dimensions.height, frameRate: rate
            )
            // The still resource takes one ordered array, so the intrinsic /
            // connected / filter ordering is assembled by hand here to match
            // what the connected-layer capture returned.
            spineChild = baseResources.videoNode(
                offset: .zero,
                duration: duration,
                children: intrinsics + connectedLayers.map(\.node) + filters
            )
            allResources = baseResources.resourceNodes
        }

        allResources.append(contentsOf: resources)
        allResources.append(NativeFCPXMLColorAdjustments.effectNode(id: "r5"))

        return NativeFCPXMLDocument(
            version: version,
            resources: allResources,
            eventName: name,
            projectName: name,
            sequenceFormatID: "r1",
            sequenceDuration: duration,
            spineChildren: [spineChild]
        ).xmlString
    }
}
