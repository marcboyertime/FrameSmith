import XCTest
@testable import FCPCommandConsoleCore

final class CoreTests: XCTestCase {
    private func registry() throws -> EffectRegistry {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try EffectRegistry.load(from: root.appendingPathComponent("registry/effects"))
    }

    private func selection(_ type: SelectionType = .singleClip, clips: [String] = ["clip-a"], revision: String = "r1") -> SelectionToken {
        SelectionToken(selectionType: type, timelineID: "timeline", clipIDs: clips, revision: revision, startFrame: type == .twoAdjacentClips ? 100 : 0, endFrame: type == .twoAdjacentClips ? 112 : 24, sourceDurationFrames: type == .twoAdjacentClips ? 1000 : 240, sourceRangeStartFrame: type == .twoAdjacentClips ? 0 : nil, sourceRangeEndFrame: type == .twoAdjacentClips ? 500 : nil, boundaryFrame: type == .twoAdjacentClips ? 100 : nil, frameRate: type == .twoAdjacentClips ? 24 : nil, handleBeforeFrames: type == .twoAdjacentClips ? 12 : 0, handleAfterFrames: type == .twoAdjacentClips ? 12 : 0)
    }

    func testRegistryHasExactlyFourDefinitionsAndAliases() throws {
        let registry = try registry()
        XCTAssertEqual(registry.all.count, 4)
        XCTAssertEqual(registry.resolve("VHS"), .oldTelevision)
        XCTAssertEqual(registry.resolve("crossfade"), .naturalDissolve)
        XCTAssertEqual(registry.resolve("parallax"), .livingStill)
    }

    func testParserAndPlannerAreDeterministicAndLocal() throws {
        let planner = DeterministicPlanner(registry: try registry())
        let operation = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let plan = try planner.plan(request: "apply old tv scanline at 12 fps", selection: selection(), target: Target.confirmed(x: 0.2, y: 0.8), operationID: operation)
        XCTAssertEqual(plan.effectID, .oldTelevision)
        XCTAssertFalse(plan.cost.paid)
        XCTAssertEqual(plan.cost.usd, 0)
        XCTAssertEqual(plan.operationID, operation)
        XCTAssertThrowsError(try planner.plan(request: "run /bin/sh; rm -rf", selection: selection()))
        XCTAssertThrowsError(try planner.plan(request: "make dissolve and parallax", selection: selection()))
        let targeted = try planner.plan(request: "targeted rotate and zoom clockwise for 2 seconds by 12 degrees", selection: selection(), target: Target.confirmed(x: 0.75, y: 0.25))
        XCTAssertEqual(targeted.effectID, .targetedRotateZoom)
        XCTAssertEqual(targeted.parameters["durationSeconds"]?.numberValue ?? 0, 2, accuracy: 0.0001)
        XCTAssertEqual(targeted.parameters["direction"]?.stringValue, "clockwise")
    }

