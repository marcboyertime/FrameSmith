import Foundation
import XCTest
@testable import FCPCommandConsoleCore

/// Covers the evaluator the preview reads.
///
/// The sampler's job is to undo, exactly, the unit work the emitter does:
/// percent-of-height back to pixels, positive-Y-up back to positive-Y-down.
/// A sign or scale error here shows the user a confident picture of something
/// the export will not do — which is worse than no preview.
final class ChannelSamplerTests: XCTestCase {
    private let rate = NativeFCPXMLFrameRate.thirty
    private let sampler = NativeFCPXMLChannelSampler(frameHeight: 1080)

    // MARK: - Interpolation

    func testSamplingReturnsExactValuesAtKeyframes() {
        let track = [
            NativeFCPXMLKeyframe(time: .seconds(0), value: "0"),
            NativeFCPXMLKeyframe(time: .seconds(4), value: "12")
        ]
        XCTAssertEqual(try XCTUnwrap(sampler.sample(track, at: 0)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(sampler.sample(track, at: 4)), 12, accuracy: 1e-9)
    }

    func testSamplingInterpolatesLinearlyBetweenKeyframes() {
        let track = [
            NativeFCPXMLKeyframe(time: .seconds(0), value: "0"),
            NativeFCPXMLKeyframe(time: .seconds(4), value: "12")
        ]
        XCTAssertEqual(try XCTUnwrap(sampler.sample(track, at: 2)), 6, accuracy: 1e-9)
    }

    /// Final Cut holds a parameter flat before its first keyframe. Native
    /// effects still rely on this rule even though Living Still v2 is rendered.
    func testSamplingHoldsFlatOutsideTheTrack() {
        let track = [
            NativeFCPXMLKeyframe(time: .seconds(2), value: "1"),
            NativeFCPXMLKeyframe(time: .seconds(4), value: "0")
        ]
        XCTAssertEqual(try XCTUnwrap(sampler.sample(track, at: 0)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(sampler.sample(track, at: 99)), 0, accuracy: 1e-9)
    }

    func testEmptyTrackSamplesToNothing() {
        XCTAssertNil(sampler.sample([], at: 1))
    }

    /// Scale keyframes carry pairs; everything else is scalar.
    func testPairedValuesSampleTheirFirstComponent() {
        let track = [NativeFCPXMLKeyframe(time: .seconds(0), value: "1.08 1.08")]
        XCTAssertEqual(try XCTUnwrap(sampler.sample(track, at: 0)), 1.08, accuracy: 1e-9)
    }

    // MARK: - Units, in the direction the preview needs

    /// The emitter converts pixels → percent of height and flips Y. The
    /// sampler must undo both, or a downward pan previews as upward.
    func testYFlipRoundTripsBackToScreenDown() {
        // A plan asking to move the framing DOWN by 200px.
        let emitted = NativeFCPXMLTransformUnits.positionY(fromHeightFraction: 200.0 / 1080.0, height: 1080)
        XCTAssertLessThan(emitted, 0, "Final Cut's +Y is up, so downward must emit negative")

        let channel = NativeFCPXMLTransformChannel(
            positionY: [NativeFCPXMLKeyframe(time: .seconds(0), value: NativeFCPXMLNumber.string(emitted))]
        )
        let state = sampler.state(
            transform: channel,
            opacity: NativeFCPXMLOpacityChannel(),
            atClipSeconds: 0,
            origin: .movieFromZero
        )
        XCTAssertGreaterThan(state.offsetY, 0, "screen coordinates are +Y down, so it must come back positive")
        XCTAssertEqual(state.offsetY, 200, accuracy: 0.01)
    }

    func testPercentOfHeightConvertsBackToPixels() {
        let channel = NativeFCPXMLTransformChannel(
            positionX: [NativeFCPXMLKeyframe(time: .seconds(0), value: "18.5185")]
        )
        let state = sampler.state(
            transform: channel,
            opacity: NativeFCPXMLOpacityChannel(),
            atClipSeconds: 0,
            origin: .movieFromZero
        )
        XCTAssertEqual(state.offsetX, 200, accuracy: 0.01)
    }

    // MARK: - Origin

    /// A still's keyframes are absolute from 3600 s and a movie's from 0 s, so
    /// "one second into the clip" is a different absolute time for each.
    /// Getting this wrong previews an hour of empty hold.
    func testClipTimeResolvesAgainstTheRightOrigin() {
        let stillTrack = [
            NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.still.keyframeTime(frame: 0, rate: rate), value: "0"),
            NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.still.keyframeTime(frame: 60, rate: rate), value: "10")
        ]
        let channel = NativeFCPXMLTransformChannel(positionX: stillTrack)

        let atStart = sampler.state(transform: channel, opacity: .init(), atClipSeconds: 0, origin: .still)
        let atTwoSeconds = sampler.state(transform: channel, opacity: .init(), atClipSeconds: 2, origin: .still)
        XCTAssertEqual(atStart.offsetX, 0, accuracy: 0.01)
        XCTAssertEqual(atTwoSeconds.offsetX, 10.0 / 100 * 1080, accuracy: 0.01)

        // The same clip time read against the wrong origin lands an hour early
        // and holds at the first value forever.
        let wrongOrigin = sampler.state(transform: channel, opacity: .init(), atClipSeconds: 2, origin: .movieFromZero)
        XCTAssertEqual(wrongOrigin.offsetX, 0, accuracy: 0.01)
    }

