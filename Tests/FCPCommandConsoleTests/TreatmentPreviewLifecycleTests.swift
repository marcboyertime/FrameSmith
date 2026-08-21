import XCTest
@testable import FCPCommandConsoleCore

private actor PreviewWorkerCounter {
    private(set) var calls = 0
    func record() { calls += 1 }
}

private actor PreviewWorkerGate {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func waitForRelease() async {
        if !started {
            started = true
            let waiters = startWaiters
            startWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}

final class TreatmentPreviewLifecycleTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(
            "framesmith-preview-lifecycle-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }

    private func admittedRenderedExecution() throws -> AdmittedTreatmentExecution {
        let sourceURL = scratch.appendingPathComponent("source.png")
        try Data("public preview lifecycle fixture".utf8).write(to: sourceURL)
        let source = LocalMediaAsset(
            itemID: "source", url: sourceURL, kind: .still,
            dimensions: .init(width: 1920, height: 1080),
            durationSeconds: nil, frameRate: nil, hasAudio: false,
            canonicalPath: sourceURL.path,
            sha256: try ContentHasher.sha256File(sourceURL)
        )
        let registry = try registry()
        let gate = CapabilityGate(
            manualSemanticsEvidence: .init(
                admittedContracts: FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts
            )
        )
        let session = LocalMediaPlannerSession(
            registry: registry,
            schemaValidator: try PlanSchemaValidator(
                schemaURL: projectRoot().appendingPathComponent("schemas/effect-plan.schema.json")
            ),
            capabilityGate: gate
        )
        let base = try session.plan(
            request: "Make this a living still for 4 seconds.",
            primary: source, outgoing: nil, incoming: nil, target: nil
        ).plan
        let knowledge = try EditorialKnowledgeCatalog.load(
            from: projectRoot().appendingPathComponent("registry/editorial-techniques"),
            knownSourceIDs: EditorialKnowledgeCatalog.sourceIDs(
                fromCSV: projectRoot().appendingPathComponent("docs/editorial-intelligence/sources.csv")
            )
        )
        var workflow = EditorialTreatmentWorkflow(
            catalog: knowledge,
            registry: registry,
            admittedCapabilities: Set(
                FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts.map(\.rawValue)
            ),
            schemaValidator: try PlanSchemaValidator(
                schemaURL: projectRoot().appendingPathComponent("schemas/effect-plan.schema.json")
            ),
            treatmentContractValidator: try TreatmentPlanContractValidator(
                schemaURL: projectRoot().appendingPathComponent("schemas/treatment-plan.schema.json")
            ),
            capabilityGate: gate
        )
        var state = EditorialTreatmentWorkflow.State()
        return try XCTUnwrap(try workflow.generate(
            state: &state,
            command: "restrained depth movement",
            media: [.primary: source],
            target: nil,
            durationFrames: 120,
            basePlans: [.livingStill: base]
        ).first)
    }

    private func preparedAsset(for execution: AdmittedTreatmentExecution) throws -> RenderedEffectAsset {
        let movie = scratch.appendingPathComponent("prepared-\(UUID().uuidString).mov")
        try Data("exact rendered preview bytes".utf8).write(to: movie)
        let plan = execution.treatment.effectPlan
        let duration = try XCTUnwrap(plan.parameters["durationSeconds"]?.numberValue)
        let fps = Int(try XCTUnwrap(plan.parameters["fps"]?.numberValue))
        return RenderedEffectAsset(
            url: movie,
            sha256: try ContentHasher.sha256File(movie),
            constructionDigest: try RenderedConstructionIdentity.digest(plan: plan, media: execution.media),
            rendererRecipeDigest: String(repeating: "r", count: 64),
            sourceSHA256: try XCTUnwrap(execution.media[.primary]).sha256,
            width: 1920,
            height: 1080,
            fps: fps,
            frameCount: Int((duration * Double(fps)).rounded()),
            durationSeconds: duration,
            videoFormat: .proRes422HQ10Bit,
            videoOnly: true,
            provenance: ["renderer": "preview-lifecycle-test"]
        )
    }

    private func relabel(
        _ execution: AdmittedTreatmentExecution,
        optionID: String
    ) -> AdmittedTreatmentExecution {
        let source = execution.treatment
        let treatment = TreatmentPlan(
            optionID: optionID,
            structureFingerprint: source.structureFingerprint,
            intent: source.intent,
            name: source.name,
            idea: source.idea,
            changes: source.changes,
            preserved: source.preserved,
            techniqueCardIDs: source.techniqueCardIDs,
            effectPlan: source.effectPlan,
            editability: source.editability,
            previewFidelity: source.previewFidelity,
            dimensions: source.dimensions,
            estimatedLatency: source.estimatedLatency,
            monetary: source.monetary,
            privacy: source.privacy,
            provenanceSummary: source.provenanceSummary,
            techniqueCardVersions: source.techniqueCardVersions,
            constructionSignature: source.constructionSignature
        )
        return AdmittedTreatmentExecution(
            treatment: treatment,
            structure: execution.structure,
            media: execution.media,
            admittedCapabilities: execution.admittedCapabilities,
            constructionSignature: execution.constructionSignature,
            channels: execution.channels,
            cards: execution.cards,
            contract: execution.contract,
            registryEffectID: execution.registryEffectID,
            registryDigest: execution.registryDigest,
            emitterAvailable: execution.emitterAvailable
        )
    }

    func testRenderedPreviewRequiresExactBytesSelectsMovieAndBindsOptionAndFile() throws {
        let execution = try admittedRenderedExecution()
        XCTAssertThrowsError(try TreatmentPreviewAdmission.admit(
            execution: execution,
            preparedRenderedAsset: nil
        )) { error in
            XCTAssertEqual(
                error as? TreatmentPreviewAdmissionError,
                .renderedAssetRequired(execution.treatment.optionID)
            )
        }

        let asset = try preparedAsset(for: execution)
        let preview = try TreatmentPreviewAdmission.admit(
            execution: execution,
            preparedRenderedAsset: asset
        )
        let descriptor = try TreatmentComparisonTileDescriptor.make(
            preview: preview,
            execution: execution
        )
        guard case .rendered(let selected) = descriptor.representation else {
            return XCTFail("a rendered treatment must select its prepared movie")
        }
        XCTAssertEqual(selected.url, asset.url)
        XCTAssertEqual(selected.sha256, asset.sha256)

        let otherOption = relabel(execution, optionID: "different-option")
        XCTAssertThrowsError(try TreatmentPreviewAdmission.validate(preview, against: otherOption))

        try Data("mutated after admission".utf8).write(to: asset.url)
        XCTAssertThrowsError(try TreatmentPreviewAdmission.validate(preview, against: execution))
    }

    func testComparisonTransportResolvesOneExactFrameForEveryTile() throws {
        let execution = try admittedRenderedExecution()
        let preview = try TreatmentPreviewAdmission.admit(
            execution: execution,
            preparedRenderedAsset: try preparedAsset(for: execution)
        )
        let descriptor = try TreatmentComparisonTileDescriptor.make(
            preview: preview,
            execution: execution
        )
        var transport = try TreatmentComparisonTransport(
            descriptors: [descriptor, descriptor, descriptor]
        )
        transport.scrub(toFrame: 119)
        XCTAssertEqual(transport.resolvedFrameIndices(tileCount: 3), [119, 119, 119])
        XCTAssertEqual(transport.seconds, 119.0 / 30.0, accuracy: 0.000_001)
        transport.advance()
        XCTAssertEqual(transport.resolvedFrameIndices(tileCount: 3), [0, 0, 0])
        XCTAssertThrowsError(try TreatmentComparisonTransport(
            descriptors: [descriptor, descriptor, descriptor, descriptor]
        )) { error in
            XCTAssertEqual(error as? TreatmentPreviewAdmissionError, .comparisonLimit)
        }
    }

    func testCoordinatorDeduplicatesContentAndEnforcesThreeOptionLimit() async throws {
        let original = try admittedRenderedExecution()
        let asset = try preparedAsset(for: original)
        let counter = PreviewWorkerCounter()
        let worker = TreatmentPreviewPreparationWorker { _ in
            await counter.record()
            try await Task.sleep(for: .milliseconds(30))
            return asset
        }
        let coordinator = TreatmentPreviewPreparationCoordinator(worker: worker)
        let executions = (1...4).map { relabel(original, optionID: "option-\($0)") }

        async let first = coordinator.prepare(executions[0])
        async let second = coordinator.prepare(executions[1])
        async let third = coordinator.prepare(executions[2])
        let results = try await [first, second, third]
        XCTAssertTrue(results.allSatisfy {
            if case .ready = $0 { return true }
            return false
        })
        let callCount = await counter.calls
        XCTAssertEqual(callCount, 1, "one construction must render once")
        do {
            _ = try await coordinator.prepare(executions[3])
            XCTFail("a fourth comparison option must be refused")
        } catch {
            XCTAssertEqual(error as? TreatmentPreviewAdmissionError, .comparisonLimit)
        }
    }

    func testDurableResultAfterDeselectIsClassifiedStaleNotReady() async throws {
        let execution = try admittedRenderedExecution()
        let asset = try preparedAsset(for: execution)
        let gate = PreviewWorkerGate()
        let worker = TreatmentPreviewPreparationWorker { _ in
            // Simulate crossing the renderer's durable publication point.
            await gate.waitForRelease()
            return asset
        }
        let coordinator = TreatmentPreviewPreparationCoordinator(worker: worker)
        let task = Task { try await coordinator.prepare(execution) }
        await gate.waitUntilStarted()
        await coordinator.deselect(execution.treatment.optionID)
        await gate.release()
        let terminal = try await task.value
        let state = await coordinator.state(for: execution.treatment.optionID)
        let staleCount = await coordinator.durableStaleArtifactCount
        XCTAssertEqual(terminal, .cancelled)
        XCTAssertEqual(state, .cancelled)
        XCTAssertEqual(staleCount, 1)
    }

    func testLatestGenerationOwnsReadyStateWhenAnOlderWaiterCompletesLate() async throws {
        let execution = try admittedRenderedExecution()
        let asset = try preparedAsset(for: execution)
        let counter = PreviewWorkerCounter()
        let gate = PreviewWorkerGate()
        let worker = TreatmentPreviewPreparationWorker { _ in
            await counter.record()
            // Crossing the durable boundary makes cancellation non-destructive;
            // generation ownership still decides which waiter may publish UI state.
            await gate.waitForRelease()
            return asset
        }
        let coordinator = TreatmentPreviewPreparationCoordinator(worker: worker)
        let older = Task { try await coordinator.prepare(execution) }
        await gate.waitUntilStarted()
        await coordinator.deselect(execution.treatment.optionID)
        let newer = Task { try await coordinator.prepare(execution) }
        await gate.release()

        let oldResult = try await older.value
        let newResult = try await newer.value
        let finalState = await coordinator.state(for: execution.treatment.optionID)
        let calls = await counter.calls
        XCTAssertEqual(oldResult, .cancelled)
        guard case .ready(let latestPreview) = newResult,
              case .ready(let finalPreview) = finalState else {
            return XCTFail("only the latest generation may publish ready")
        }
        XCTAssertEqual(latestPreview, finalPreview)
        XCTAssertEqual(latestPreview.representation.contentDigest, asset.sha256)
        XCTAssertEqual(calls, 1, "same content remains deduplicated across ownership generations")
    }
}
