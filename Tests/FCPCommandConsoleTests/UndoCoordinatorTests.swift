import XCTest
@testable import FCPCommandConsoleCore

final class UndoCoordinatorTests: XCTestCase {
    private var source: URL!

    override func setUpWithError() throws {
        source = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fcpcc-undo-source-\(UUID().uuidString).mov")
        try Data("undo-source".utf8).write(to: source)
    }

    override func tearDownWithError() throws {
        if let source { try? FileManager.default.removeItem(at: source) }
        source = nil
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: repoRoot().appendingPathComponent("registry/effects"))
    }

    private func plan(operationID: UUID = UUID()) throws -> EffectPlan {
        let identity = SourceIdentity(itemID: "undo-clip", canonicalPath: source.standardizedFileURL.path, sha256: try ContentHasher.sha256File(source))
        let selection = SelectionToken(selectionType: .singleClip, timelineID: "undo-timeline", clipIDs: ["undo-clip"], sourceIdentities: [identity], revision: "r1", startFrame: 0, endFrame: 24, sourceDurationFrames: 240)
        return try DeterministicPlanner(registry: registry()).plan(request: "make this still image feel gently alive", selection: selection, operationID: operationID)
    }

    private func runtime(_ label: String = "undo") -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fcpcc-\(label)-\(UUID().uuidString)", isDirectory: true)
    }

    private final class Counter: @unchecked Sendable {
        var value = 0
    }

    private final class RevisionBox: @unchecked Sendable {
        var value: String
        init(_ value: String) { self.value = value }
    }

    func testVerifiedUndoIsIdempotentAndSurvivesRestart() async throws {
        let root = runtime("success")
        defer { try? FileManager.default.removeItem(at: root) }
        let operation = UUID()
        let plan = try plan(operationID: operation)
        let coordinator = try JobCoordinator(runtimeRoot: root, registry: registry())
        let applied = try await coordinator.apply(plan: plan, currentRevision: "r1", beforeSnapshotHash: "before-hash") {
            VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after-hash", verified: true, postMutationRevision: "r2")
        }
        XCTAssertEqual(applied.state, .applied)
        let canUndo = await coordinator.canUndo(operationID: operation, currentRevision: "r2")
        XCTAssertTrue(canUndo)

        let counter = Counter()
        let undone = try await coordinator.undo(operationID: operation, currentRevision: "r2") { _ in
            counter.value += 1
            return VerifiedMutationEvidence(evidenceID: "undo", afterSnapshotHash: "before-hash", verified: true)
        }
        XCTAssertEqual(undone.state, .undone)
        XCTAssertEqual(undone.verifiedUndoEvidence?.afterSnapshotHash, "before-hash")
        let canUndoAfter = await coordinator.canUndo(operationID: operation, currentRevision: "r2")
        XCTAssertFalse(canUndoAfter)

        let duplicate = try await coordinator.undo(operationID: operation, currentRevision: "r2") { _ in
            counter.value += 1
            return VerifiedMutationEvidence(evidenceID: "duplicate", afterSnapshotHash: "before-hash", verified: true)
        }
        XCTAssertEqual(duplicate.state, .undone)
        XCTAssertEqual(counter.value, 1, "duplicate undo must never invoke the adapter")

        let restarted = try JobCoordinator(runtimeRoot: root, registry: registry())
        let restartedRecord = await restarted.record(operationID: operation)
        XCTAssertEqual(restartedRecord?.state, .undone)
        let restartedHistory = await restarted.history()
        XCTAssertEqual(restartedHistory.map(\.state), [.planned, .applying, .applied, .undoing, .undone])
    }

    func testStaleRevisionIsDeniedImmediatelyBeforeUndoClosure() async throws {
        let root = runtime("stale")
        defer { try? FileManager.default.removeItem(at: root) }
        let operation = UUID()
        let plan = try plan(operationID: operation)
        let coordinator = try JobCoordinator(runtimeRoot: root, registry: registry())
        _ = try await coordinator.apply(plan: plan, currentRevision: "r1", beforeSnapshotHash: "before-hash") {
            VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after-hash", verified: true, postMutationRevision: "r2")
        }

        let reads = Counter()
        let called = Counter()
        do {
            _ = try await coordinator.undo(operationID: operation, revisionProvider: {
                reads.value += 1
                return reads.value == 1 ? "r2" : "r3"
            }) { _ in
                called.value += 1
                return VerifiedMutationEvidence(evidenceID: "unexpected", afterSnapshotHash: "before-hash", verified: true)
            }
            XCTFail("stale revision must fail closed")
        } catch let error as JobCoordinatorError {
            guard case .staleRevision(let expected, let actual) = error else { return XCTFail("unexpected error: \(error)") }
            XCTAssertEqual(expected, "r2")
            XCTAssertEqual(actual, "r3")
        }
        XCTAssertEqual(reads.value, 2)
        XCTAssertEqual(called.value, 0)
        let record = await coordinator.record(operationID: operation)
        XCTAssertEqual(record?.state, .failed)
        XCTAssertFalse(record?.rollbackRequired ?? true)
    }

    func testMissingOrTamperedRollbackPayloadDisablesUndo() async throws {
        let missingRoot = runtime("missing-payload")
        defer { try? FileManager.default.removeItem(at: missingRoot) }
        let missingPlan = try plan()
        let missing = try JobCoordinator(runtimeRoot: missingRoot, registry: registry())
        _ = try await missing.apply(plan: missingPlan, currentRevision: "r1") {
            VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after", verified: true, postMutationRevision: "r2")
        }
        let missingCanUndo = await missing.canUndo(operationID: missingPlan.operationID, currentRevision: "r2")
        XCTAssertFalse(missingCanUndo)

        let tamperedRoot = runtime("tampered-payload")
        defer { try? FileManager.default.removeItem(at: tamperedRoot) }
        let tamperedPlan = try plan()
        let tampered = try JobCoordinator(runtimeRoot: tamperedRoot, registry: registry())
        _ = try await tampered.apply(plan: tamperedPlan, currentRevision: "r1", beforeSnapshotHash: "before-hash") {
            VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after", verified: true, postMutationRevision: "r2")
        }
        let payloadURL = tamperedRoot.appendingPathComponent("rollback/\(tamperedPlan.operationID.uuidString).json")
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: payloadURL)) as? [String: Any])
        object["beforeSnapshotHash"] = "tampered-before-hash"
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: payloadURL, options: .atomic)
        let tamperedCanUndo = await tampered.canUndo(operationID: tamperedPlan.operationID, currentRevision: "r2")
        XCTAssertFalse(tamperedCanUndo)
        do {
            _ = try await tampered.undo(operationID: tamperedPlan.operationID, currentRevision: "r2") { _ in
                XCTFail("tampered payload must not invoke undo")
                return VerifiedMutationEvidence(evidenceID: "unexpected", afterSnapshotHash: "before-hash", verified: true)
            }
            XCTFail("tampered payload must fail closed")
        } catch let error as JobCoordinatorError {
            guard case .undoUnavailable = error else { return XCTFail("unexpected error: \(error)") }
        }
    }

    func testUnverifiedAndWrongRestoredSnapshotBecomeRollbackRequired() async throws {
        for (label, returnedEvidence) in [
            ("unverified", VerifiedMutationEvidence(evidenceID: "unverified", afterSnapshotHash: "before-hash", verified: false)),
            ("wrong-hash", VerifiedMutationEvidence(evidenceID: "wrong", afterSnapshotHash: "not-before", verified: true)),
            ("empty-id", VerifiedMutationEvidence(evidenceID: "", afterSnapshotHash: "before-hash", verified: true))
        ] {
            let root = runtime(label)
            defer { try? FileManager.default.removeItem(at: root) }
            let undoPlan = try plan()
            let coordinator = try JobCoordinator(runtimeRoot: root, registry: registry())
            _ = try await coordinator.apply(plan: undoPlan, currentRevision: "r1", beforeSnapshotHash: "before-hash") {
                VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after", verified: true, postMutationRevision: "r2")
            }
            do {
                _ = try await coordinator.undo(operationID: undoPlan.operationID, currentRevision: "r2") { _ in returnedEvidence }
                XCTFail("invalid undo evidence must fail")
            } catch let error as JobCoordinatorError {
                guard case .verificationFailed = error else { return XCTFail("unexpected error: \(error)") }
            }
            let record = await coordinator.record(operationID: undoPlan.operationID)
            XCTAssertEqual(record?.state, .rollbackRequired)
            XCTAssertTrue(record?.rollbackRequired ?? false)
            XCTAssertNil(record?.verifiedUndoEvidence)
        }
    }

    func testInterruptedUndoRecoversAsRollbackRequired() async throws {
        let root = runtime("restart-recovery")
        defer { try? FileManager.default.removeItem(at: root) }
        let undoPlan = try plan()
        let coordinator = try JobCoordinator(runtimeRoot: root, registry: registry())
        _ = try await coordinator.apply(plan: undoPlan, currentRevision: "r1", beforeSnapshotHash: "before-hash") {
            VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after", verified: true, postMutationRevision: "r2")
        }
        let jobURL = root.appendingPathComponent("jobs/\(undoPlan.operationID.uuidString).json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var record = try decoder.decode(JobRecord.self, from: Data(contentsOf: jobURL))
        record.state = .undoing
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: jobURL, options: .atomic)

        let restarted = try JobCoordinator(runtimeRoot: root, registry: registry())
        let recovered = await restarted.record(operationID: undoPlan.operationID)
        XCTAssertEqual(recovered?.state, .rollbackRequired)
        XCTAssertTrue(recovered?.rollbackRequired ?? false)
        let recoveredHistory = await restarted.history()
        XCTAssertTrue(recoveredHistory.contains { $0.state == .rollbackRequired && $0.detail?.contains("recovered interrupted") == true })
    }

    func testCommandSessionUndoRequiresExactCapabilityPayloadAndAdapter() async throws {
        let root = runtime("session")
        defer { try? FileManager.default.removeItem(at: root) }
        let undoCalls = Counter()
        let revision = RevisionBox("r1")
        let capability = CommandAdapterCapability(effect: .livingStill, currentRevision: "r1", undoSupport: true)
        let adapter = CommandSessionAdapter(
            capability: capability,
            revisionProvider: { revision.value },
            mutation: { _ in
                revision.value = "r2"
                return VerifiedMutationEvidence(evidenceID: "apply", afterSnapshotHash: "after", verified: true, postMutationRevision: "r2")
            },
            undo: { _ in
                undoCalls.value += 1
                return VerifiedMutationEvidence(evidenceID: "undo", afterSnapshotHash: "before-hash", verified: true)
            },
            beforeSnapshotHash: "before-hash"
        )
        let session = try CommandSession(registry: registry(), runtimeRoot: root, adapter: adapter)
        _ = try await session.plan(command: "make this still image feel gently alive", selection: try makeSelection(), operationID: UUID())
        let plannedState = await session.state()
        XCTAssertFalse(plannedState.undoEnabled)
        _ = try await session.apply()
        let appliedState = await session.state()
        XCTAssertTrue(appliedState.undoEnabled)
        let undone = try await session.undo()
        XCTAssertEqual(undone.jobState, .undone)
        XCTAssertFalse(undone.undoEnabled)
        XCTAssertEqual(undoCalls.value, 1)
        let duplicate = try await session.undo()
        XCTAssertEqual(duplicate.jobState, .undone)
        XCTAssertEqual(undoCalls.value, 1)
    }

    private func makeSelection() throws -> SelectionToken {
        let identity = SourceIdentity(itemID: "undo-clip", canonicalPath: source.standardizedFileURL.path, sha256: try ContentHasher.sha256File(source))
        return SelectionToken(selectionType: .singleClip, timelineID: "undo-timeline", clipIDs: ["undo-clip"], sourceIdentities: [identity], revision: "r1", startFrame: 0, endFrame: 24, sourceDurationFrames: 240)
    }
}