    // MARK: - Static forms

    func testStaticPositionAndOpacityAreUsedWhenNothingIsAnimated() {
        let channel = NativeFCPXMLTransformChannel(staticPosition: (x: 18.5185, y: -9.25926))
        let blend = NativeFCPXMLOpacityChannel.composite(opacity: 0.5, mode: .overlay)
        let state = sampler.state(transform: channel, opacity: blend, atClipSeconds: 1, origin: .movieFromZero)

        XCTAssertEqual(state.offsetX, 200, accuracy: 0.01)
        XCTAssertEqual(state.offsetY, 100, accuracy: 0.01, "negative emitted Y is downward on screen")
        XCTAssertEqual(state.opacity, 0.5, accuracy: 1e-9)
    }

    func testAbsentChannelsSampleToIdentity() {
        let state = sampler.state(
            transform: NativeFCPXMLTransformChannel(),
            opacity: NativeFCPXMLOpacityChannel(),
            atClipSeconds: 1,
            origin: .movieFromZero
        )
        XCTAssertEqual(state.offsetX, 0)
        XCTAssertEqual(state.offsetY, 0)
        XCTAssertEqual(state.scale, 1)
        XCTAssertEqual(state.rotationDegrees, 0)
        XCTAssertEqual(state.opacity, 1)
    }

    // MARK: - Preview and export read one construction

