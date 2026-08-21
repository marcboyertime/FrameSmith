import XCTest
@testable import FCPCommandConsoleCore

/// The two emitters that generalize previously probe-only constructions.
///
/// These check the *construction rules* the ground-truth captures established,
/// not just that XML came out. Every rule here corresponds to a way Final Cut
/// silently rewrites or misplaces a document that looks fine.
final class StandaloneTransitionEmitterTests: XCTestCase {
    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }

    private func movie(_ id: String, seconds: Double = 8, digest: Character = "a") -> LocalMediaAsset {
        LocalMediaAsset(
            itemID: id, url: URL(fileURLWithPath: "/tmp/\(id).mov"), kind: .movie,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: seconds, frameRate: 30, hasAudio: true,
            canonicalPath: "/tmp/\(id).mov", sha256: String(repeating: digest, count: 64)
        )
    }
    private func still(_ id: String, digest: Character = "s") -> LocalMediaAsset {
        LocalMediaAsset(
            itemID: id, url: URL(fileURLWithPath: "/tmp/\(id).png"), kind: .still,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: nil, frameRate: nil, hasAudio: false,
            canonicalPath: "/tmp/\(id).png", sha256: String(repeating: digest, count: 64)
        )
    }

    private let oldTelevisionDefaults: [String: ParameterValue] = [
        "durationSeconds": .number(4),
        "profile": .string("broadcast-mono"),
        "intensity": .number(0.68),
        "scanlineStrength": .number(0.42),
        "noiseStrength": .number(0.28),
        "syncInstability": .number(0.22),
        "chromaSeparation": .number(0.18),
        "bloomStrength": .number(0.20),
        "vignetteStrength": .number(0.34),
        "ghostingStrength": .number(0.10),
        "flickerStrength": .number(0.12),
        "seed": .integer(7341),
        "outputLongEdge": .integer(1920),
        "fps": .integer(30),
        "renderMethod": .string("ffmpeg-crt-v2"),
        "preserveOriginal": .boolean(true)
    ]

    private func plan(_ effect: EffectID, parameters: [String: ParameterValue] = [:]) -> EffectPlan {
        let source = SourceIdentity(itemID: "a", canonicalPath: "/tmp/a.mov", sha256: String(repeating: "a", count: 64))
        let resolvedParameters = effect == .oldTelevision
            ? oldTelevisionDefaults.merging(parameters) { _, override in override }
            : parameters
        let renderedAsset = GeneratedAssetDefinition(
            kind: "crt-treatment-movie",
            format: "prores-422-10bit",
            alpha: false,
            deterministic: true
        )
        return EffectPlan(
            originalRequest: "test",
            confidence: 1,
            effectID: effect,
            selectionToken: SelectionToken(selectionType: .singleClip, clipIDs: ["a"], sourceIdentities: [source], revision: "r1"),
            parameters: resolvedParameters,
            representation: effect == .oldTelevision ? .layeredMedia : .fcpxmlNative,
            generatedAssets: effect == .oldTelevision ? [renderedAsset] : [],
            previewStrategy: effect == .oldTelevision ? "checksum-bound-rendered-movie" : "",
            fallback: effect == .oldTelevision ? "refuse-if-crt-renderer-unavailable" : "none",
            preconditionRevision: "r1"
        )
    }

    /// A checksum-bound prepared asset without invoking the renderer. The
    /// shared FCPXML boundary validates its file, source, construction, timing,
    /// and digest before it may become the connected layer.
    private func preparedCRTAsset(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        frameCount: Int = 120,
        durationSeconds: Double = 4
    ) throws -> RenderedEffectAsset {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "fcpcc-rendered-crt-emitter-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("old-television.mov")
        try Data("sealed rendered CRT fixture".utf8).write(to: url)
        let primary = try XCTUnwrap(media[.primary])
        return RenderedEffectAsset(
            url: url,
            sha256: try ContentHasher.sha256File(url),
            constructionDigest: try RenderedConstructionIdentity.digest(plan: plan, media: media),
            rendererRecipeDigest: String(repeating: "r", count: 64),
            sourceSHA256: primary.sha256,
            width: 1920,
            height: 1080,
            fps: 30,
            frameCount: frameCount,
            durationSeconds: durationSeconds,
            videoFormat: .proRes422HQ10Bit,
            videoOnly: true,
            provenance: [
                "renderer": OldTelevisionRenderAdapter.rendererVersion,
                "codecProfile": "HQ",
                "codecFourCC": "apch"
            ]
        )
    }

    // MARK: - Natural dissolve construction rules

    /// The four rules together. Any one of them missing produces a document
    /// Final Cut accepts and then silently rewrites.
    func testDissolveReproducesAllFourAdmittedConstructionRules() throws {
        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let xml = try NaturalDissolveStandaloneEmitter().emitDocument(
            plan: plan(.naturalDissolve, parameters: ["durationFrames": .integer(12)]),
            media: [.outgoing: outgoing, .incoming: incoming],
            publishedMediaURLs: [.outgoing: outgoing.url, .incoming: incoming.url],
            version: "1.14"
        )

        // Rule 1: a real effect resource carrying the Cross Dissolve UID.
        XCTAssertTrue(xml.contains(#"uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265""#), "missing effect resource UID")
        // Rule 2: a filter-video on the transition referencing it.
        XCTAssertTrue(xml.contains(#"<filter-video ref="r4""#), "transition must reference the effect resource")
        // Rule 3: the centred offset. 8s clips and the canonical 12-frame
        // transition leave a six-frame handle on each side: visible outgoing
        // 234 frames, cut at 234, offset 228 = 22800/3000s.
        XCTAssertTrue(xml.contains(#"<transition name="Cross Dissolve" offset="22800/3000s" duration="1200/3000s""#), xml)
        // Rule 4: butt-joined. The incoming clip's offset equals the cut.
        XCTAssertTrue(xml.contains(#"offset="23400/3000s" start="600/3000s""#), "incoming clip must butt-join at the cut")
    }

    /// Revision 3's failure signature: overlapping clips are DTD-valid and are
    /// silently re-flowed. The incoming clip must start exactly at the cut.
    func testDissolveClipsButtJoinRatherThanOverlap() throws {
        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let emitter = NaturalDissolveStandaloneEmitter()
        let channels = try emitter.channels(
            plan: plan(.naturalDissolve, parameters: ["durationFrames": .integer(12)]),
            media: [.outgoing: outgoing, .incoming: incoming]
        )
        let transition = try XCTUnwrap(channels.transition)
        XCTAssertEqual(transition.cutFrame, transition.outgoingDurationFrames, "the cut is where the outgoing clip ends")
        XCTAssertEqual(
            transition.outgoingDurationFrames + transition.incomingDurationFrames,
            Int((channels.durationSeconds * 30).rounded()),
            "clip lengths must sum to the sequence with no overlap"
        )
    }

    func testRegistryPlannedCanonicalDissolveDrivesChannelsAndXML() throws {
        let registry = try registry()
        let selection = SelectionToken(
            selectionType: .twoAdjacentClips,
            origin: .localMedia,
            clipIDs: ["clip-a", "clip-b"],
            sourceIdentities: [
                SourceIdentity(itemID: "clip-a", canonicalPath: "/tmp/clip-a.mov", sha256: String(repeating: "a", count: 64)),
                SourceIdentity(itemID: "clip-b", canonicalPath: "/tmp/clip-b.mov", sha256: String(repeating: "b", count: 64))
            ],
            revision: "r1",
            startFrame: 0,
            endFrame: 12,
            sourceDurationFrames: 240,
            handleBeforeFrames: 6,
            handleAfterFrames: 6
        )
        let planned = try DeterministicPlanner(registry: registry).plan(
            request: "Make this clip dissolve naturally into the next clip.",
            selection: selection
        )
        let definition = try registry.definition(for: .naturalDissolve)
        let canonical = Dictionary(uniqueKeysWithValues: definition.parameters.map { ($0.name, $0.defaultValue!) })
        XCTAssertEqual(planned.parameters, canonical)
        try PlanValidator(registry: registry).validate(planned)

        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let emitter = NaturalDissolveStandaloneEmitter()
        let channels = try emitter.channels(plan: planned, media: [.outgoing: outgoing, .incoming: incoming])
        XCTAssertEqual(channels.transition?.durationFrames, 12)
        let xml = try emitter.emitDocument(
            plan: planned,
            media: [.outgoing: outgoing, .incoming: incoming],
            publishedMediaURLs: [.outgoing: outgoing.url, .incoming: incoming.url],
            version: "1.14"
        )
        XCTAssertTrue(xml.contains(#"duration="1200/3000s""#), xml)
    }

    /// The director-control contract: an effect never moves an edit point to
    /// make itself fit. Insufficient handle is a refusal, not a trim.
    func testDissolveRefusesInsteadOfMovingTheEditPoint() {
        XCTAssertThrowsError(try NaturalDissolveStandaloneEmitter.geometry(
            rate: .thirty,
            outgoingFrames: 100,
            incomingFrames: 100,
            transitionFrames: 60,
            outgoingSourceFrames: 110,   // only 10 frames of handle, 30 needed
            incomingSourceStartFrame: 30
        )) { error in
            guard case StandaloneCompositionError.insufficientHandle(let side, let available, let required) = error else {
                return XCTFail("expected an insufficient-handle refusal, got \(error)")
            }
            XCTAssertEqual(side, "outgoing")
            XCTAssertEqual(available, 10)
            XCTAssertEqual(required, 30)
        }
    }

    func testDissolveRefusesWhenTheIncomingClipHasNoHeadHandle() {
        XCTAssertThrowsError(try NaturalDissolveStandaloneEmitter.geometry(
            rate: .thirty, outgoingFrames: 100, incomingFrames: 100, transitionFrames: 60,
            outgoingSourceFrames: 200, incomingSourceStartFrame: 5
        )) { error in
            guard case StandaloneCompositionError.insufficientHandle(let side, _, _) = error else {
                return XCTFail("expected an insufficient-handle refusal, got \(error)")
            }
            XCTAssertEqual(side, "incoming")
        }
    }

    /// An odd duration cannot be split evenly, so the centred offset would land
    /// off a frame boundary and the result would be ambiguous rather than wrong.
    func testDissolveDurationIsForcedEvenSoTheOffsetStaysFrameAligned() throws {
        let geometry = try NaturalDissolveStandaloneEmitter.geometry(
            rate: .thirty, outgoingFrames: 100, incomingFrames: 100, transitionFrames: 45,
            outgoingSourceFrames: 200, incomingSourceStartFrame: 50
        )
        XCTAssertEqual(geometry.transitionFrames % 2, 0)
        XCTAssertEqual(geometry.transitionOffsetFrames, geometry.cutFrame - geometry.transitionFrames / 2)
    }

    func testDissolveRejectsMissingOrInvalidRegistryDurationFrames() {
        let single = movie("only", digest: "a")
        XCTAssertThrowsError(try NaturalDissolveStandaloneEmitter().channels(
            plan: plan(.naturalDissolve), media: [.primary: single]
        )) { error in
            XCTAssertEqual(error as? StandaloneCompositionError, .missingSecondClip)
        }

        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let invalidParameters: [[String: ParameterValue]] = [
            [:],
            ["durationFrames": .number(.infinity)],
            ["durationFrames": .number(12.5)],
            ["durationFrames": .integer(0)],
            ["durationFrames": .integer(121)]
        ]
        for parameters in invalidParameters {
            XCTAssertThrowsError(try NaturalDissolveStandaloneEmitter().channels(
                plan: plan(.naturalDissolve, parameters: parameters),
                media: [.outgoing: outgoing, .incoming: incoming]
            )) { error in
                guard case StandaloneExportError.invalidRecipe = error else {
                    return XCTFail("expected invalid-recipe refusal, got \(error)")
                }
            }
        }
    }

    // MARK: - Old television construction rules

    func testOldTelevisionChannelsAreNeutralAndDirectEmissionRequiresPreparedRender() throws {
        let base = movie("base", digest: "a")
        let treatment = plan(.oldTelevision)
        let channels = try OldTelevisionStandaloneEmitter().channels(
            plan: treatment,
            media: [.primary: base]
        )
        XCTAssertTrue(channels.transform.isEmpty)
        XCTAssertTrue(channels.opacity.isEmpty, "micro-flicker is baked into pixels, never an opacity fade")
        XCTAssertNil(channels.saturation, "the rendered treatment must not add an indicative native colour filter")
        XCTAssertNil(channels.overlay, "the optional user-still overlay path was retired")
        XCTAssertEqual(channels.durationSeconds, 4)

        XCTAssertThrowsError(try OldTelevisionStandaloneEmitter().emitDocument(
            plan: treatment,
            media: [.primary: base],
            publishedMediaURLs: [.primary: base.url],
            version: "1.14"
        )) { error in
            guard case StandaloneExportError.invalidRecipe(let reason) = error else {
                return XCTFail("expected prepared-render refusal, got \(error)")
            }
            XCTAssertTrue(reason.contains("checksum-bound prepared render"), reason)
        }
    }

    func testPreparedRenderedMovieIsAFullDurationParentRelativeLayerAndPreservesSpineAudio() throws {
        let base = movie("base", digest: "a")
        let treatment = plan(.oldTelevision)
        let media: [LocalMediaRole: LocalMediaAsset] = [.primary: base]
        let prepared = try preparedCRTAsset(plan: treatment, media: media)
        let xml = try OldTelevisionStandaloneEmitter().emitPreparedDocument(
            plan: treatment,
            media: media,
            publishedMediaURLs: [.primary: base.url],
            preparedAsset: prepared,
            publishedPreparedURL: URL(fileURLWithPath: "/tmp/package/Media/old-television.mov"),
            version: "1.14"
        )

        XCTAssertTrue(
            xml.contains(#"<video ref="r3" lane="1" offset="0s" name="old-television.mov" start="0s" duration="4s"/>"#),
            xml
        )
        XCTAssertEqual(
            xml.components(separatedBy: #"hasAudio="1""#).count - 1,
            1,
            "only the unchanged spine source retains audio"
        )
        XCTAssertFalse(xml.contains("Color Adjustments"), xml)
        XCTAssertFalse(xml.contains("adjust-blend"), xml)
        XCTAssertFalse(xml.contains(#"<param name="amount">"#), xml)
    }

    func testRegistryPlannedOldTelevisionDrivesNeutralChannelsAndOneGeneratedMovie() throws {
        let registry = try registry()
        let selection = SelectionToken(
            selectionType: .singleClip,
            origin: .localMedia,
            clipIDs: ["base"],
            sourceIdentities: [SourceIdentity(itemID: "base", canonicalPath: "/tmp/base.mov", sha256: String(repeating: "a", count: 64))],
            revision: "r1",
            startFrame: 0,
            endFrame: 120,
            sourceDurationFrames: 240
        )
        let planned = try DeterministicPlanner(registry: registry).plan(request: "old television", selection: selection)
        try PlanValidator(registry: registry).validate(planned)
        let definition = try registry.definition(for: .oldTelevision)
        let canonical = Dictionary(uniqueKeysWithValues: definition.parameters.map { ($0.name, $0.defaultValue!) })
        XCTAssertEqual(planned.parameters, canonical)
        XCTAssertEqual(planned.generatedAssets, [
            GeneratedAssetDefinition(
                kind: "crt-treatment-movie",
                format: "prores-422-10bit",
                alpha: false,
                deterministic: true
            )
        ])
        XCTAssertEqual(planned.previewStrategy, "checksum-bound-rendered-movie")
        XCTAssertEqual(planned.fallback, "refuse-if-crt-renderer-unavailable")

        let base = movie("base", digest: "a")
        let emitter = OldTelevisionStandaloneEmitter()
        let channels = try emitter.channels(plan: planned, media: [.primary: base])
        XCTAssertEqual(channels.durationSeconds, 4)
        XCTAssertTrue(channels.transform.isEmpty)
        XCTAssertTrue(channels.opacity.isEmpty)
        XCTAssertNil(channels.saturation)
        XCTAssertNil(channels.overlay)

        var missing = planned
        missing.parameters.removeValue(forKey: "intensity")
        XCTAssertThrowsError(try emitter.channels(plan: missing, media: [.primary: base])) { error in
            guard case StandaloneExportError.invalidRecipe = error else { return XCTFail("expected invalid recipe, got \(error)") }
        }
        var unknown = planned
        unknown.parameters["unsupported"] = .number(1)
        XCTAssertThrowsError(try emitter.channels(plan: unknown, media: [.primary: base])) { error in
            guard case StandaloneExportError.invalidRecipe = error else { return XCTFail("expected invalid recipe, got \(error)") }
        }
    }

    func testPreparedRenderMustMatchTheExactParentDuration() throws {
        let base = movie("base", digest: "a")
        let treatment = plan(.oldTelevision)
        let media: [LocalMediaRole: LocalMediaAsset] = [.primary: base]
        let short = try preparedCRTAsset(
            plan: treatment,
            media: media,
            frameCount: 90,
            durationSeconds: 3
        )
        XCTAssertThrowsError(try OldTelevisionStandaloneEmitter().emitPreparedDocument(
            plan: treatment,
            media: media,
            publishedMediaURLs: [.primary: base.url],
            preparedAsset: short,
            publishedPreparedURL: URL(fileURLWithPath: "/tmp/package/Media/short.mov"),
            version: "1.14"
        )) { error in
            guard case StandaloneExportError.admittedArtifactMismatch(let reason) = error else {
                return XCTFail("expected exact-timing refusal, got \(error)")
            }
            XCTAssertTrue(reason.contains("timing does not match"), reason)
        }
    }

    func testPreparedOldTelevisionSupportsAStillWithoutReusingItsOneHourOrigin() throws {
        let base = still("still-base", digest: "s")
        let treatment = plan(.oldTelevision, parameters: ["durationSeconds": .number(3)])
        let media: [LocalMediaRole: LocalMediaAsset] = [.primary: base]
        let prepared = try preparedCRTAsset(
            plan: treatment,
            media: media,
            frameCount: 90,
            durationSeconds: 3
        )
        let xml = try OldTelevisionStandaloneEmitter().emitPreparedDocument(
            plan: treatment,
            media: media,
            publishedMediaURLs: [.primary: base.url],
            preparedAsset: prepared,
            publishedPreparedURL: URL(fileURLWithPath: "/tmp/package/Media/old-television.mov"),
            version: "1.14"
        )
        XCTAssertTrue(xml.contains(#"start="3600s" duration="3s""#), xml)
        XCTAssertTrue(
            xml.contains(#"<video ref="r3" lane="1" offset="0s" name="old-television.mov" start="0s" duration="3s"/>"#),
            xml
        )
    }

    func testNeutralChannelsKeepMediaKindOriginWithoutOpacityFlicker() throws {
        let emitter = OldTelevisionStandaloneEmitter()
        let movieChannels = try emitter.channels(plan: plan(.oldTelevision), media: [.primary: movie("m", digest: "a")])
        XCTAssertEqual(movieChannels.origin, .movieFromZero)
        XCTAssertTrue(movieChannels.opacity.isEmpty)

        let stillChannels = try emitter.channels(plan: plan(.oldTelevision), media: [.primary: still("s", digest: "s")])
        XCTAssertEqual(stillChannels.origin, .still)
        XCTAssertTrue(stillChannels.opacity.isEmpty)
    }

    // MARK: - Preview and export share one construction

    func testBothEmittersExposeChannelsThatMatchWhatTheyEmit() throws {
        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let dissolve = NaturalDissolveStandaloneEmitter()
        let dissolvePlan = plan(.naturalDissolve, parameters: ["durationFrames": .integer(12)])
        let dissolveChannels = try dissolve.channels(plan: dissolvePlan, media: [.outgoing: outgoing, .incoming: incoming])
        let dissolveXML = try dissolve.emitDocument(
            plan: dissolvePlan, media: [.outgoing: outgoing, .incoming: incoming],
            publishedMediaURLs: [.outgoing: outgoing.url, .incoming: incoming.url], version: "1.14"
        )
        let transition = try XCTUnwrap(dissolveChannels.transition)
        let rate = NativeFCPXMLFrameRate.thirty
        XCTAssertTrue(
            dissolveXML.contains("duration=\"\(rate.time(frames: transition.durationFrames).attributeValue)\""),
            "the previewed transition duration must be the emitted one"
        )

        let base = movie("base", digest: "c")
        let television = OldTelevisionStandaloneEmitter()
        let televisionPlan = plan(.oldTelevision)
        let televisionMedia: [LocalMediaRole: LocalMediaAsset] = [.primary: base]
        let televisionChannels = try television.channels(plan: televisionPlan, media: televisionMedia)
        let prepared = try preparedCRTAsset(plan: televisionPlan, media: televisionMedia)
        let televisionXML = try television.emitPreparedDocument(
            plan: televisionPlan,
            media: televisionMedia,
            publishedMediaURLs: [.primary: base.url],
            preparedAsset: prepared,
            publishedPreparedURL: URL(fileURLWithPath: "/tmp/package/Media/old-television.mov"),
            version: "1.14"
        )
        XCTAssertTrue(televisionChannels.opacity.isEmpty)
        XCTAssertNil(televisionChannels.overlay)
        XCTAssertTrue(
            televisionXML.contains(#"<video ref="r3" lane="1" offset="0s" name="old-television.mov" start="0s" duration="4s"/>"#),
            "preview and export must share the prepared full-duration movie"
        )
    }
}
