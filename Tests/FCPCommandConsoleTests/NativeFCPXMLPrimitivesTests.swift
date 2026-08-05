import Foundation
import XCTest
@testable import FCPCommandConsoleCore

/// These tests pin the primitives to Final Cut's own output.
///
/// Every expected string here was read from
/// `exports/ground-truth/living-still-ground-truth.fcpxmld` on 2026-08-04.
/// They are not preferences about formatting — a change that makes one of them
/// fail is a change that stops matching what Final Cut wrote.
final class NativeFCPXMLPrimitivesTests: XCTestCase {

    // MARK: - Time

    func testWholeSecondsCollapseAndFractionsStayUnreduced() {
        XCTAssertEqual(NativeFCPXMLTime.seconds(4).attributeValue, "4s")
        XCTAssertEqual(NativeFCPXMLTime.zero.attributeValue, "0s")
        // Final Cut left this unreduced; reducing would parse but would not
        // reproduce the observed construction.
        XCTAssertEqual(NativeFCPXMLTime(numerator: 2594592000, timescale: 720000).attributeValue, "2594592000/720000s")
    }

    func testFrameDurationMatchesCapture() {
        XCTAssertEqual(NativeFCPXMLFrameRate.thirty.frameDuration().attributeValue, "100/3000s")
    }

    func testFourSecondDurationMatchesCapture() {
        XCTAssertEqual(NativeFCPXMLFrameRate.thirty.time(frames: 120).attributeValue, "4s")
    }

    /// The single most dangerous finding: keyframe times are absolute from a
    /// one-hour source start. A keyframe emitted at `0s` lands an hour early.
    func testKeyframeTimesAreAbsoluteFromTheHourSourceStart() {
        let rate = NativeFCPXMLFrameRate.thirty
        XCTAssertEqual(NativeFCPXMLStillTiming.keyframeTime(frame: 0, rate: rate).attributeValue, "3600s")
        XCTAssertEqual(NativeFCPXMLStillTiming.keyframeTime(frame: 108, rate: rate).attributeValue, "2594592000/720000s")
        XCTAssertEqual(NativeFCPXMLStillTiming.keyframeTime(frame: 119, rate: rate).attributeValue, "2594856000/720000s")
    }

    func testKeyframeTimesDecodeToTheExpectedSeconds() {
        let rate = NativeFCPXMLFrameRate.thirty
        XCTAssertEqual(NativeFCPXMLStillTiming.keyframeTime(frame: 108, rate: rate).seconds, 3603.6, accuracy: 0.000001)
        XCTAssertEqual(NativeFCPXMLStillTiming.keyframeTime(frame: 119, rate: rate).seconds, 3600 + 119.0 / 30.0, accuracy: 0.000001)
    }

    // MARK: - Number formatting

    func testNumberFormattingMatchesCapturedPrecision() {
        XCTAssertEqual(NativeFCPXMLNumber.string(0), "0")
        XCTAssertEqual(NativeFCPXMLNumber.string(1), "1")
        XCTAssertEqual(NativeFCPXMLNumber.string(1.08), "1.08")
        XCTAssertEqual(NativeFCPXMLNumber.string(3.5555555555555554), "3.55556")
        XCTAssertEqual(NativeFCPXMLNumber.pair(1, 1), "1 1")
        XCTAssertEqual(NativeFCPXMLNumber.pair(1.08, 1.08), "1.08 1.08")
    }

    // MARK: - Transform units

    /// The inspector reads `px`; the XML does not. 38.4 px on a 1080-high
    /// frame is `3.55556`. Emitting 38.4 would pan 10.8x too far and still
    /// import cleanly.
    func testPositionIsPercentOfFrameHeightNotPixels() {
        XCTAssertEqual(NativeFCPXMLTransformUnits.position(fromPixels: 38.4, frameHeight: 1080), 3.5555555555555554, accuracy: 1e-12)
        let fromFraction = NativeFCPXMLTransformUnits.position(fromWidthFraction: 0.02, width: 1920, height: 1080)
        XCTAssertEqual(NativeFCPXMLNumber.string(fromFraction), "3.55556")
    }

    func testPositionConversionUsesHeightForBothAxes() {
        // A square frame makes the width/height ratio 1, isolating the divisor.
        XCTAssertEqual(NativeFCPXMLTransformUnits.position(fromWidthFraction: 0.5, width: 1000, height: 1000), 50, accuracy: 1e-12)
    }

    // MARK: - Transform channel