    /// Living Still's scalar preview is deliberately identity-only. Its visible
    /// construction is the exact checksum-bound movie that export connects
    /// above the unchanged one-hour-origin still.
    func testLivingStillUsesNeutralScalarChannelsAndThePreparedRenderedMovie() throws {
        let asset = LocalMediaAsset(
            itemID: "still",
            url: URL(fileURLWithPath: "/tmp/still.png"),
            kind: .still,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: nil,
            frameRate: nil,
            hasAudio: false,
            canonicalPath: "/tmp/still.png",
            sha256: String(repeating: "a", count: 64)
        )
        let selection = SelectionToken(
            selectionType: .singleClip,
            clipIDs: ["still"],
            sourceIdentities: [asset.sourceIdentity],
            revision: "r1"
        )
        let registryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("registry/effects")
        let plan = try DeterministicPlanner(registry: try EffectRegistry.load(from: registryRoot)).plan(
            request: "Make this a living still.",
            selection: selection,
            target: Target.confirmed(x: 0.5, y: 0.5)
        )

        let emitter = LivingStillStandaloneEmitter()
        let media: [LocalMediaRole: LocalMediaAsset] = [.primary: asset]
        let channels = try emitter.channels(plan: plan, media: media)
        XCTAssertTrue(channels.transform.isEmpty)
        XCTAssertTrue(channels.opacity.isEmpty)
        XCTAssertNil(channels.saturation)
        XCTAssertNil(channels.overlay)
        let preview = sampler.state(
            transform: channels.transform,
            opacity: channels.opacity,
            atClipSeconds: 2,
            origin: channels.origin
        )
        XCTAssertEqual(preview.offsetX, 0)
        XCTAssertEqual(preview.offsetY, 0)
        XCTAssertEqual(preview.scale, 1)
        XCTAssertEqual(preview.opacity, 1)
        XCTAssertThrowsError(try emitter.emitDocument(
            plan: plan,
            media: media,
            publishedMediaURLs: [.primary: URL(fileURLWithPath: "/tmp/out/still.png")],
            version: "1.14"
        ))

        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(
            "fcpcc-living-still-channel-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: scratch) }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let renderedURL = scratch.appendingPathComponent("living-still.mov")
        try Data("sealed depth render".utf8).write(to: renderedURL)
        let prepared = RenderedEffectAsset(
            url: renderedURL,
            sha256: try ContentHasher.sha256File(renderedURL),
            constructionDigest: try RenderedConstructionIdentity.digest(plan: plan, media: media),
            rendererRecipeDigest: String(repeating: "r", count: 64),
            sourceSHA256: asset.sha256,
            width: 1920,
            height: 1080,
            fps: 30,
            frameCount: 120,
            durationSeconds: 4,
            videoFormat: .proRes422HQ10Bit,
            videoOnly: true,
            provenance: [
                "model": "apple.coreml.depth-anything-v2-small-f16@cfef6f6f2a70783dedc0bfae40cecbc2052285d3",
                "motionMethod": "coreml-continuous-depth-warp-v2"
            ]
        )
        let document = try emitter.emitPreparedDocument(
            plan: plan,
            media: media,
            publishedMediaURLs: [.primary: URL(fileURLWithPath: "/tmp/out/still.png")],
            preparedAsset: prepared,
            publishedPreparedURL: URL(fileURLWithPath: "/tmp/out/living-still.mov"),
            version: "1.14"
        )
        XCTAssertTrue(document.contains(#"<video ref="r2" offset="0s" name="still" start="3600s" duration="4s">"#), document)
        XCTAssertTrue(document.contains(#"<video ref="r3" lane="1" offset="0s" name="living-still.mov" start="0s" duration="4s"/>"#), document)
        XCTAssertFalse(document.contains("adjust-transform"), document)
        XCTAssertFalse(document.contains("adjust-blend"), document)
        XCTAssertFalse(document.contains("Color Adjustments"), document)
        XCTAssertFalse(document.contains(#"hasAudio="1""#), document)
        XCTAssertEqual(channels.origin, .still, "a still must preview against the 3600s origin")
        XCTAssertEqual(channels.frameHeight, 1080)
    }
}

/// Pins the rotation convention observed 2026-08-06.
///
/// Final Cut's positive rotation is **counterclockwise**, established by
/// comparing frame 0 and frame 119 of the imported rotate/zoom project: the
/// colour-bar boundaries end with their tops left of their bottoms, and the
/// rainbow diagonal flips from sloping down-right to up-right. Both features
/// agree, so it is not an artefact of reading one edge.
///
/// The sampler carries Final Cut's sign unchanged; the renderer negates,
/// because SwiftUI's `rotationEffect` is clockwise-positive. Keeping the sign
/// unflipped here means the state reads the same as the exported XML.
extension ChannelSamplerTests {
    func testSamplerCarriesFinalCutsRotationSignUnchanged() {
        let channel = NativeFCPXMLTransformChannel(
            rotation: [NativeFCPXMLKeyframe(time: .seconds(0), value: "30")]
        )
        let state = NativeFCPXMLChannelSampler(frameHeight: 1080).state(
            transform: channel,
            opacity: NativeFCPXMLOpacityChannel(),
            atClipSeconds: 0,
            origin: .movieFromZero
        )
        XCTAssertEqual(
            state.rotationDegrees, 30, accuracy: 1e-9,
            "the sampler must report Final Cut's value; only the renderer negates"
        )
    }
}

/// Regression: the target picker drew its image top-left while the mapper
/// computed it centred, so clicks on the visible image were rejected as
/// letterbox and no target was ever set. Found by manual testing 2026-08-06.
///
/// The mapper was correct; the view was not. These pin the contract the view
/// has to satisfy, so the assumption is at least written down where a future
/// caller will meet it.
final class AspectFitCentringTests: XCTestCase {
    /// A portrait image in a wide container leaves letterbox on both sides,
    /// and the displayed rect must sit in the middle of it.
    func testPortraitMediaIsCentredInAWideContainer() throws {
        let media = MediaSize(width: 276, height: 361)
        let container = MediaSize(width: 880, height: 220)
        let rect = try AspectFitPointMapper.displayedRect(media: media, in: container)

        let expectedWidth = 220.0 * 276.0 / 361.0
        XCTAssertEqual(rect.size.height, 220, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, expectedWidth, accuracy: 0.001)
        XCTAssertEqual(rect.origin.x, (880 - expectedWidth) / 2, accuracy: 0.001)
        XCTAssertGreaterThan(rect.origin.x, 1, "there must be letterbox to the left of a centred portrait image")
    }

    /// The exact failure the user hit: a click where a top-left-aligned view
    /// draws the image is letterbox as far as the mapper is concerned.
    func testClickWhereATopLeftAlignedViewWouldDrawIsRejected() {
        let media = MediaSize(width: 276, height: 361)
        let container = MediaSize(width: 880, height: 220)
        // Middle of the image if it were drawn flush left.
        let asDrawnWhenBuggy = MediaPoint(x: 84, y: 110)

        XCTAssertThrowsError(
            try AspectFitPointMapper.target(for: asDrawnWhenBuggy, media: media, in: container)
        ) { error in
            XCTAssertEqual(error as? AspectFitPointMappingError, .outsideDisplayedMedia)
        }
    }

    /// The same click resolves once the view fills the container it measured.
    func testCentredClickResolvesToATarget() throws {
        let media = MediaSize(width: 276, height: 361)
        let container = MediaSize(width: 880, height: 220)
        let centre = MediaPoint(x: 440, y: 110)

        let target = try AspectFitPointMapper.target(for: centre, media: media, in: container)
        XCTAssertEqual(target.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(target.y, 0.5, accuracy: 0.001)
    }
}
