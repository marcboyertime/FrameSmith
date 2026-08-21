import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class ParameterTruthRegressionTests: XCTestCase {
    private func root() -> URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func registry() throws -> EffectRegistry { try EffectRegistry.load(from: root().appendingPathComponent("registry/effects")) }
    private func asset(kind: LocalMediaKind = .still, duration: Double? = nil, id: String = "a") -> LocalMediaAsset {
        LocalMediaAsset(itemID: id, url: URL(fileURLWithPath: "/tmp/\(id).png"), kind: kind, dimensions: .init(width: 1920, height: 1080), durationSeconds: duration, frameRate: 30, hasAudio: false, canonicalPath: "/tmp/\(id).png", sha256: String(repeating: id, count: 64))
    }
    private func plan(_ id: EffectID, asset: LocalMediaAsset, target: Target? = nil) throws -> EffectPlan {
        let definition = try registry().definition(for: id)
        let token = SelectionToken(selectionType: .singleClip, clipIDs: ["a"], sourceIdentities: [asset.sourceIdentity], revision: "r")
        return EffectPlan(originalRequest: "test", confidence: 1, effectID: id, selectionToken: token, normalizedPoint: target,
            parameters: Dictionary(uniqueKeysWithValues: definition.parameters.compactMap { parameter in parameter.defaultValue.map { (parameter.name, $0) } }), representation: definition.representation, editableProperties: definition.editableProperties, generatedAssets: definition.generatedAssets, previewStrategy: definition.preview, verification: definition.verification, fallback: definition.fallback, preconditionRevision: "r")
    }

    func testLivingStillParametersBindThePreparedRenderWhileScalarChannelsRemainNeutral() throws {
        let media = asset(); let baseline = try plan(.livingStill, asset: media); let defaultChannels = try LivingStillStandaloneEmitter().channels(plan: baseline, media: [.primary: media]); var plan = baseline
        plan.parameters["durationSeconds"] = .number(5)
        plan.parameters["motionStrength"] = .number(0.7); plan.parameters["pushIn"] = .number(0.08)
        plan.parameters["panX"] = .number(0.03); plan.parameters["panY"] = .number(0.02)
        plan.parameters["depthSmoothing"] = .number(0.65)
        try PlanValidator(registry: registry()).validate(plan)
        let emitter = LivingStillStandaloneEmitter(); let channels = try emitter.channels(plan: plan, media: [.primary: media])
        XCTAssertNotEqual(channels.durationSeconds, defaultChannels.durationSeconds); XCTAssertEqual(channels.durationSeconds, 5)
        XCTAssertTrue(channels.transform.isEmpty); XCTAssertTrue(channels.opacity.isEmpty)
        XCTAssertNil(channels.saturation); XCTAssertNil(channels.overlay); XCTAssertEqual(channels.origin, .still)
        XCTAssertNotEqual(
            try RenderedConstructionIdentity.digest(plan: baseline, media: [.primary: media]),
            try RenderedConstructionIdentity.digest(plan: plan, media: [.primary: media])
        )
        XCTAssertThrowsError(try emitter.emitDocument(plan: plan, media: [.primary: media], publishedMediaURLs: [.primary: media.url], version: "1.14")) { error in
            guard case StandaloneExportError.invalidRecipe(let reason) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(reason.contains("checksum-bound prepared depth render"), reason)
        }
        plan.parameters["pushInScaleEnd"] = .number(1); XCTAssertThrowsError(try PlanValidator(registry: registry()).validate(plan))
        plan = baseline; plan.parameters["pushIn"] = .number(0.2); XCTAssertThrowsError(try PlanValidator(registry: registry()).validate(plan))
        plan = baseline; plan.parameters["modelID"] = .string("unpinned-model"); XCTAssertThrowsError(try PlanValidator(registry: registry()).validate(plan))
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
        let other = try self.plan(.targetedRotateZoom, asset: still, target: .confirmed(x: 0.8, y: 0.2))
        let otherChannels = try TargetedRotateZoomStandaloneEmitter().channels(plan: other, media: [.primary: still])
        XCTAssertNotEqual(channels.transform.positionX.last?.value, otherChannels.transform.positionX.last?.value)
        XCTAssertNotEqual(channels.transform.positionY.last?.value, otherChannels.transform.positionY.last?.value)
        let movie = asset(kind: .movie, duration: 10); let movieChannels = try TargetedRotateZoomStandaloneEmitter().channels(plan: try self.plan(.targetedRotateZoom, asset: movie, target: .confirmed(x: 0.5, y: 0.5)), media: [.primary: movie])
        XCTAssertEqual(movieChannels.origin, .movieFromZero); XCTAssertEqual(try XCTUnwrap(movieChannels.transform.rotation.last).time.seconds, 119.0 / 30.0, accuracy: 0.00001)
    }

    func testRevisionCatalogAndReadOnlyPolicies() throws {
        let media = asset(); let session = LocalMediaPlannerSession(registry: try registry())
        let result = try session.plan(request: "living still", primary: media, outgoing: nil, incoming: nil, target: nil)
        let service = LocalMediaPlanRevisionService(registry: try registry(), schemaValidator: try PlanSchemaValidator(schemaURL: root().appendingPathComponent("schemas/effect-plan.schema.json")))
        let revised = try service.revise(result, patch: ["panY": .number(0.03)])
        XCTAssertNotEqual(revised.plan.operationID, result.plan.operationID); XCTAssertEqual(revised.baselineParameters, result.baselineParameters); XCTAssertEqual(result.plan.parameters["panY"]?.numberValue, -0.006)
        XCTAssertThrowsError(try service.revise(result, patch: ["colorEnrichment": .number(0.2)])); XCTAssertThrowsError(try service.revise(result, patch: ["panY": .string("bad")]))
        // All four effects gained production emitters on 2026-08-07, so the
        // catalog reports no absence for any of them.
        for effect in EffectID.allCases {
            XCTAssertNotNil(StandaloneEmitterCatalog().emitter(for: effect), effect.rawValue)
            XCTAssertNil(StandaloneEmitterCatalog().absenceReason(for: effect), effect.rawValue)
        }
        XCTAssertThrowsError(try service.revise(result, patch: ["preserveOriginal": .boolean(false)])); XCTAssertThrowsError(try service.revise(result, patch: ["unknown": .number(1)]))
        XCTAssertThrowsError(try LocalMediaPlanRevisionService(registry: try registry()).revise(result, patch: ["panY": .number(0.03)]))
        let reset = try service.reset(revised, parameter: "panY"); XCTAssertEqual(reset.plan.parameters["panY"], result.baselineParameters["panY"])
    }

    func testInitialAndRevisionMovieOverflowRefuseWithoutChangingOldResult() throws {
        let movie = asset(kind: .movie, duration: 5); let session = LocalMediaPlannerSession(registry: try registry())
        XCTAssertThrowsError(try session.plan(request: "targeted rotate zoom for 6 seconds", primary: movie, outgoing: nil, incoming: nil, target: .confirmed(x: 0.5, y: 0.5)))
        let valid = try session.plan(request: "targeted rotate zoom", primary: movie, outgoing: nil, incoming: nil, target: .confirmed(x: 0.5, y: 0.5))
        let service = LocalMediaPlanRevisionService(registry: try registry(), schemaValidator: try PlanSchemaValidator(schemaURL: root().appendingPathComponent("schemas/effect-plan.schema.json")))
        XCTAssertThrowsError(try service.revise(valid, patch: ["durationSeconds": .number(6)])); XCTAssertEqual(valid.plan.parameters["durationSeconds"]?.numberValue, 4)
    }

    func testUnavailablePlanningUsesCatalogReason() throws {
        let session = LocalMediaPlannerSession(registry: try registry()); let first = asset(); let second = asset(id: "b")
        let dissolve = try session.plan(request: "natural dissolve", primary: nil, outgoing: first, incoming: second, target: nil)
        let television = try session.plan(request: "old television", primary: first, outgoing: nil, incoming: nil, target: nil)
        // Both now have emitters, so any refusal here comes from the capability
        // gate rather than an absent emitter. The reason must still be stated
        // and must not be the old emitter-absence text.
        for result in [dissolve, television] {
            if !result.standaloneExportDecision.allowed {
                XCTAssertFalse(result.standaloneExportDecision.reason.isEmpty, result.plan.effectID.rawValue)
                XCTAssertNil(StandaloneEmitterCatalog().absenceReason(for: result.plan.effectID))
            }
        }
    }

    func testTwoInputMediaMustMatchTokenIdentityOrder() throws {
        let outgoing = asset(id: "a"); let incoming = asset(id: "b")
        let session = LocalMediaPlannerSession(registry: try registry())
        let result = try session.plan(request: "natural dissolve", primary: nil, outgoing: outgoing, incoming: incoming, target: nil)
        let execution = ValidatedPlanExecution(registry: try registry())
        try execution.validate(plan: result.plan, media: [.outgoing: outgoing, .incoming: incoming])
        XCTAssertThrowsError(try execution.validate(plan: result.plan, media: [.outgoing: incoming, .incoming: outgoing]))

        var missingIdentity = result.plan
        missingIdentity.selectionToken.sourceIdentities.removeLast()
        XCTAssertThrowsError(try execution.validate(plan: missingIdentity, media: [.outgoing: outgoing, .incoming: incoming]))
    }

    func testResetAllCreativePreservesBaselineAndIdentity() throws {
        let media = asset(); let session = LocalMediaPlannerSession(registry: try registry())
        let original = try session.plan(request: "living still", primary: media, outgoing: nil, incoming: nil, target: nil)
        let service = LocalMediaPlanRevisionService(registry: try registry(), schemaValidator: try PlanSchemaValidator(schemaURL: root().appendingPathComponent("schemas/effect-plan.schema.json")))
        let edited = try service.revise(original, patch: ["durationSeconds": .number(6), "panX": .number(0.02)])
        let reset = try service.resetAllCreative(edited)
        XCTAssertNotEqual(reset.plan.operationID, edited.plan.operationID); XCTAssertEqual(reset.plan.originalRequest, original.plan.originalRequest); XCTAssertEqual(reset.selection, original.selection); XCTAssertEqual(reset.inputs, original.inputs); XCTAssertEqual(reset.baselineParameters, original.baselineParameters)
        for definition in try registry().definition(for: .livingStill).parameters where (definition.presentation ?? .failClosed).exposure.isEditable { XCTAssertEqual(reset.plan.parameters[definition.name], original.baselineParameters[definition.name]) }
        XCTAssertEqual(reset.admission, .current(reset.plan))
    }

    func testMetadataDriftIsRejectedBeforeExportConstruction() throws {
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("framesmith-metadata-drift-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let input = scratch.appendingPathComponent("still.png")
        try Data(repeating: 0x42, count: 512).write(to: input)
        let media = LocalMediaAsset(
            itemID: "still", url: input, kind: .still,
            dimensions: .init(width: 1920, height: 1080), durationSeconds: nil,
            frameRate: nil, hasAudio: false, canonicalPath: input.path,
            sha256: try ContentHasher.sha256File(input))
        let plan = try self.plan(.livingStill, asset: media)

        // Simulate a registry edit that no longer matches the admitted plan.
        var definitions = Array((try registry()).definitions.values)
        let livingStill = try XCTUnwrap(definitions.firstIndex { $0.identifier == .livingStill })
        definitions[livingStill].generatedAssets = []
        let driftedRegistry = try EffectRegistry(definitions: definitions)
        XCTAssertThrowsError(try ValidatedPlanExecution(registry: driftedRegistry).validate(plan: plan, media: [.primary: media]))

        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [media]))
        let installed = FinalCutVersionIdentity(shortVersion: "12.3", build: "450152")
        let gate = CapabilityGate(manualSemanticsEvidence: FinalCutSemanticProfileStore.finalCut12_3_450152.evidence(forInstalled: installed))
        let outputRoot = scratch.appendingPathComponent("out", isDirectory: true)
        let builder = StandaloneFCPXMLExportBuilder(gate: gate, outputRoot: outputRoot, registry: driftedRegistry)
        XCTAssertThrowsError(try builder.export(plan: plan, media: [.primary: media], mediaEvidence: evidence, installedFinalCut: installed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent(plan.operationID.uuidString).path))
    }
}