    func testPositionNestsPerAxisWhileScaleStaysPaired() {
        let channel = NativeFCPXMLTransformChannel.pushInAndPan(
            startFrame: 0, endFrame: 119, rate: .thirty,
            panXFraction: 0.02, panYFraction: 0,
            scaleStart: 1, scaleEnd: 1.08,
            width: 1920, height: 1080
        )
        let xml = try! XCTUnwrap(channel.node).rendered()

        XCTAssertTrue(xml.contains("<param name=\"position\">"), xml)
        XCTAssertTrue(xml.contains("<param name=\"X\" key=\"1\">"), xml)
        XCTAssertTrue(xml.contains("<param name=\"Y\" key=\"2\">"), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"3600s\" value=\"0\"/>"), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"2594856000/720000s\" value=\"3.55556\"/>"), xml)

        // scale must NOT nest into sub-params
        XCTAssertTrue(xml.contains("<param name=\"scale\">"), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"3600s\" value=\"1 1\"/>"), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"2594856000/720000s\" value=\"1.08 1.08\"/>"), xml)
        XCTAssertFalse(xml.contains("<param name=\"scale\">\n      <param"), xml)
    }

    /// Final Cut emitted a held axis as one keyframe with `curve="linear"`,
    /// rather than omitting the axis.
    func testHeldAxisEmitsASingleLinearKeyframe() {
        let channel = NativeFCPXMLTransformChannel.pushInAndPan(
            startFrame: 0, endFrame: 119, rate: .thirty,
            panXFraction: 0.02, panYFraction: 0,
            scaleStart: 1, scaleEnd: 1.08,
            width: 1920, height: 1080
        )
        XCTAssertEqual(channel.positionY.count, 1)
        XCTAssertEqual(channel.positionY.first?.curve, "linear")
        XCTAssertNil(channel.positionX.first?.curve, "an animated axis carried no curve in the capture")
    }

    func testEmptyTransformEmitsNothing() {
        XCTAssertNil(NativeFCPXMLTransformChannel().node)
    }

    // MARK: - Opacity channel

    func testOpacityIsAdjustBlendAmountOnAZeroToOneScale() {
        let channel = NativeFCPXMLOpacityChannel.fade(fadeStartFrame: 108, endFrame: 119, rate: .thirty)
        let xml = try! XCTUnwrap(channel.node).rendered()
        XCTAssertTrue(xml.hasPrefix("<adjust-blend>"), xml)
        XCTAssertTrue(xml.contains("<param name=\"amount\">"), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"2594592000/720000s\" value=\"1\"/>"), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"2594856000/720000s\" value=\"0\"/>"), xml)
    }

    /// The composition carries three opacity keyframes; Final Cut holds a
    /// value flat before the first, so two is the observed form.
    func testFadeEmitsTwoKeyframesNotThree() {
        XCTAssertEqual(NativeFCPXMLOpacityChannel.fade(fadeStartFrame: 108, endFrame: 119, rate: .thirty).amount.count, 2)
    }

    func testEmptyOpacityEmitsNothing() {
        XCTAssertNil(NativeFCPXMLOpacityChannel().node)
    }

    // MARK: - Color adjustments

    func testColorEffectIdentityIsTheCapturedOne() {
        XCTAssertEqual(NativeFCPXMLColorAdjustments.effectUID, "FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0")
        XCTAssertEqual(NativeFCPXMLColorAdjustments.effectName, "Color Adjustments")
    }

    func testColorFilterCarriesEveryCapturedParameterAndOverridesOnlySaturation() {
        let node = NativeFCPXMLColorAdjustments.filterNode(ref: "r4", saturation: 25)
        let xml = node.rendered()
        XCTAssertTrue(xml.contains("<param name=\"Saturation\" key=\"16\" value=\"25\"/>"), xml)
        XCTAssertTrue(xml.contains("<param name=\"Exposure\" key=\"3\" value=\"0\"/>"), xml)
        XCTAssertTrue(xml.contains("<data key=\"effectConfig\">"), xml)
        XCTAssertTrue(xml.contains("<param name=\"Neutralization Data\" key=\"23\""), xml)
        XCTAssertEqual(NativeFCPXMLColorAdjustments.capturedParameters.count, 18)

        let changed = NativeFCPXMLColorAdjustments.filterNode(ref: "r4", saturation: 12).rendered()
        XCTAssertTrue(changed.contains("<param name=\"Saturation\" key=\"16\" value=\"12\"/>"), changed)
        XCTAssertTrue(changed.contains("<param name=\"Exposure\" key=\"3\" value=\"0\"/>"), "only Saturation may vary")
    }

    /// The `effectConfig` payload is a version stamp, not captured state.
    func testEffectConfigDecodesToThePluginVersionStamp() throws {
        let base64 = NativeFCPXMLColorAdjustments.Blobs.effectConfig
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(plist?["$archiver"] as? String, "NSKeyedArchiver")
        let objects = try XCTUnwrap(plist?["$objects"] as? [Any])
        XCTAssertTrue(objects.contains { ($0 as? String) == "pluginVersion" })
    }

    // MARK: - Node rendering

    func testAttributeAndTextEscaping() {
        let node = NativeFCPXMLNode("effect", attributes: [("name", "A & B \"quoted\" <x>")])
        XCTAssertTrue(node.rendered().contains("A &amp; B &quot;quoted&quot; &lt;x&gt;"))
        let data = NativeFCPXMLNode.text(name: "data", attributes: [("key", "k")], text: "a<b&c")
        XCTAssertEqual(data.rendered(), "<data key=\"k\">a&lt;b&amp;c</data>")
    }

    func testAmpersandIsEscapedFirstSoNothingIsDoubleEscaped() {
        XCTAssertEqual(NativeFCPXMLNode.escapeAttribute("&lt;"), "&amp;lt;")
    }
}
