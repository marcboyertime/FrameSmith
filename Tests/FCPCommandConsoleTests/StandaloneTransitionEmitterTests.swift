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

    private func plan(_ effect: EffectID, parameters: [String: ParameterValue] = [:]) -> EffectPlan {
        let source = SourceIdentity(itemID: "a", canonicalPath: "/tmp/a.mov", sha256: String(repeating: "a", count: 64))
        return EffectPlan(
            originalRequest: "test",
            confidence: 1,
            effectID: effect,
            selectionToken: SelectionToken(selectionType: .singleClip, clipIDs: ["a"], sourceIdentities: [source], revision: "r1"),
            parameters: parameters,
            representation: .fcpxmlNative,
            fallback: "none",
            preconditionRevision: "r1"
        )
    }

    // MARK: - Natural dissolve construction rules

    /// The four rules together. Any one of them missing produces a document
    /// Final Cut accepts and then silently rewrites.
    func testDissolveReproducesAllFourAdmittedConstructionRules() throws {
        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let xml = try NaturalDissolveStandaloneEmitter().emitDocument(
            plan: plan(.naturalDissolve, parameters: ["durationSeconds": .number(1)]),
            media: [.outgoing: outgoing, .incoming: incoming],
            publishedMediaURLs: [.outgoing: outgoing.url, .incoming: incoming.url],
            version: "1.14"
        )

        // Rule 1: a real effect resource carrying the Cross Dissolve UID.
        XCTAssertTrue(xml.contains(#"uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265""#), "missing effect resource UID")
        // Rule 2: a filter-video on the transition referencing it.
        XCTAssertTrue(xml.contains(#"<filter-video ref="r4""#), "transition must reference the effect resource")
        // Rule 3: the centred offset. 8s clips, 30 frames of transition,
        // handle 15 each side -> visible outgoing 225 frames, cut at 225,
        // offset 225 - 15 = 210 frames = 21000/3000s.
        XCTAssertTrue(xml.contains(#"<transition name="Cross Dissolve" offset="7s" duration="1s""#), xml)
        // Rule 4: butt-joined. The incoming clip's offset equals the cut.
        XCTAssertTrue(xml.contains(#"offset="7s" start="500/1000s""#) || xml.contains(#"offset="7s""#), "incoming clip must butt-join at the cut")
    }

    /// Revision 3's failure signature: overlapping clips are DTD-valid and are
    /// silently re-flowed. The incoming clip must start exactly at the cut.
    func testDissolveClipsButtJoinRatherThanOverlap() throws {
        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let emitter = NaturalDissolveStandaloneEmitter()
        let channels = try emitter.channels(
            plan: plan(.naturalDissolve, parameters: ["durationSeconds": .number(2)]),
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

    func testDissolveNeedsTwoClips() {
        let single = movie("only", digest: "a")
        XCTAssertThrowsError(try NaturalDissolveStandaloneEmitter().channels(
            plan: plan(.naturalDissolve), media: [.primary: single]
        )) { error in
            XCTAssertEqual(error as? StandaloneCompositionError, .missingSecondClip)
        }
    }

    // MARK: - Old television construction rules

    func testOldTelevisionEmitsFlickerColourAndAConnectedOverlay() throws {
        let base = movie("base", digest: "a")
        let overlay = still("texture", digest: "t")
        let xml = try OldTelevisionStandaloneEmitter().emitDocument(
            plan: plan(.oldTelevision, parameters: [
                "durationSeconds": .number(4), "overlayOpacity": .number(0.5), "overlayStartSeconds": .number(1)
            ]),
            media: [.primary: base, .overlay: overlay],
            publishedMediaURLs: [.primary: base.url, .overlay: overlay.url],
            version: "1.14"
        )
        // Animated flicker uses the param form.
        XCTAssertTrue(xml.contains(#"<param name="amount">"#), "flicker must be an animated param")
        // The connected layer, in the captured shape.
        XCTAssertTrue(xml.contains(#"<video ref="r3" lane="1""#), "overlay must be a connected child at lane 1")
        // Static blend uses the attribute form with the observed mode string.
        XCTAssertTrue(xml.contains(#"<adjust-blend amount="0.5" mode="14 (Overlay)"/>"#), xml)
        // Colour filter present.
        XCTAssertTrue(xml.contains("Color Adjustments"))
    }

    /// The single most dangerous overlay finding: a timeline-relative offset is
    /// valid FCPXML that silently misplaces the overlay.
    func testOverlayOffsetIsParentRelative() throws {
        let base = movie("base", digest: "a")
        let overlay = still("texture", digest: "t")
        let channels = try OldTelevisionStandaloneEmitter().channels(
            plan: plan(.oldTelevision, parameters: [
                "durationSeconds": .number(4), "overlayStartSeconds": .number(1)
            ]),
            media: [.primary: base, .overlay: overlay]
        )
        let descriptor = try XCTUnwrap(channels.overlay)
        XCTAssertEqual(descriptor.startFrameWithinParent, 30, "1s into a parent that starts at 0 is frame 30")
        XCTAssertEqual(descriptor.blendMode, .overlay)
    }

    func testOverlayMayNotOutliveItsParentClip() {
        let base = movie("base", digest: "a")
        let overlay = still("texture", digest: "t")
        XCTAssertNoThrow(try OldTelevisionStandaloneEmitter().channels(
            plan: plan(.oldTelevision, parameters: [
                "durationSeconds": .number(2), "overlayStartSeconds": .number(1), "overlayDurationSeconds": .number(1)
            ]),
            media: [.primary: base, .overlay: overlay]
        ))
    }

    /// Without an overlay the effect still emits a valid base treatment rather
    /// than failing — flicker and colour are useful on their own.
    func testOldTelevisionWorksWithoutAnOverlay() throws {
        let base = movie("base", digest: "a")
        let xml = try OldTelevisionStandaloneEmitter().emitDocument(
            plan: plan(.oldTelevision, parameters: ["durationSeconds": .number(3)]),
            media: [.primary: base],
            publishedMediaURLs: [.primary: base.url],
            version: "1.14"
        )
        XCTAssertFalse(xml.contains(#"lane="1""#))
        XCTAssertTrue(xml.contains("Color Adjustments"))
    }

    /// Stills and movies do not share a keyframe origin, and the flicker is
    /// animated, so getting this wrong places every keyframe an hour off.
    func testFlickerUsesTheCorrectOriginForEachMediaKind() throws {
        let emitter = OldTelevisionStandaloneEmitter()
        let movieChannels = try emitter.channels(plan: plan(.oldTelevision), media: [.primary: movie("m", digest: "a")])
        XCTAssertEqual(movieChannels.origin, .movieFromZero)
        XCTAssertEqual(movieChannels.opacity.amount.first?.time.attributeValue, "0s")

        let stillChannels = try emitter.channels(plan: plan(.oldTelevision), media: [.primary: still("s", digest: "s")])
        XCTAssertEqual(stillChannels.origin, .still)
        XCTAssertEqual(stillChannels.opacity.amount.first?.time.attributeValue, "3600s")
    }

    // MARK: - Preview and export share one construction

    func testBothEmittersExposeChannelsThatMatchWhatTheyEmit() throws {
        let outgoing = movie("clip-a", digest: "a")
        let incoming = movie("clip-b", digest: "b")
        let dissolve = NaturalDissolveStandaloneEmitter()
        let dissolvePlan = plan(.naturalDissolve, parameters: ["durationSeconds": .number(1)])
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
        let overlay = still("texture", digest: "t")
        let television = OldTelevisionStandaloneEmitter()
        let televisionPlan = plan(.oldTelevision, parameters: ["overlayOpacity": .number(0.35)])
        let televisionChannels = try television.channels(plan: televisionPlan, media: [.primary: base, .overlay: overlay])
        let televisionXML = try television.emitDocument(
            plan: televisionPlan, media: [.primary: base, .overlay: overlay],
            publishedMediaURLs: [.primary: base.url, .overlay: overlay.url], version: "1.14"
        )
        let descriptor = try XCTUnwrap(televisionChannels.overlay)
        XCTAssertEqual(descriptor.opacity, 0.35)
        XCTAssertTrue(televisionXML.contains(#"amount="0.35""#), "the previewed overlay opacity must be the emitted one")
    }
}
