import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class ParameterTruthRegressionTests: XCTestCase {
    private func root() -> URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func registry() throws -> EffectRegistry { try EffectRegistry.load(from: root().appendingPathComponent("registry/effects")) }
    private func asset(kind: LocalMediaKind = .still, duration: Double? = nil) -> LocalMediaAsset {
        LocalMediaAsset(itemID: "a", url: URL(fileURLWithPath: "/tmp/a.png"), kind: kind, dimensions: .init(width: 1920, height: 1080), durationSeconds: duration, frameRate: 30, hasAudio: false, canonicalPath: "/tmp/a.png", sha256: String(repeating: "a", count: 64))
    }
    private func plan(_ id: EffectID, asset: LocalMediaAsset, target: Target? = nil) throws -> EffectPlan {
        let definition = try registry().definition(for: id)
        let token = SelectionToken(selectionType: .singleClip, clipIDs: ["a"], sourceIdentities: [asset.sourceIdentity], revision: "r")
        return EffectPlan(originalRequest: "test", confidence: 1, effectID: id, selectionToken: token, normalizedPoint: target,
            parameters: Dictionary(uniqueKeysWithValues: definition.parameters.compactMap { parameter in parameter.defaultValue.map { (parameter.name, $0) } }), representation: definition.representation, editableProperties: definition.editableProperties, generatedAssets: definition.generatedAssets, previewStrategy: definition.preview, verification: definition.verification, fallback: definition.fallback, preconditionRevision: "r")
    }

    func testLivingStillChannelsAndXMLFollowPlanValues() throws {
        let media = asset(); var plan = try plan(.livingStill, asset: media)
        plan.parameters["durationSeconds"] = .number(5)
        plan.parameters["pushInScaleStart"] = .number(1.2); plan.parameters["pushInScaleEnd"] = .number(1.5)
        plan.parameters["panX"] = .number(0.1); plan.parameters["panY"] = .number(0.2)
        plan.parameters["fadeDurationSeconds"] = .number(1); plan.parameters["opacityStart"] = .number(0.8); plan.parameters["opacityEnd"] = .number(0.2)
        try PlanValidator(registry: registry()).validate(plan)
        let emitter = LivingStillStandaloneEmitter(); let channels = try emitter.channels(plan: plan, media: [.primary: media])
        XCTAssertEqual(channels.durationSeconds, 5); XCTAssertEqual(channels.transform.scale.last?.value, "1.5 1.5")
        XCTAssertEqual(channels.transform.positionY.last?.value, "-20") // 0.2 height fraction, sign-flipped
        XCTAssertEqual(channels.opacity.amount.first?.value, "0.8"); XCTAssertEqual(channels.opacity.amount.last?.value, "0.2")
        let xml = try emitter.emitDocument(plan: plan, media: [.primary: media], publishedMediaURLs: [.primary: media.url], version: "1.14")
        XCTAssertTrue(xml.contains("duration=\"5s\"")); XCTAssertTrue(xml.contains("value=\"-20\"")); XCTAssertTrue(xml.contains("value=\"1.5 1.5\""))
        plan.parameters["pushInScaleEnd"] = .number(1); XCTAssertThrowsError(try PlanValidator(registry: registry()).validate(plan))
    }

    func testTargetedOriginsDirectionAndMovieOverflow() throws {
        let still = asset(); var plan = try plan(.targetedRotateZoom, asset: still, target: .confirmed(x: 0.2, y: 0.8))
        plan.parameters["durationSeconds"] = .number(5); plan.parameters["scaleEnd"] = .number(1.7)
        plan.parameters["rotationStartDegrees"] = .number(-10); plan.parameters["rotationEndDegrees"] = .number(20); plan.parameters["direction"] = .string("counterclockwise")
        try PlanValidator(registry: registry()).validate(plan)
        let channels = try TargetedRotateZoomStandaloneEmitter().channels(plan: plan, media: [.primary: still])
        XCTAssertEqual(channels.origin, .still); XCTAssertEqual(channels.transform.rotation.last?.value, "20")
        XCTAssertEqual(channels.transform.scale.last?.value, "1.7 1.7")
        XCTAssertEqual(try XCTUnwrap(channels.transform.rotation.last).time.seconds, 3600 + 149.0 / 30.0, accuracy: 0.00001)
        plan.parameters["direction"] = .string("clockwise"); XCTAssertThrowsError(try PlanValidator(registry: registry()).validate(plan))
        var moviePlan = try self.plan(.targetedRotateZoom, asset: asset(kind: .movie, duration: 2), target: .confirmed(x: 0.5, y: 0.5)); moviePlan.parameters["durationSeconds"] = .number(3)
        XCTAssertThrowsError(try TargetedRotateZoomStandaloneEmitter().channels(plan: moviePlan, media: [.primary: asset(kind: .movie, duration: 2)]))
    }

    func testRevisionCatalogAndReadOnlyPolicies() throws {
        let media = asset(); let session = LocalMediaPlannerSession(registry: try registry())
        let result = try session.plan(request: "living still", primary: media, outgoing: nil, incoming: nil, target: nil)
        let service = LocalMediaPlanRevisionService(registry: try registry())
        let revised = try service.revise(result, patch: ["panY": .number(0.1)])
        XCTAssertNotEqual(revised.plan.operationID, result.plan.operationID); XCTAssertEqual(revised.baselineParameters, result.baselineParameters); XCTAssertEqual(result.plan.parameters["panY"]?.numberValue, 0)
        XCTAssertThrowsError(try service.revise(result, patch: ["colorEnrichment": .number(0.2)])); XCTAssertThrowsError(try service.revise(result, patch: ["panY": .string("bad")]))
        XCTAssertEqual(StandaloneEmitterCatalog().absenceReason(for: .oldTelevision), StandaloneFCPXMLExportBuilder.missingEmitterReason(for: .oldTelevision))
        XCTAssertNotNil(StandaloneEmitterCatalog().emitter(for: .livingStill))
    }
}
