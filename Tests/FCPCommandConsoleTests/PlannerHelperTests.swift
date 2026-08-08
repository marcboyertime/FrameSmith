import CoreFoundation
import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class PlannerHelperTests: XCTestCase {
    private let zeroHash = String(repeating: "0", count: 64)

    private func resources() throws -> PlannerHelperResources {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/FCPCommandConsolePlannerHelper/Resources")
        return try PlannerHelperResources(rootURL: root)
    }

    private func selection(_ type: SelectionType, clips: [String]) -> SelectionToken {
        let identities = clips.map { SourceIdentity(itemID: $0, canonicalPath: "/tmp/\($0)", sha256: zeroHash) }
        if type == .twoAdjacentClips {
            return SelectionToken(
                tokenID: "token-\(clips.joined(separator: "-"))", selectionType: type,
                timelineID: "timeline", clipIDs: clips, sourceIdentities: identities,
                revision: "revision-1", startFrame: 100, endFrame: 112,
                sourceDurationFrames: 1000, sourceRangeStartFrame: 0,
                sourceRangeEndFrame: 500, leftSourceDurationFrames: 1000,
                rightSourceDurationFrames: 1000, leftSourceRangeStartFrame: 0,
                leftSourceRangeEndFrame: 500, rightSourceRangeStartFrame: 0,
                rightSourceRangeEndFrame: 500, leftClipEndFrame: 100,
                rightClipStartFrame: 100, boundaryFrame: 100, frameRate: 24,
                handleBeforeFrames: 12, handleAfterFrames: 12, isSpine: true, adjacent: true
            )
        }
        return SelectionToken(
            tokenID: "token-\(clips.joined(separator: "-"))", selectionType: type,
            timelineID: "timeline", clipIDs: clips, sourceIdentities: identities,
            revision: "revision-1", startFrame: 0, endFrame: 24,
            sourceDurationFrames: 240, handleBeforeFrames: 0,
            handleAfterFrames: 0, isSpine: true, adjacent: true
        )
    }

    private func request(_ text: String, selection: SelectionToken, target: Target? = nil, operation: UUID = UUID()) -> Data {
        let envelope = PlannerHelperRequestEnvelope(
            operationID: operation,
            request: PlannerHelperRequestText(originalText: text),
            selection: PlannerHelperSelection(core: selection),
            target: target.map { PlannerHelperTarget(normalizedX: $0.x, normalizedY: $0.y) }
        )
        let encoder = JSONEncoder()
        return try! encoder.encode(envelope)
    }

    func testAllFourExactRequestsProduceValidatedLocalPlans() throws {
        let engine = PlannerHelperEngine(resources: try resources())
        let cases: [(String, SelectionToken, Target?, EffectID)] = [
            ("targeted rotate and zoom clockwise for 2 seconds by 12 degrees", selection(.singleClip, clips: ["clip-a"]), Target.confirmed(x: 0.5, y: 0.5), .targetedRotateZoom),
            ("Make this look like old black-and-white television footage with static, grain, scanlines, and subtle image instability.", selection(.singleClip, clips: ["clip-a"]), nil, .oldTelevision),
            ("Make this clip dissolve naturally into the next clip.", selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"]), nil, .naturalDissolve),
            ("Make this still image feel gently alive for four seconds, then fade quickly to black.", selection(.singleClip, clips: ["clip-a"]), nil, .livingStill)
        ]
        for (text, token, target, id) in cases {
            let response = engine.handle(data: request(text, selection: token, target: target))
            XCTAssertEqual(response.status, .ok, text)
            XCTAssertEqual(response.plan?.effectID, id, text)
            XCTAssertEqual(response.plan?.schemaVersion, "2.0", text)
            XCTAssertEqual(response.plan?.cost, CostEstimate(paid: false, usd: 0, provider: "local"), text)
            XCTAssertNoThrow(try PlanValidator(registry: try resources().registry).validate(response.plan!), text)
        }
    }

    func testClosedWireAndOperationIdentity() throws {
        let operation = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let token = selection(.singleClip, clips: ["clip-a"])
        let response = PlannerHelperEngine(resources: try resources()).handle(data: request("old tv", selection: token, operation: operation))
        let wire = try PlannerHelperWireCodec.encode(response)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: wire) as? [String: Any])
        let plan = try XCTUnwrap(object["plan"] as? [String: Any])
        let selection = try XCTUnwrap(plan["selection_token"] as? [String: Any])
        XCTAssertNotNil(selection["clip_ids"])
        XCTAssertNil(selection["clip_i_ds"])
        XCTAssertEqual(plan["operation_id"] as? String, operation.uuidString)
        XCTAssertEqual(plan["schema_version"] as? String, "2.0")
    }

    func testWirePreservesNumericZeroAndOneWithoutCoercingBooleans() throws {
        let token = selection(.singleClip, clips: ["clip-a"])
        let response = PlannerHelperEngine(resources: try resources()).handle(
            data: request("old tv", selection: token)
        )
        let wire = try PlannerHelperWireCodec.encode(response)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: wire) as? [String: Any])
        let plan = try XCTUnwrap(object["plan"] as? [String: Any])
        let cost = try XCTUnwrap(plan["cost"] as? [String: Any])
        let parameters = try XCTUnwrap(plan["parameters"] as? [String: Any])
        let selection = try XCTUnwrap(plan["selection_token"] as? [String: Any])
        let editable = try XCTUnwrap(plan["editable_properties"] as? [[String: Any]])

        let zeroCost = try XCTUnwrap(cost["usd"] as? NSNumber)
        let overlayStartOne = try XCTUnwrap(parameters["overlayStartSeconds"] as? NSNumber)
        let startFrameZero = try XCTUnwrap(selection["start_frame"] as? NSNumber)
        let paid = try XCTUnwrap(cost["paid"] as? NSNumber)

        XCTAssertTrue(editable.isEmpty)
        for number in [zeroCost, overlayStartOne, startFrameZero] {
            XCTAssertNotEqual(CFGetTypeID(number), CFBooleanGetTypeID())
        }
        XCTAssertEqual(zeroCost.doubleValue, 0)
        XCTAssertEqual(overlayStartOne.doubleValue, 1)
        XCTAssertEqual(startFrameZero.intValue, 0)
        XCTAssertEqual(CFGetTypeID(paid), CFBooleanGetTypeID())
        XCTAssertFalse(paid.boolValue)
    }

    func testMalformedOversizeMultipleAndUnknownFieldsFailClosed() throws {
        let engine = PlannerHelperEngine(resources: try resources())
        XCTAssertEqual(engine.handle(data: Data("not-json".utf8)).error?.code, .malformedJSON)
        XCTAssertEqual(engine.handle(data: Data("{}{}".utf8)).error?.code, .multipleJSONValues)
        XCTAssertEqual(engine.handle(data: Data(repeating: 0x20, count: PlannerHelperLimits.maxInputBytes + 1)).error?.code, .inputTooLarge)
        let valid = String(decoding: request("old tv", selection: selection(.singleClip, clips: ["clip-a"])), as: UTF8.self)
        let injected = valid.dropLast() + ",\"shell\":\"echo secret\"}"
        XCTAssertEqual(engine.handle(data: Data(injected.utf8)).error?.code, .unknownField)
    }

    func testTargetSelectionTimingAndHandleRefusals() throws {
        let engine = PlannerHelperEngine(resources: try resources())
        let noTarget = engine.handle(data: request("targeted rotate and zoom", selection: selection(.singleClip, clips: ["clip-a"])))
        XCTAssertEqual(noTarget.error?.code, .targetRequired)

        var dissolve = selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"])
        dissolve.handleBeforeFrames = 0
        dissolve.handleAfterFrames = 0
        let insufficientHandles = engine.handle(data: request("cross dissolve", selection: dissolve))
        XCTAssertEqual(insufficientHandles.error?.code, .invalidSelection)

        var invalid = selection(.singleClip, clips: ["clip-a"])
        invalid.isSpine = false
        XCTAssertEqual(engine.handle(data: request("old tv", selection: invalid)).error?.code, .invalidSelection)
    }

    func testResourceMissingAndTamperAreRejected() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("planner-helper-resources-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: temp) }
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/FCPCommandConsolePlannerHelper/Resources")
        try fm.copyItem(at: source, to: temp)
        try fm.removeItem(at: temp.appendingPathComponent("schemas/effect-plan.schema.json"))
        XCTAssertThrowsError(try PlannerHelperResources(rootURL: temp)) { error in
            XCTAssertEqual(error as? PlannerHelperResourceError, .resourceMissing)
        }

        try fm.copyItem(at: source, to: temp.appendingPathComponent("restored"))
        let restored = temp.appendingPathComponent("restored")
        let schema = restored.appendingPathComponent("schemas/effect-plan.schema.json")
        try Data("{}".utf8).write(to: schema)
        XCTAssertThrowsError(try PlannerHelperResources(rootURL: restored)) { error in
            XCTAssertEqual(error as? PlannerHelperResourceError, .resourceTampered)
        }
    }
}
