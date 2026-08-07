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

    /// Final Cut holds a parameter flat before its first keyframe — the reason
    /// the living still fade emits two keyframes rather than three.
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

    /// The property that makes the preview worth trusting: it samples the same
    /// channels the emitter puts in the document. If these ever diverge, a
    /// preview could look right while the export is wrong.
    func testEmitterChannelsMatchWhatTheDocumentContains() throws {
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
        var plan = try DeterministicPlanner(registry: try EffectRegistry.load(from: registryRoot)).plan(
            request: "Make this a living still.",
            selection: selection,
            target: Target.confirmed(x: 0.5, y: 0.5)
        )
        plan.effectID = .livingStill

        let emitter = LivingStillStandaloneEmitter()
        let channels = try emitter.channels(plan: plan, media: [.primary: asset])
        let document = try emitter.emitDocument(
            plan: plan,
            media: [.primary: asset],
            publishedMediaURLs: [.primary: URL(fileURLWithPath: "/tmp/out/still.png")],
            version: "1.14"
        )

        // Every keyframe value the sampler would read must appear in the
        // document verbatim.
        for keyframe in channels.transform.scale {
            XCTAssertTrue(
                document.contains("value=\"\(keyframe.value)\""),
                "scale keyframe \(keyframe.value) is previewed but not exported"
            )
        }
        for keyframe in channels.opacity.amount {
            XCTAssertTrue(
                document.contains("value=\"\(keyframe.value)\""),
                "opacity keyframe \(keyframe.value) is previewed but not exported"
            )
        }
        XCTAssertEqual(channels.origin, .still, "a still must preview against the 3600s origin")
        XCTAssertEqual(channels.frameHeight, 1080)
    }
}
