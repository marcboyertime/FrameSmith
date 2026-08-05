import Foundation
import XCTest
@testable import FCPCommandConsoleCore

/// Pins the rotation, anchor, static-form, and connected-layer primitives to
/// Final Cut's own output.
///
/// Every expected string was read from the 2026-08-05 captures in
/// `exports/ground-truth/`: `rotation-ground-truth`,
/// `connected-layers-ground-truth`, `connected-layers-offset-disambiguation`,
/// and `position-sign-convention`. These are not formatting preferences — a
/// change that breaks one is a change that stops matching what Final Cut wrote.
final class RotationAndConnectedLayerTests: XCTestCase {
    private let rate = NativeFCPXMLFrameRate.thirty

    // MARK: - Timing origin

    /// The finding the living still work alone would have got wrong: a movie
    /// clip's keyframes start at 0s, not at the stills' one-hour origin.
    func testMovieKeyframesStartAtZeroAndStillsAtOneHour() {
        XCTAssertEqual(NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 0, rate: rate).attributeValue, "0s")
        XCTAssertEqual(NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 60, rate: rate).attributeValue, "2s")
        XCTAssertEqual(NativeFCPXMLTimingOrigin.still.keyframeTime(frame: 0, rate: rate).attributeValue, "3600s")
        XCTAssertEqual(NativeFCPXMLTimingOrigin.still.keyframeTime(frame: 119, rate: rate).attributeValue, "2594856000/720000s")
    }

    // MARK: - Rotation

    /// Reproduces `rotation-ground-truth.fcpxmld` exactly.
    func testRotationAndAnchorMatchTheCapture() {
        let channel = NativeFCPXMLTransformChannel(
            rotation: [
                NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 0, rate: rate), value: "0"),
                NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 60, rate: rate), value: "45")
            ],
            anchor: (x: 18.5185, y: -9.25926)
        )
        let expected = """
        <adjust-transform anchor="18.5185 -9.25926">
          <param name="rotation">
            <keyframeAnimation>
              <keyframe time="0s" value="0"/>
              <keyframe time="2s" value="45"/>
            </keyframeAnimation>
          </param>
        </adjust-transform>
        """
        XCTAssertEqual(channel.node?.rendered(), expected)
    }

    /// Rotation carries no `key`, unlike position's keyed X/Y sub-params.
    func testRotationParamHasNoKeyAttribute() {
        let channel = NativeFCPXMLTransformChannel(
            rotation: [NativeFCPXMLKeyframe(time: .zero, value: "0")]
        )
        XCTAssertFalse(channel.node!.rendered().contains("key="))
    }

    func testAnchorPixelsConvertAgainstFrameHeightOnBothAxes() {
        XCTAssertEqual(NativeFCPXMLTransformUnits.position(fromPixels: 200, frameHeight: 1080), 18.5185, accuracy: 0.0001)
        XCTAssertEqual(NativeFCPXMLTransformUnits.position(fromPixels: -100, frameHeight: 1080), -9.25926, accuracy: 0.0001)
    }

    // MARK: - Static versus animated

    /// The rule confirmed on four properties across three captures.
    func testStaticPositionIsAPairedAttributeNotAParamTree() {
        let channel = NativeFCPXMLTransformChannel(staticPosition: (x: 0, y: 18.5185))
        XCTAssertEqual(channel.node?.rendered(), #"<adjust-transform position="0 18.5185"/>"#)
    }

    func testAnimatedPositionIsANestedKeyedParamTree() {
        let channel = NativeFCPXMLTransformChannel(
            positionX: [NativeFCPXMLKeyframe(time: .zero, value: "0")],
            positionY: [NativeFCPXMLKeyframe(time: .zero, value: "0")]
        )
        let rendered = channel.node!.rendered()
        XCTAssertTrue(rendered.contains(#"<param name="position">"#))
        XCTAssertTrue(rendered.contains(#"<param name="X" key="1">"#))
        XCTAssertTrue(rendered.contains(#"<param name="Y" key="2">"#))
        XCTAssertFalse(rendered.contains("position=\""), "animated position must not also be an attribute")
    }

    /// Both forms of the same property at once is a construction Final Cut
    /// never writes, so it must be unrepresentable rather than merely unused.
    func testStaticAndAnimatedPositionCannotCoexist() {
        // Verified by the initializer precondition; asserting the guard's
        // condition directly keeps the intent recorded without trapping.
        let animated = NativeFCPXMLTransformChannel(positionX: [NativeFCPXMLKeyframe(time: .zero, value: "0")])
        XCTAssertNil(animated.staticPosition)
        let statik = NativeFCPXMLTransformChannel(staticPosition: (x: 1, y: 2))
        XCTAssertTrue(statik.positionX.isEmpty && statik.positionY.isEmpty)
    }

    /// Final Cut's +Y is up; normalized image coordinates are +Y down.
    func testPositionYFlipsSignAgainstNormalizedImageCoordinates() {
        // A plan asking to move the framing DOWN by 200px on a 1080 frame.
        let value = NativeFCPXMLTransformUnits.positionY(fromHeightFraction: 200.0 / 1080.0, height: 1080)
        XCTAssertEqual(value, -18.5185, accuracy: 0.0001)
    }

    func testEmptyChannelEmitsNothing() {
        XCTAssertNil(NativeFCPXMLTransformChannel().node)
        XCTAssertNil(NativeFCPXMLOpacityChannel().node)
    }

    // MARK: - Blend

    /// Reproduces the `adjust-blend` from `connected-layers-ground-truth`.
    func testStaticBlendMatchesTheCapture() {
        let blend = NativeFCPXMLOpacityChannel.composite(opacity: 0.5, mode: .overlay)
        XCTAssertEqual(blend.node?.rendered(), #"<adjust-blend amount="0.5" mode="14 (Overlay)"/>"#)
    }

    func testOverlayIsTheOnlyNamedBlendMode() {
        XCTAssertEqual(NativeFCPXMLBlendMode.overlay.attributeValue, "14 (Overlay)")
    }

    func testAnimatedBlendStillEmitsAParam() {
        let blend = NativeFCPXMLOpacityChannel.fade(fadeStartFrame: 108, endFrame: 119, rate: rate)
        let rendered = blend.node!.rendered()
        XCTAssertTrue(rendered.contains(#"<param name="amount">"#))
        XCTAssertFalse(rendered.contains("amount=\""), "animated amount must not also be an attribute")
    }

    // MARK: - Connected layer

    /// Reproduces the connected `<video>` from `connected-layers-ground-truth`
    /// exactly, attributes and order included.
    func testConnectedLayerMatchesTheCapture() {
        let layer = NativeFCPXMLConnectedLayer(
            ref: "r3",
            lane: 1,
            offsetWithinParent: .seconds(2),
            name: "living-still",
            start: NativeFCPXMLTime(numerator: 10808700, timescale: 3000),
            duration: .seconds(3),
            blend: .composite(opacity: 0.5, mode: .overlay)
        )
        let expected = """
        <video ref="r3" lane="1" offset="2s" name="living-still" start="10808700/3000s" duration="3s">
          <adjust-blend amount="0.5" mode="14 (Overlay)"/>
        </video>
        """
        XCTAssertEqual(layer.node.rendered(), expected)
    }

    /// The disambiguation capture: an overlay at timeline 10s on a parent
    /// starting at 8s is written `offset="2s"`.
    ///
    /// Timeline-relative offsets are valid FCPXML that import silently and
    /// misplace every overlay on a non-first clip, so this is the single most
    /// important assertion in the file.
    func testOffsetIsParentRelativeNotTimelineRelative() {
        let layer = NativeFCPXMLConnectedLayer.atTimelineTime(
            ref: "r3",
            timelineOffset: .seconds(10),
            parentStart: .seconds(8),
            name: "living-still",
            start: NativeFCPXMLStillTiming.sourceStart,
            duration: .seconds(3)
        )
        XCTAssertEqual(layer.offsetWithinParent.attributeValue, "2s")
        XCTAssertTrue(layer.node.rendered().contains(#"offset="2s""#))
        XCTAssertFalse(layer.node.rendered().contains(#"offset="10s""#))
    }

    /// An overlay on the first clip is the degenerate case where both readings
    /// agree — which is exactly why the first capture could not settle it.
    func testOffsetOnFirstClipIsUnchanged() {
        let layer = NativeFCPXMLConnectedLayer.atTimelineTime(
            ref: "r3",
            timelineOffset: .seconds(2),
            parentStart: .zero,
            name: "living-still",
            start: NativeFCPXMLStillTiming.sourceStart,
            duration: .seconds(3)
        )
        XCTAssertEqual(layer.offsetWithinParent.attributeValue, "2s")
    }

    // MARK: - Probe emission

    private func probeXML(_ kind: NativeEffectProbeKind) throws -> String {
        let builder = NativeEffectProbeBuilder(
            kind: kind,
            fixtureRoot: URL(fileURLWithPath: "/tmp/fixtures"),
            exportRoot: URL(fileURLWithPath: "/tmp/probes")
        )
        return try builder.makeFCPXML(media: Dictionary(uniqueKeysWithValues: kind.fixtures.map {
            ($0, URL(fileURLWithPath: "/tmp/probes/Media/\($0)"))
        }))
    }

    /// The compensation is verified against a hand-computed value, not against
    /// whatever the code happens to produce.
    ///
    /// Source (0.7, 0.35), centre (0.5, 0.5), scale 1.5, rotation 12°. The
    /// target is right of and above centre, so the framing must move left and
    /// down — both emitted values negative.
    func testTargetedRotateZoomEmitsTheHandComputedCompensation() throws {
        let xml = try probeXML(.targetedRotateZoom)
        XCTAssertTrue(xml.contains(#"<keyframe time="4s" value="-60.48434"/>"#), "X compensation")
        XCTAssertTrue(xml.contains(#"<keyframe time="4s" value="-15.77097"/>"#), "Y compensation, sign flipped")
        XCTAssertTrue(xml.contains(#"<keyframe time="4s" value="1.5 1.5"/>"#), "scale")
        XCTAssertTrue(xml.contains(#"<keyframe time="4s" value="12"/>"#), "rotation in degrees")
    }

    /// A movie probe must not carry the stills' one-hour origin.
    func testTargetedRotateZoomUsesMovieKeyframeOrigin() throws {
        let xml = try probeXML(.targetedRotateZoom)
        XCTAssertTrue(xml.contains(#"<keyframe time="0s" value="0"/>"#))
        XCTAssertFalse(xml.contains("3600s"), "a movie clip must not use the still source origin")
    }

    /// The old television probe's only unobserved construction is the connected
    /// layer; everything else has already returned intact from an earlier pass.
    func testOldTelevisionEmitsTheConnectedLayerInDTDOrder() throws {
        let xml = try probeXML(.oldTelevision)
        let blendAt = xml.range(of: "<adjust-blend>")!.lowerBound
        let videoAt = xml.range(of: "<video ref=")!.lowerBound
        let filterAt = xml.range(of: "<filter-video ")!.lowerBound
        XCTAssertTrue(blendAt < videoAt, "intrinsics precede connected clips")
        XCTAssertTrue(videoAt < filterAt, "connected clips precede filters — the DTD rejects the other order")
        XCTAssertTrue(xml.contains(#"<video ref="r3" lane="1" offset="1s""#))
        XCTAssertTrue(xml.contains(#"<adjust-blend amount="0.5" mode="14 (Overlay)"/>"#))
    }

    /// The overlay is a still, so it keeps the one-hour origin even though the
    /// spine clip it hangs off is a movie.
    func testOldTelevisionOverlayKeepsTheStillOrigin() throws {
        let xml = try probeXML(.oldTelevision)
        XCTAssertTrue(xml.contains(#"start="3600s""#), "the connected still keeps its source origin")
    }

    func testProbeRequiredContractsMatchTheGate() {
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.requiredContracts(for: NativeEffectProbeKind.oldTelevision.effectID),
            [.assetAdmission, .opacityKeyframes, .nativeColorAdjustment, .connectedOverlayLayers]
        )
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.requiredContracts(for: NativeEffectProbeKind.targetedRotateZoom.effectID),
            [.assetAdmission, .transformKeyframes]
        )
    }

    /// Spent evidence must stay unwritable, the same rail the living still
    /// builder carries for ground truth.
    func testProbeBuilderRefusesToWriteIntoEvidenceDirectories() {
        for forbidden in ["ground-truth", "roundtrip-spikes", "living-still-probes"] {
            let builder = NativeEffectProbeBuilder(
                kind: .oldTelevision,
                fixtureRoot: URL(fileURLWithPath: "/tmp/fixtures"),
                exportRoot: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Movies/FCPCommandConsole/exports/\(forbidden)")
            )
            XCTAssertThrowsError(try builder.validateExportRoot(builder.exportRoot), forbidden)
        }
    }

    func testConnectedLayerCarriesTransformAndExtraChildrenInOrder() {
        let layer = NativeFCPXMLConnectedLayer(
            ref: "r3",
            offsetWithinParent: .zero,
            name: "overlay",
            start: NativeFCPXMLStillTiming.sourceStart,
            duration: .seconds(1),
            transform: NativeFCPXMLTransformChannel(staticPosition: (x: 0, y: 0)),
            blend: .composite(opacity: 1, mode: .overlay),
            extraChildren: [NativeFCPXMLNode("filter-video", attributes: [("ref", "r9"), ("name", "Test")])]
        )
        let rendered = layer.node.rendered()
        let transformAt = rendered.range(of: "adjust-transform")!.lowerBound
        let blendAt = rendered.range(of: "adjust-blend")!.lowerBound
        let filterAt = rendered.range(of: "filter-video")!.lowerBound
        XCTAssertTrue(transformAt < blendAt, "transform precedes blend, as captured")
        XCTAssertTrue(blendAt < filterAt, "extra children follow the intrinsic channels")
    }
}
