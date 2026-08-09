import XCTest
@testable import FCPCommandConsoleCore

final class EditorialTreatmentWorkflowTests: XCTestCase {
    private func root() -> URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func asset(_ id: String = "still", digest: Character = "a") -> LocalMediaAsset {
        LocalMediaAsset(itemID: id, url: URL(fileURLWithPath: "/tmp/\(id).png"), kind: .still, dimensions: .init(width: 1920, height: 1080), durationSeconds: nil, frameRate: nil, hasAudio: false, canonicalPath: "/tmp/\(id).png", sha256: String(repeating: digest, count: 64))
    }
    private func registry() throws -> EffectRegistry { try EffectRegistry.load(from: root().appendingPathComponent("registry/effects")) }
    private func workflow() throws -> EditorialTreatmentWorkflow {
        let root = root(); let registry = try registry()
        let catalog = try EditorialKnowledgeCatalog.load(from: root.appendingPathComponent("registry/editorial-techniques"), knownSourceIDs: EditorialKnowledgeCatalog.sourceIDs(fromCSV: root.appendingPathComponent("docs/editorial-intelligence/sources.csv")))
        return EditorialTreatmentWorkflow(catalog: catalog, registry: registry, admittedCapabilities: Set(FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts.map(\.rawValue)), schemaValidator: try PlanSchemaValidator(schemaURL: root.appendingPathComponent("schemas/effect-plan.schema.json")), treatmentContractValidator: try TreatmentPlanContractValidator(schemaURL: root.appendingPathComponent("schemas/treatment-plan.schema.json")), capabilityGate: CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts)))
    }
    private func bases(_ media: LocalMediaAsset, frames: Int = 90) throws -> [EffectID: EffectPlan] {
        let session = LocalMediaPlannerSession(registry: try registry(), schemaValidator: try PlanSchemaValidator(schemaURL: root().appendingPathComponent("schemas/effect-plan.schema.json")), capabilityGate: CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts)))
        let plan = try session.plan(request: "Make this a living still for \(Double(frames) / 30.0) seconds.", primary: media, outgoing: nil, incoming: nil, target: nil)
        return [.livingStill: plan.plan]
    }

    func testExplicitDurationAndSingleStillScopeAreRequired() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        XCTAssertThrowsError(try workflow.generate(state: &state, command: "quiet", media: [.primary: still], target: nil, durationFrames: nil, basePlans: try bases(still))) { XCTAssertEqual($0 as? EditorialTreatmentWorkflowError, .durationRequired) }
        XCTAssertThrowsError(try workflow.generate(state: &state, command: "quiet", media: [.primary: still, .outgoing: asset("other", digest: "b")], target: nil, durationFrames: 90, basePlans: try bases(still))) { error in
            guard case .unsupportedScope = error as? EditorialTreatmentWorkflowError else { return XCTFail("wrong error \(error)") }
        }
    }

    func testGenerationOnlyPublishesAdmittedOptionsWithDirectorTiming() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        let admitted = try workflow.generate(state: &state, command: "quiet", media: [.primary: still], target: nil, durationFrames: 90, basePlans: try bases(still))
        XCTAssertFalse(admitted.isEmpty)
        XCTAssertEqual(state.options.count, admitted.count)
        XCTAssertEqual(state.lock?.clips.map(\.durationFrames), [90])
        XCTAssertTrue(state.lock?.authorizedDeltas.isEmpty == true)
        XCTAssertTrue(admitted.allSatisfy { $0.channels.durationSeconds == 3 })
        XCTAssertFalse(admitted.contains { $0.treatment.effectPlan.effectID == .oldTelevision })
        XCTAssertFalse(admitted.contains { $0.treatment.effectPlan.effectID == .targetedRotateZoom })
        XCTAssertTrue(admitted.allSatisfy { $0.channels.matches($0.channels.materializedChannels()) })
    }

    func testInputDriftClearsOptionsAppliedComparisonAndHistory() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        let admitted = try workflow.generate(state: &state, command: "quiet", media: [.primary: still], target: nil, durationFrames: 90, basePlans: try bases(still))
        let current = workflow.snapshot(command: "quiet", media: [.primary: still], target: nil, durationFrames: 90)
        _ = try workflow.use(admitted[0].treatment.optionID, state: &state, current: current, media: [.primary: still])
        try workflow.toggleComparison(admitted[0].treatment.optionID, state: &state)
        let drifted = workflow.snapshot(command: "changed", media: [.primary: still], target: nil, durationFrames: 90)
        XCTAssertNotNil(workflow.invalidateIfDrifted(&state, current: drifted))
        XCTAssertTrue(state.options.isEmpty); XCTAssertNil(state.applied); XCTAssertTrue(state.comparisonIDs.isEmpty); XCTAssertTrue(state.history.isEmpty)
    }

    func testUseAdoptsExactPlanAndMintsOneFreshOperationID() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        let option = try XCTUnwrap(try workflow.generate(state: &state, command: "quiet wording", media: [.primary: still], target: nil, durationFrames: 90, basePlans: try bases(still)).first)
        let current = workflow.snapshot(command: "quiet wording", media: [.primary: still], target: nil, durationFrames: 90)
        let applied = try workflow.use(option.treatment.optionID, state: &state, current: current, media: [.primary: still])
        XCTAssertNotEqual(applied.0.treatment.effectPlan.operationID, option.treatment.effectPlan.operationID)
        XCTAssertEqual(applied.1.plan.parameters, applied.0.treatment.effectPlan.parameters)
        XCTAssertEqual(applied.1.plan.originalRequest, option.treatment.effectPlan.originalRequest, "Use This must not default-replan")
    }

    func testInvalidRefineRetainsPriorArtifactAndComparisonHasHardLimit() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        let admitted = try workflow.generate(state: &state, command: "quiet", media: [.primary: still], target: nil, durationFrames: 90, basePlans: try bases(still))
        let current = workflow.snapshot(command: "quiet", media: [.primary: still], target: nil, durationFrames: 90)
        _ = try workflow.use(admitted[0].treatment.optionID, state: &state, current: current, media: [.primary: still])
        let before = state.applied
        XCTAssertThrowsError(try workflow.revise(state: &state, current: current, media: [.primary: still], patch: ["not-a-parameter": .number(2)]))
        XCTAssertEqual(state.applied, before)
        for index in 0..<3 { state.options["comparison-\(index)"] = admitted[0] }
        try workflow.toggleComparison("comparison-0", state: &state); try workflow.toggleComparison("comparison-1", state: &state); try workflow.toggleComparison("comparison-2", state: &state)
        XCTAssertThrowsError(try workflow.toggleComparison(admitted[0].treatment.optionID, state: &state)) { XCTAssertEqual($0 as? EditorialTreatmentWorkflowError, .comparisonLimit) }
    }

    func testCompareFreshlyReadmitsAndClearsAStaleOption() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        let admitted = try workflow.generate(state: &state, command: "quiet", media: [.primary: still], target: nil, durationFrames: 90, basePlans: try bases(still))
        let id = admitted[0].treatment.optionID
        let current = workflow.snapshot(command: "quiet", media: [.primary: still], target: nil, durationFrames: 90)
        var tamperedTreatment = admitted[0].treatment
        tamperedTreatment.effectPlan.parameters["durationSeconds"] = .number(4)
        tamperedTreatment.constructionSignature = TreatmentIdentity.constructionSignature(for: tamperedTreatment.effectPlan)
        let stale = AdmittedTreatmentExecution(treatment: tamperedTreatment, structure: admitted[0].structure, media: admitted[0].media, admittedCapabilities: admitted[0].admittedCapabilities, constructionSignature: admitted[0].constructionSignature, channels: admitted[0].channels, cards: admitted[0].cards, contract: admitted[0].contract, registryEffectID: admitted[0].registryEffectID, registryDigest: admitted[0].registryDigest, emitterAvailable: true)
        state.options[id] = stale
        XCTAssertThrowsError(try workflow.toggleComparison(id, state: &state, current: current, media: [.primary: still])) { error in
            guard case EditorialTreatmentWorkflowError.drifted = error else { return XCTFail("wrong error \(error)") }
        }
        XCTAssertNil(state.options[id])
        XCTAssertFalse(state.comparisonIDs.contains(id))
    }

    func testSnapshotRoundTripsEveryPreviewChannelAndExportRefusesMismatch() throws {
        var workflow = try workflow(); var state = EditorialTreatmentWorkflow.State(); let still = asset()
        let option = try XCTUnwrap(try workflow.generate(state: &state, command: "quiet", media: [.primary: still], target: nil, durationFrames: 90, basePlans: try bases(still)).first)
        let current = workflow.snapshot(command: "quiet", media: [.primary: still], target: nil, durationFrames: 90)
        let applied = try workflow.use(option.treatment.optionID, state: &state, current: current, media: [.primary: still]).0
        XCTAssertEqual(AdmittedChannelSnapshot(channels: applied.channels.materializedChannels()), applied.channels)
        let materialized = applied.channels.materializedChannels()
        let altered = NativeFCPXMLEffectChannels(transform: materialized.transform, opacity: materialized.opacity, saturation: materialized.saturation, durationSeconds: materialized.durationSeconds + 1, origin: materialized.origin, frameWidth: materialized.frameWidth, frameHeight: materialized.frameHeight, transition: materialized.transition, overlay: materialized.overlay)
        let mismatched = AdmittedTreatmentExecution(treatment: applied.treatment, structure: applied.structure, media: applied.media, admittedCapabilities: applied.admittedCapabilities, constructionSignature: applied.constructionSignature, channels: AdmittedChannelSnapshot(channels: altered), cards: applied.cards, contract: applied.contract, registryEffectID: applied.registryEffectID, registryDigest: applied.registryDigest, emitterAvailable: true)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [still]))
        let builder = StandaloneFCPXMLExportBuilder(gate: CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts)), outputRoot: URL(fileURLWithPath: "/tmp/editorial-mismatch-\(UUID().uuidString)"), registry: try registry())
        XCTAssertThrowsError(try builder.export(admitted: mismatched, mediaEvidence: evidence, installedFinalCut: FinalCutVersionIdentity(shortVersion: "12.3", build: "450152"))) { error in
            guard case .admittedArtifactMismatch = error as? StandaloneExportError else { return XCTFail("expected channel mismatch refusal, got \(error)") }
        }
    }

    func testChannelSnapshotMaterializesEveryFieldWithoutRecomputation() {
        let keyframe = NativeFCPXMLKeyframe(time: .init(numerator: 17, timescale: 720000), value: "1.2", curve: "linear", interp: "linear")
        let channels = NativeFCPXMLEffectChannels(
            transform: .init(positionX: [keyframe], positionY: [keyframe], scale: [keyframe], rotation: [keyframe], anchor: (1, 2), staticPosition: nil),
            opacity: .init(amount: [keyframe], staticAmount: nil, mode: .overlay), saturation: 25, durationSeconds: 3, origin: .movie(startSeconds: 7), frameWidth: 1920, frameHeight: 1080,
            transition: .init(cutFrame: 90, durationFrames: 12, outgoingDurationFrames: 90, incomingDurationFrames: 90),
            overlay: .init(startFrameWithinParent: 4, durationFrames: 20, opacity: 0.5, blendMode: .overlay)
        )
        let snapshot = AdmittedChannelSnapshot(channels: channels)
        XCTAssertEqual(snapshot, AdmittedChannelSnapshot(channels: snapshot.materializedChannels()))
        XCTAssertEqual(snapshot.digest, AdmittedChannelSnapshot(channels: snapshot.materializedChannels()).digest)
    }
}
