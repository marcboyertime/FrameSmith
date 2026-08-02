import XCTest
@testable import FCPCommandConsoleCore

final class CoreTests: XCTestCase {
    private var sourceA: URL!
    private var sourceB: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        sourceA = root.appendingPathComponent("fcpcc-core-source-a-\(UUID().uuidString).mov")
        sourceB = root.appendingPathComponent("fcpcc-core-source-b-\(UUID().uuidString).mov")
        try Data("synthetic-source-a".utf8).write(to: sourceA)
        try Data("synthetic-source-b".utf8).write(to: sourceB)
    }

    override func tearDownWithError() throws {
        if let sourceA { try? FileManager.default.removeItem(at: sourceA) }
        if let sourceB { try? FileManager.default.removeItem(at: sourceB) }
        sourceA = nil
        sourceB = nil
        try super.tearDownWithError()
    }

    private func registry() throws -> EffectRegistry {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try EffectRegistry.load(from: root.appendingPathComponent("registry/effects"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func schemaValidator() throws -> PlanSchemaValidator {
        try PlanSchemaValidator(schemaURL: projectRoot().appendingPathComponent("schemas/effect-plan.schema.json"))
    }

    private func encode(_ plan: EffectPlan) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(plan)
    }

    private func mutateSerializedPlan(_ plan: EffectPlan, _ mutate: (inout [String: Any]) throws -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encode(plan)) as? [String: Any])
        try mutate(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private struct CLIResult {
        var status: Int32
        var stdout: String
        var stderr: String
    }

    private func runCLI(_ arguments: [String]) throws -> CLIResult {
        let candidates = [
            projectRoot().appendingPathComponent(".build/arm64-apple-macosx/debug/fcpcommandconsole"),
            projectRoot().appendingPathComponent(".build/debug/fcpcommandconsole")
        ]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw XCTSkip("fcpcommandconsole executable is not built; run swift build before CLI integration tests")
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = projectRoot()
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        return CLIResult(
            status: process.terminationStatus,
            stdout: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }

    private func selection(_ type: SelectionType = .singleClip, clips: [String] = ["clip-a"], revision: String = "r1") -> SelectionToken {
        let urls = [sourceA!, sourceB!]
        let identities = clips.enumerated().map { index, clip in
            SourceIdentity(itemID: clip, canonicalPath: urls[min(index, urls.count - 1)].standardizedFileURL.path, sha256: (try! ContentHasher.sha256File(urls[min(index, urls.count - 1)])).lowercased())
        }
        return SelectionToken(selectionType: type, timelineID: "timeline", clipIDs: clips, sourceIdentities: identities, revision: revision, startFrame: type == .twoAdjacentClips ? 100 : 0, endFrame: type == .twoAdjacentClips ? 112 : 24, sourceDurationFrames: type == .twoAdjacentClips ? 1000 : 240, sourceRangeStartFrame: type == .twoAdjacentClips ? 0 : nil, sourceRangeEndFrame: type == .twoAdjacentClips ? 500 : nil, boundaryFrame: type == .twoAdjacentClips ? 100 : nil, frameRate: type == .twoAdjacentClips ? 24 : nil, handleBeforeFrames: type == .twoAdjacentClips ? 12 : 0, handleAfterFrames: type == .twoAdjacentClips ? 12 : 0)
    }

    func testRegistryHasExactlyFourDefinitionsAndAliases() throws {
        let registry = try registry()
        XCTAssertEqual(registry.all.count, 4)
        XCTAssertEqual(try registry.definition(for: .targetedRotateZoom).representation.rawValue, "fcp_native")
        XCTAssertEqual(try registry.definition(for: .oldTelevision).representation.rawValue, "generated_asset_plus_fcp_native")
        XCTAssertEqual(try registry.definition(for: .naturalDissolve).representation.rawValue, "fcp_native")
        XCTAssertEqual(try registry.definition(for: .livingStill).representation.rawValue, "fcp_native")
        XCTAssertEqual(registry.resolve("VHS"), .oldTelevision)
        XCTAssertEqual(registry.resolve("crossfade"), .naturalDissolve)
        XCTAssertEqual(registry.resolve("parallax"), .livingStill)
        XCTAssertNil(RepresentationClass(identifier: "native"))
        XCTAssertNil(RepresentationClass(identifier: "unknown"))
    }

    func testExactWorkflowSentencesParseWithNoAmbiguity() throws {
        let planner = DeterministicPlanner(registry: try registry())
        let targeted = try planner.plan(request: "Give this image a slow clockwise rotation while zooming toward the point I select.", selection: selection(), target: Target.confirmed(x: 0.6, y: 0.4))
        XCTAssertEqual(targeted.effectID, .targetedRotateZoom)
        XCTAssertEqual(targeted.confidence, 0.98, accuracy: 0.0001)
        XCTAssertTrue(targeted.ambiguities.isEmpty)
        XCTAssertEqual(targeted.parameters["durationSeconds"]?.numberValue, 4)
        XCTAssertEqual(targeted.parameters["scaleStart"]?.numberValue, 1)
        XCTAssertEqual(targeted.parameters["scaleEnd"]?.numberValue, 1.3)
        XCTAssertEqual(targeted.parameters["rotationStartDegrees"]?.numberValue, 0)
        XCTAssertEqual(targeted.parameters["rotationEndDegrees"]?.numberValue, 12)
        XCTAssertEqual(targeted.parameters["easing"]?.stringValue, "ease_in_out")
        XCTAssertEqual(targeted.parameters["direction"]?.stringValue, "clockwise")

        let oldTV = try planner.plan(request: "Make this look like old black-and-white television footage with static, grain, scanlines, and subtle image instability.", selection: selection())
        XCTAssertEqual(oldTV.effectID, .oldTelevision)
        XCTAssertEqual(oldTV.confidence, 0.98, accuracy: 0.0001)
        XCTAssertTrue(oldTV.ambiguities.isEmpty)
        XCTAssertEqual(oldTV.parameters["monochromeEnabled"], .boolean(true))
        XCTAssertEqual(oldTV.generatedAssets.count, 2)

        let dissolve = try planner.plan(request: "Make this clip dissolve naturally into the next clip.", selection: selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"]))
        XCTAssertEqual(dissolve.effectID, .naturalDissolve)
        XCTAssertEqual(dissolve.confidence, 0.98, accuracy: 0.0001)
        XCTAssertTrue(dissolve.ambiguities.isEmpty)
        XCTAssertEqual(dissolve.selectionToken.sourceIdentities.map(\.itemID), ["clip-a", "clip-b"])

        let living = try planner.plan(request: "Make this still image feel gently alive for four seconds, then fade quickly to black.", selection: selection())
        XCTAssertEqual(living.effectID, .livingStill)
        XCTAssertEqual(living.confidence, 0.98, accuracy: 0.0001)
        XCTAssertTrue(living.ambiguities.isEmpty)
        XCTAssertEqual(living.parameters["durationSeconds"]?.numberValue, 4)
        XCTAssertEqual(living.parameters["preserveOriginal"], .boolean(true))
        let enriched = try planner.plan(request: "Make this still image feel gently alive for four seconds, slightly enrich the colors, then fade quickly to black.", selection: selection())
        XCTAssertEqual(enriched.effectID, .livingStill)
        XCTAssertTrue(enriched.ambiguities.isEmpty)
    }

    func testExactWorkflowSentencesSerializeSchemaAndSemanticValidate() throws {
        let registry = try registry()
        let planner = DeterministicPlanner(registry: registry)
        let cases: [(String, SelectionToken, Target?)] = [
            (
                "Give this image a slow clockwise rotation while zooming toward the point I select.",
                selection(),
                Target.confirmed(x: 0.68, y: 0.34)
            ),
            (
                "Make this look like old black-and-white television footage with static, grain, scanlines, and subtle image instability.",
                selection(),
                nil
            ),
            (
                "Make this clip dissolve naturally into the next clip.",
                selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"]),
                nil
            ),
            (
                "Make this still image feel gently alive for four seconds, then fade quickly to black.",
                selection(),
                nil
            )
        ]

        for (request, token, target) in cases {
            let plan = try planner.plan(request: request, selection: token, target: target, operationID: UUID())
            let data = try encode(plan)
            XCTAssertNoThrow(try schemaValidator().validate(data), request)
            let decoded = try JSONDecoder().decode(EffectPlan.self, from: data)
            XCTAssertNoThrow(try PlanValidator(registry: registry).validate(decoded), request)
            // JSON numeric values intentionally do not preserve whether a
            // source default was encoded from `Int` or `Double`; canonical
            // sorted-key re-encoding is the wire-level round-trip contract.
            XCTAssertEqual(try encode(decoded), data, request)
        }
    }

    func testSchemaRejectsRequiredExtraRepresentationAndSourceIdentityViolations() throws {
        let registry = try registry()
        let planner = DeterministicPlanner(registry: registry)
        let plan = try planner.plan(
            request: "Give this image a slow clockwise rotation while zooming toward the point I select.",
            selection: selection(),
            target: Target.confirmed(x: 0.5, y: 0.5)
        )
        let validator = try schemaValidator()

        let missingRequired = try mutateSerializedPlan(plan) { object in
            object.removeValue(forKey: "operationID")
        }
        XCTAssertThrowsError(try validator.validate(missingRequired)) { error in
            guard case PlanSchemaValidationError.violation(let path, _) = error else {
                return XCTFail("expected required-field schema violation, got \(error)")
            }
            XCTAssertEqual(path, "$.operationID")
        }

        let extraField = try mutateSerializedPlan(plan) { object in
            object["unexpected"] = "not part of the wire contract"
        }
        XCTAssertThrowsError(try validator.validate(extraField)) { error in
            guard case PlanSchemaValidationError.violation(let path, _) = error else {
                return XCTFail("expected additionalProperties schema violation, got \(error)")
            }
            XCTAssertEqual(path, "$.unexpected")
        }

        let wrongRepresentation = try mutateSerializedPlan(plan) { object in
            object["representation"] = "native"
        }
        XCTAssertThrowsError(try validator.validate(wrongRepresentation))

        let malformedHash = try mutateSerializedPlan(plan) { object in
            var token = try XCTUnwrap(object["selectionToken"] as? [String: Any])
            var identities = try XCTUnwrap(token["sourceIdentities"] as? [[String: Any]])
            identities[0]["sha256"] = "not-a-sha256"
            token["sourceIdentities"] = identities
            object["selectionToken"] = token
        }
        XCTAssertThrowsError(try validator.validate(malformedHash))

        let malformedPath = try mutateSerializedPlan(plan) { object in
            var token = try XCTUnwrap(object["selectionToken"] as? [String: Any])
            var identities = try XCTUnwrap(token["sourceIdentities"] as? [[String: Any]])
            identities[0]["canonicalPath"] = "relative/source.mov"
            token["sourceIdentities"] = identities
            object["selectionToken"] = token
        }
        XCTAssertThrowsError(try validator.validate(malformedPath))

        let recursiveParameter = try mutateSerializedPlan(plan) { object in
            object["parameters"] = [
                "nested": [
                    "deep": [
                        "leaf": true
                    ]
                ]
            ]
        }
        XCTAssertNoThrow(try validator.validate(recursiveParameter))

        // JSON has no additional primitive type that can be represented by
        // ParameterValue. A non-finite number is therefore an unsupported
        // value and must fail before any schema branch is accepted.
        let nonFiniteParameter = Data(#"{"parameters":{"nested":NaN}}"#.utf8)
        XCTAssertThrowsError(try validator.validate(nonFiniteParameter))
    }

    func testBoundedCLIRejectsInjectionAndUnknownFlags() throws {
        let baseArguments = [
            "plan-bounded",
            "--request", "Give this image a slow clockwise rotation while zooming toward the point I select.",
            "--source", sourceA.path,
            "--source-id", "clip-a",
            "--revision", "r1",
            "--target-x", "0.5",
            "--target-y", "0.5"
        ]

        let unknownFlag = try runCLI(baseArguments + ["--backend", "native"])
        XCTAssertNotEqual(unknownFlag.status, 0)
        XCTAssertTrue(unknownFlag.stderr.contains("error:"), unknownFlag.stderr)

        let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fcpcc-cli-injection-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let injection = try runCLI([
            "plan-bounded",
            "--request", "rotate this; touch \(marker.path)",
            "--source", sourceA.path,
            "--source-id", "clip-a",
            "--revision", "r1",
            "--target-x", "0.5",
            "--target-y", "0.5"
        ])
        XCTAssertNotEqual(injection.status, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path), "CLI must never execute request text as shell")

        let injectedSourceID = try runCLI([
            "plan-bounded",
            "--request", "Give this image a slow clockwise rotation while zooming toward the point I select.",
            "--source", sourceA.path,
            "--source-id", "clip-a;touch",
            "--revision", "r1",
            "--target-x", "0.5",
            "--target-y", "0.5"
        ])
        XCTAssertNotEqual(injectedSourceID.status, 0)
        XCTAssertFalse(injectedSourceID.stdout.contains("native.targeted_rotate_zoom"))
    }

    func testSelectionSourceIdentityValidationFailsClosed() throws {
        let registry = try registry()
        let planner = DeterministicPlanner(registry: registry)
        let plan = try planner.plan(request: "crop", selection: selection(), target: Target.confirmed(x: 0.5, y: 0.5))
        var missing = plan
        missing.selectionToken.sourceIdentities = []
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(missing))
        var uppercase = plan
        uppercase.selectionToken.sourceIdentities[0].sha256 = uppercase.selectionToken.sourceIdentities[0].sha256.uppercased()
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(uppercase))
        var nonCanonical = plan
        nonCanonical.selectionToken.sourceIdentities[0].canonicalPath += "/../source.mov"
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(nonCanonical))
        var duplicate = try planner.plan(request: "cross dissolve", selection: selection(.twoAdjacentClips, clips: ["clip-a", "clip-b"]))
        duplicate.selectionToken.sourceIdentities[1] = duplicate.selectionToken.sourceIdentities[0]
        XCTAssertThrowsError(try PlanValidator(registry: registry).validate(duplicate))
    }

    func testPlanSchemaIncludesWireAndTypedIdentityContract() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("schemas/effect-plan.schema.json"))) as! [String: Any]
        let properties = schema["properties"] as! [String: Any]
        XCTAssertEqual((properties["representation"] as! [String: Any])["enum"] as? [String], ["fcp_native", "generated_asset_plus_fcp_native", "external_render_required"])
        XCTAssertNotNil(properties["generatedAssets"])
        XCTAssertNotNil(properties["previewStrategy"])
        XCTAssertNotNil(properties["verification"])
        let defs = schema["$defs"] as! [String: Any]
        let token = defs["selectionToken"] as! [String: Any]
        XCTAssertNotNil((token["properties"] as! [String: Any])["sourceIdentities"])
        XCTAssertNotNil(defs["sourceIdentity"])
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: costs.providerApprovalURL.path))
        let uploadOperation = UUID()
        let uploadEstimate = CostEstimate(paid: false, usd: 0, provider: "local", requiresMediaUpload: true)
        XCTAssertThrowsError(try costs.enforce(uploadEstimate, operationID: uploadOperation))
        costs.approveFirstProvider("another-provider")
        XCTAssertThrowsError(try costs.enforce(uploadEstimate, operationID: uploadOperation), "provider/text approval must not authorize media upload")
        costs.approveMediaUpload(for: uploadOperation)
        XCTAssertTrue(costs.isMediaUploadApproved(for: uploadOperation))
        XCTAssertTrue(FileManager.default.fileExists(atPath: costs.mediaUploadApprovalURL.path))
        XCTAssertTrue(String(data: try Data(contentsOf: costs.mediaUploadApprovalURL), encoding: .utf8)?.contains(uploadOperation.uuidString) == true)
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
