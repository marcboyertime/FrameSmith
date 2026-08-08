import XCTest
@testable import FCPCommandConsoleCore

final class CommandSessionTests: XCTestCase {
    private var sourceA: URL!
    private var sourceB: URL!

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        sourceA = root.appendingPathComponent("fcpcc-session-a-\(UUID().uuidString).mov")
        sourceB = root.appendingPathComponent("fcpcc-session-b-\(UUID().uuidString).mov")
        try Data("session-source-a".utf8).write(to: sourceA)
        try Data("session-source-b".utf8).write(to: sourceB)
    }

    override func tearDownWithError() throws {
        if let sourceA { try? FileManager.default.removeItem(at: sourceA) }
        if let sourceB { try? FileManager.default.removeItem(at: sourceB) }
        sourceA = nil
        sourceB = nil
    }

    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: root().appendingPathComponent("registry/effects"))
    }

    private func selection(_ type: SelectionType = .singleClip, clips: [String] = ["clip-a"], revision: String = "r1") throws -> SelectionToken {
        let urls = [sourceA!, sourceB!]
        let identities = try clips.enumerated().map { index, clip in
            SourceIdentity(
                itemID: clip,
                canonicalPath: urls[min(index, urls.count - 1)].standardizedFileURL.path,
                sha256: try ContentHasher.sha256File(urls[min(index, urls.count - 1)])
            )
        }
        return SelectionToken(
            selectionType: type,
            timelineID: "session-timeline",
            clipIDs: clips,
            sourceIdentities: identities,
            revision: revision,
            startFrame: type == .twoAdjacentClips ? 100 : 0,
            endFrame: type == .twoAdjacentClips ? 112 : 24,
            sourceDurationFrames: type == .twoAdjacentClips ? 1000 : 240,
            sourceRangeStartFrame: type == .twoAdjacentClips ? 0 : nil,
            sourceRangeEndFrame: type == .twoAdjacentClips ? 500 : nil,
            boundaryFrame: type == .twoAdjacentClips ? 100 : nil,
            frameRate: type == .twoAdjacentClips ? 24 : nil,
            handleBeforeFrames: type == .twoAdjacentClips ? 12 : 0,
            handleAfterFrames: type == .twoAdjacentClips ? 12 : 0
        )
    }

    private func sessionRoot(_ label: String = "session") -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fcpcc-\(label)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeSession(
        label: String = "session",
        capability: CommandAdapterCapability = .offline,
        revisionProvider: CommandSessionAdapter.RevisionProvider? = nil,
        mutation: CommandSessionAdapter.Mutation? = nil
    ) throws -> (CommandSession, URL) {
        let registry = try registry()
        let runtime = sessionRoot(label)
        let schema = root().appendingPathComponent("schemas/effect-plan.schema.json")
        let adapter = CommandSessionAdapter(capability: capability, revisionProvider: revisionProvider, mutation: mutation)
        return (try CommandSession(registry: registry, schemaURL: schema, runtimeRoot: runtime, adapter: adapter), runtime)
    }

    func testFourWorkflowPresentationsExposeTypedPanelState() async throws {
        let cases: [(String, SelectionToken, Target?, EffectID, Bool)] = [
            ("Give this image a slow clockwise rotation while zooming toward the point I select.", try selection(), Target.confirmed(x: 0.6, y: 0.4), .targetedRotateZoom, false),
            ("Make this look like old black-and-white television footage with static, grain, scanlines, and subtle image instability.", try selection(), nil, .oldTelevision, false),
            ("Make this clip dissolve naturally into the next clip.", try selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"]), nil, .naturalDissolve, false),
            ("Make this still image feel gently alive for four seconds, then fade quickly to black.", try selection(), nil, .livingStill, false)
        ]

        for (index, item) in cases.enumerated() {
            let (session, runtime) = try makeSession(label: "workflow-\(index)")
            defer { try? FileManager.default.removeItem(at: runtime) }
            let state = try await session.plan(command: item.0, selection: item.1, target: item.2)
            XCTAssertEqual(state.plan?.effectID, item.3)
            XCTAssertEqual(state.selectedClipSummary?.clipIDs, item.1.clipIDs)
            XCTAssertEqual(state.normalizedTarget, item.2)
            XCTAssertNotNil(state.plan)
            XCTAssertEqual(state.previewStatus, .ready)
            XCTAssertEqual(state.previewRendered, false)
            XCTAssertFalse(state.applyEnabled, "offline adapter must remain fail-closed")
            XCTAssertTrue(state.cancelEnabled)
            XCTAssertFalse(state.undoEnabled)
            XCTAssertEqual(state.plan?.previewStrategy, state.previewStrategy)
            if item.3 == .naturalDissolve || item.3 == .oldTelevision {
                XCTAssertTrue(state.editability.labels.isEmpty)
            } else {
                XCTAssertFalse(state.editability.labels.isEmpty)
            }
            XCTAssertEqual(state.editability.hasBakedAssets, item.4)
            XCTAssertEqual(state.history.map(\.state), [.previewed])
        }
    }

    func testPanelEditabilityUsesOnlyPresentationDeclaredParameters() async throws {
        let cases: [(String, SelectionToken, Target?, EffectID, Set<String>)] = [
            (
                "Give this image a slow clockwise rotation while zooming toward the point I select.",
                try selection(),
                Target.confirmed(x: 0.6, y: 0.4),
                .targetedRotateZoom,
                ["durationSeconds", "scaleStart", "scaleEnd", "rotationStartDegrees", "rotationEndDegrees"]
            ),
            (
                "Make this look like old black-and-white television footage with static, grain, scanlines, and subtle image instability.",
                try selection(),
                nil,
                .oldTelevision,
                []
            ),
            (
                "Make this clip dissolve naturally into the next clip.",
                try selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"]),
                nil,
                .naturalDissolve,
                []
            ),
            (
                "Make this still image feel gently alive for four seconds, then fade quickly to black.",
                try selection(),
                nil,
                .livingStill,
                ["durationSeconds", "pushInScaleStart", "pushInScaleEnd", "panX", "panY", "opacityStart", "opacityEnd", "fadeDurationSeconds"]
            )
        ]

        for (index, item) in cases.enumerated() {
            let (session, runtime) = try makeSession(label: "presentation-\(index)")
            defer { try? FileManager.default.removeItem(at: runtime) }
            let state = try await session.plan(command: item.0, selection: item.1, target: item.2)
            XCTAssertEqual(state.plan?.effectID, item.3)
            XCTAssertEqual(Set(state.editability.editable), item.4)
            XCTAssertEqual(
                Set(state.editability.labels.filter { $0.classification == .editable }.map(\.value)),
                item.4
            )
        }
    }

    func testMissingTargetAndUnsupportedRequestFailClosedWithPreciseIssue() async throws {
        let (session, runtime) = try makeSession(label: "errors")
        defer { try? FileManager.default.removeItem(at: runtime) }
        do {
            _ = try await session.plan(command: "rotate and zoom this clip", selection: try selection())
            XCTFail("targeted workflow without a point must fail")
        } catch let error as CommandSessionError {
            XCTAssertEqual(error, .missingRequiredTarget)
        }
        let missingTargetState = await session.state()
        XCTAssertEqual(missingTargetState.error?.code, .missingRequiredTarget)
        XCTAssertNil(missingTargetState.plan)
        XCTAssertFalse(missingTargetState.applyEnabled)

        do {
            _ = try await session.plan(command: "make this sparkle with arbitrary plugin magic", selection: try selection())
            XCTFail("unsupported workflow must fail")
        } catch let error as CommandSessionError {
            guard case .unsupportedRequest = error else { return XCTFail("unexpected error: \(error)") }
        }
        let unsupportedState = await session.state()
        XCTAssertEqual(unsupportedState.error?.code, .unsupportedRequest)
    }

    func testCapabilityAndRevisionGatesNeverInvokeMutation() async throws {
        final class MutationFlag: @unchecked Sendable { var count = 0 }
        let flag = MutationFlag()
        let capability = CommandAdapterCapability(effect: .livingStill, currentRevision: "r2")
        let (session, runtime) = try makeSession(
            label: "stale",
            capability: capability,
            revisionProvider: { @Sendable in "r2" },
            mutation: { _ in
                flag.count += 1
                return VerifiedMutationEvidence(evidenceID: "should-not-run", afterSnapshotHash: "none", verified: true)
            }
        )
        defer { try? FileManager.default.removeItem(at: runtime) }
        _ = try await session.plan(command: "make this still image feel gently alive", selection: try selection(revision: "r1"))
        let state = await session.state()
        XCTAssertFalse(state.applyEnabled)
        do {
            _ = try await session.apply()
            XCTFail("revision mismatch must deny apply")
        } catch let error as CommandSessionError {
            guard case .staleRevision(let expected, let actual) = error else { return XCTFail("unexpected error: \(error)") }
            XCTAssertEqual(expected, "r1")
            XCTAssertEqual(actual, "r2")
        }
        XCTAssertEqual(flag.count, 0)
        let staleState = await session.state()
        XCTAssertEqual(staleState.jobState, JobState.previewed)

        let (offline, offlineRuntime) = try makeSession(label: "offline")
        defer { try? FileManager.default.removeItem(at: offlineRuntime) }
        _ = try await offline.plan(command: "make this still image feel gently alive", selection: try selection())
        let offlineState = await offline.state()
        XCTAssertFalse(offlineState.applyEnabled)
        do { _ = try await offline.apply(); XCTFail("offline apply must fail") }
        catch let error as CommandSessionError {
            guard case .capabilityDenied = error else { return XCTFail("unexpected error: \(error)") }
        }
    }

    func testCancellationHistoryAndUnverifiedEvidenceRemainFailClosed() async throws {
        final class MutationFlag: @unchecked Sendable { var count = 0 }
        let flag = MutationFlag()
        let capability = CommandAdapterCapability(effect: .livingStill, currentRevision: "r1")
        let (session, runtime) = try makeSession(
            label: "cancel",
            capability: capability,
            revisionProvider: { "r1" },
            mutation: { _ in
                flag.count += 1
                return VerifiedMutationEvidence(evidenceID: "unverified", afterSnapshotHash: "after", verified: false)
            }
        )
        defer { try? FileManager.default.removeItem(at: runtime) }
        _ = try await session.plan(command: "make this still image feel gently alive", selection: try selection())
        let cancelled = try await session.cancel()
        XCTAssertEqual(cancelled.jobState, .cancelled)
        XCTAssertFalse(cancelled.cancelEnabled)
        XCTAssertFalse(cancelled.applyEnabled)
        XCTAssertEqual(cancelled.previewStatus, .cancelled)
        XCTAssertEqual(cancelled.history.map(\.state), [.previewed, .cancelled])
        do { _ = try await session.apply(); XCTFail("cancelled operation must not apply") }
        catch let error as CommandSessionError {
            guard case .capabilityDenied = error else { return XCTFail("unexpected error: \(error)") }
        }
        XCTAssertEqual(flag.count, 0)

        let (failed, failedRuntime) = try makeSession(
            label: "unverified",
            capability: capability,
            revisionProvider: { "r1" },
            mutation: { _ in
                flag.count += 1
                return VerifiedMutationEvidence(evidenceID: "unverified", afterSnapshotHash: "after", verified: false)
            }
        )
        defer { try? FileManager.default.removeItem(at: failedRuntime) }
        _ = try await failed.plan(command: "make this still image feel gently alive", selection: try selection())
        do { _ = try await failed.apply(); XCTFail("unverified evidence must fail") }
        catch let error as CommandSessionError {
            guard case .jobCoordinator = error else { return XCTFail("unexpected error: \(error)") }
        }
        let failedState = await failed.state()
        XCTAssertEqual(failedState.jobState, .rollbackRequired)
        XCTAssertFalse(failedState.applyEnabled)
        XCTAssertFalse(failedState.undoEnabled)
        XCTAssertEqual(flag.count, 1)
    }
}