    func testTargetAndParameterBoundsFailClosed() throws {
        let registry = try registry()
        let planner = DeterministicPlanner(registry: registry)
        XCTAssertEqual(Target.confirmed(x: -2, y: 2).x, 0)
        XCTAssertEqual(Target.confirmed(x: -2, y: 2).y, 1)
        let plan = try planner.plan(request: "crop", selection: selection(), target: Target.confirmed(x: 0.2, y: 0.3))
        var invalid = plan; invalid.normalizedPoint = Target(x: 2, y: 0.3)
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(invalid))
        invalid = plan; invalid.parameters["scale"] = .number(.infinity)
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(invalid))
    }

    func testAnchorCompensationCenterAndOffCenter() {
        let center = Point2D(x: 0.5, y: 0.5)
        let unchanged = SpatialTransformMath.compensate(source: center, scale: 2, rotationDegrees: 45)
        XCTAssertEqual(unchanged.translation.x, 0, accuracy: 1e-12)
        XCTAssertEqual(unchanged.translation.y, 0, accuracy: 1e-12)
        let point = Point2D(x: 0.8, y: 0.5)
        let compensated = SpatialTransformMath.compensate(source: point, scale: 2, rotationDegrees: 0)
        let applied = SpatialTransformMath.apply(point: point, scale: 2, rotationDegrees: 0, translation: compensated.translation)
        XCTAssertEqual(applied.x, point.x, accuracy: 1e-12)
        XCTAssertEqual(applied.y, point.y, accuracy: 1e-12)
        XCTAssertLessThan(compensated.translation.x, 0)
        XCTAssertEqual(compensated.compensatedAnchor.x, 0.65, accuracy: 1e-12)
    }

    func testDissolveSelectionRequirements() throws {
        let registry = try registry(); let planner = DeterministicPlanner(registry: registry)
        let valid = try planner.plan(request: "cross dissolve", selection: selection(.twoAdjacentClips, clips: ["a", "b"]))
        XCTAssertEqual(valid.effectID, .naturalDissolve)
        var stale = valid; stale.selectionToken.revision = "r2"
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(stale))
        var noHandle = valid; noHandle.selectionToken.handleBeforeFrames = 0
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(noHandle))
        var notAdjacent = valid; notAdjacent.selectionToken.adjacent = false
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(notAdjacent))
    }

    func testPathHashCostAndProvenancePolicies() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fcpcc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: temp) }
        let source = temp.appendingPathComponent("source.txt"); try Data("hello".utf8).write(to: source)
        let policy = PathPolicy(allowedInputRoots: [temp], outputRoot: temp.appendingPathComponent("out")); let canonical = try policy.canonicalizeInput(source)
        XCTAssertEqual(try ContentHasher.sha256File(canonical), ContentHasher.sha256(Data("hello".utf8)))
        XCTAssertThrowsError(try policy.validateOutput(temp.appendingPathComponent("../evil")))
        let usage = temp.appendingPathComponent("usage.jsonl"); var costs = CostPolicy(monthlyCeilingUSD: 20, usageURL: usage)
        XCTAssertNoThrow(try costs.enforce(CostEstimate(), operationID: UUID()))
        costs.approveFirstProvider("provider"); XCTAssertNoThrow(try costs.enforce(CostEstimate(paid: true, usd: 2, provider: "provider")))
        let uploadOperation = UUID()
        let uploadEstimate = CostEstimate(paid: false, usd: 0, provider: "local", requiresMediaUpload: true)
        XCTAssertThrowsError(try costs.enforce(uploadEstimate, operationID: uploadOperation))
        costs.approveFirstProvider("another-provider")
        XCTAssertThrowsError(try costs.enforce(uploadEstimate, operationID: uploadOperation), "provider/text approval must not authorize media upload")
        costs.approveMediaUpload(for: uploadOperation)
        XCTAssertTrue(costs.isMediaUploadApproved(for: uploadOperation))
        XCTAssertNoThrow(try costs.enforce(uploadEstimate, operationID: uploadOperation))
        let paidUpload = CostEstimate(paid: true, usd: 1, provider: "provider", requiresMediaUpload: true)
        let paidOperation = UUID()
        XCTAssertThrowsError(try costs.enforce(paidUpload, operationID: paidOperation), "media approval is independent from provider approval")
        costs.approveMediaUpload(for: paidOperation)
        XCTAssertNoThrow(try costs.enforce(paidUpload, operationID: paidOperation))
        XCTAssertEqual(try costs.monthTotal(provider: "provider"), 3, accuracy: 0.0001)
        let registry = try registry(); let plan = try DeterministicPlanner(registry: registry).plan(request: "crop", selection: selection(), target: Target.confirmed(x: 0.5, y: 0.5))
        let ledger = temp.appendingPathComponent("prov"); let store = IdempotencyStore(rootURL: ledger)
        let first = try store.register(plan: plan, beforeSnapshotHash: "before")
        let second = try store.register(plan: plan, beforeSnapshotHash: "before")
        XCTAssertEqual(first, second)
    }

    func testOverlayAdapterProducesVerifiedAlphaWhenToolsAvailable() throws {
        let fm = FileManager.default
        try XCTSkipUnless(fm.isExecutableFile(atPath: SafeFFmpegOverlayAdapter.ffmpegURL.path) && fm.isExecutableFile(atPath: SafeFFmpegOverlayAdapter.ffprobeURL.path), "Homebrew ffmpeg/ffprobe unavailable")
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fcpcc-overlay-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let metadata = try SafeFFmpegOverlayAdapter().generate(OverlayRequest(kind: .staticGrain, width: 160, height: 90, fps: 12, durationSeconds: 0.5, seed: 7), in: root)
        XCTAssertTrue(metadata.alphaCapable); XCTAssertFalse(metadata.sha256.isEmpty); XCTAssertTrue(metadata.pixelFormat.hasPrefix("yuva"))
        XCTAssertTrue(fm.fileExists(atPath: metadata.path.path))
    }
}
