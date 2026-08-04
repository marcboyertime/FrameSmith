import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import FCPCommandConsoleCore

final class LocalPlanPackageTests: XCTestCase {
    private var root: URL!
    private var source: URL!
    private var outputRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("fcpcc-local-package-\(UUID().uuidString)", isDirectory: true)
        source = root.appendingPathComponent("photo source.png")
        outputRoot = root.appendingPathComponent("packages", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try writePNG(to: source, red: 0.2)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
        root = nil
        source = nil
        outputRoot = nil
        try super.tearDownWithError()
    }

    func testBuildCreatesInertSelfContainedPackageWithVerifiedHashesAndPreservesSource() async throws {
        let result = try await planningResult()
        let sourceBytes = try Data(contentsOf: source)
        let package = try LocalPlanPackageBuilder(outputRoot: outputRoot).build(result)
        XCTAssertEqual(package.url.lastPathComponent, result.plan.operationID.uuidString)
        XCTAssertEqual(try Data(contentsOf: source), sourceBytes)
        XCTAssertFalse(package.manifest.containsFCPXML)
        XCTAssertFalse(package.manifest.containsEffectRender)
        XCTAssertEqual(package.manifest.finalCutCompatibility, "unverified")
        XCTAssertEqual(package.manifest.schemaVersion, "2.0")
        XCTAssertEqual(package.manifest.media.map(\.role), [.primary])
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.url.appendingPathComponent("EffectPlan.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.url.appendingPathComponent("Manifest.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.url.appendingPathComponent("Provenance.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.url.appendingPathComponent("README.txt").path))
        let media = try XCTUnwrap(package.manifest.media.first)
        let copied = package.url.appendingPathComponent(media.relativePath)
        XCTAssertEqual(try ContentHasher.sha256File(copied), media.sourceSHA256)
        XCTAssertEqual(try Data(contentsOf: copied), sourceBytes)
        let allPaths = try recursiveRelativePaths(in: package.url)
        XCTAssertFalse(allPaths.contains { $0.lowercased().hasSuffix(".fcpxml") })
        XCTAssertFalse(allPaths.contains { $0.contains("Render") })
        let manifest = try JSONDecoder().decode(LocalPlanPackageManifest.self, from: Data(contentsOf: package.url.appendingPathComponent("Manifest.json")))
        XCTAssertEqual(manifest, package.manifest)
        let provenanceDecoder = JSONDecoder()
        provenanceDecoder.dateDecodingStrategy = .iso8601
        let provenance = try provenanceDecoder.decode(LocalPlanPackageProvenance.self, from: Data(contentsOf: package.url.appendingPathComponent("Provenance.json")))
        XCTAssertEqual(provenance.sources.map(\.canonicalPath), [source.path])
    }

    func testExistingOperationTargetIsNeverOverwritten() async throws {
        let result = try await planningResult()
        let builder = LocalPlanPackageBuilder(outputRoot: outputRoot)
        _ = try builder.build(result)
        XCTAssertThrowsError(try builder.build(result)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .targetExists(outputRoot.appendingPathComponent(result.plan.operationID.uuidString, isDirectory: true)))
        }
    }

    func testStaleSourceAndSelectionMismatchFailAndCleanStaging() async throws {
        let result = try await planningResult()
        try writePNG(to: source, red: 0.8)
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: outputRoot).build(result)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .sourceStale(source))
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: outputRoot.path)
        XCTAssertFalse(names.contains { $0.contains(".staging.") })

        try writePNG(to: source, red: 0.2)
        let fresh = try await planningResult()
        let other = root.appendingPathComponent("other.png")
        try writePNG(to: other, red: 0.5)
        let otherAsset = try await LocalMediaAdmission().admit(other)
        let mismatched = try LocalMediaSelection(effectID: .targetedRotateZoom, primary: otherAsset, outgoing: nil, incoming: nil)
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: outputRoot).build(plan: fresh.plan, admission: fresh.admission, selection: mismatched)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .selectionDoesNotMatchPlan)
        }
    }

    func testUnsafeSymlinkAndFinalCutRootsAndLegacyAdmissionAreRejected() async throws {
        let result = try await planningResult()
        let symlink = root.appendingPathComponent("linked-packages")
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outputRoot)
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: symlink).build(result)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .outputRootSymlink(symlink.standardizedFileURL))
        }
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: URL(fileURLWithPath: "/")).build(result)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .outputRootUnsafe(URL(fileURLWithPath: "/")))
        }
        let libraryRoot = root.appendingPathComponent("example.fcpbundle/export")
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: libraryRoot).build(result)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .outputRootForbidden(libraryRoot.standardizedFileURL))
        }
        let legacy = try XCTUnwrap("{\"schemaVersion\":\"1.0\",\"representation\":\"fcp_native\"}".data(using: .utf8))
        let legacyAdmission = try EffectPlanAdmission.decode(legacy)
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: outputRoot).build(plan: result.plan, admission: legacyAdmission, selection: result.selection)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .invalidAdmission)
        }
    }

    func testSourceThatBecomesNonregularIsRejectedBeforeCopy() async throws {
        let result = try await planningResult()
        try FileManager.default.removeItem(at: source)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: outputRoot).build(result)) { error in
            guard case .sourceNotRegular(let rejectedURL) = error as? LocalPlanPackageError else {
                return XCTFail("Expected nonregular source rejection")
            }
            XCTAssertEqual(rejectedURL.path, source.path)
        }
        let names = try? FileManager.default.contentsOfDirectory(atPath: outputRoot.path)
        XCTAssertFalse(names?.contains { $0.contains(".staging.") } ?? true)
    }

    /// A dangling symlink is invisible to `fileExists`, so only an exclusive
    /// rename can refuse to publish over it instead of writing through it.
    func testPublishRefusesADanglingSymlinkAtTheOperationTarget() async throws {
        let result = try await planningResult()
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let target = outputRoot.appendingPathComponent(result.plan.operationID.uuidString, isDirectory: true)
        let absent = root.appendingPathComponent("never-created")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: absent)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))

        XCTAssertThrowsError(try LocalPlanPackageBuilder(outputRoot: outputRoot).build(result)) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .targetExists(target))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: absent.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: outputRoot.path)
        XCTAssertFalse(names.contains { $0.contains(".staging.") })
    }

    /// Cancellation before the commit point must stay distinguishable from an
    /// I/O failure, publish nothing, and leave no staging behind.
    func testCancellationBeforeCommitPublishesNothingAndReportsCancellation() async throws {
        let result = try await planningResult()
        let outputRoot = self.outputRoot!
        let task = Task.detached { () -> Result<LocalPlanPackage, Error> in
            while !Task.isCancelled { await Task.yield() }
            do { return .success(try LocalPlanPackageBuilder(outputRoot: outputRoot).build(result)) } catch { return .failure(error) }
        }
        task.cancel()
        switch await task.value {
        case .success: XCTFail("A cancelled build must not publish a package")
        case .failure(let error): XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: outputRoot.path)) ?? []
        XCTAssertEqual(names, [])
    }

    func testPackagingIsRefusedWhenTheInputsNoLongerMatchThePlan() async throws {
        let result = try await planningResult()
        let asset = try XCTUnwrap(result.selection.slots.first?.media)
        let builder = LocalPlanPackageBuilder(outputRoot: outputRoot)

        XCTAssertThrowsError(try builder.build(result, currentInputs: inputs(request: "something else", target: result.inputs.target, primary: asset))) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .inputsStale(.commandChanged))
        }
        XCTAssertThrowsError(try builder.build(result, currentInputs: inputs(request: result.inputs.request, target: nil, primary: asset))) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .inputsStale(.targetChanged))
        }
        XCTAssertThrowsError(try builder.build(result, currentInputs: inputs(request: result.inputs.request, target: result.inputs.target, primary: nil))) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .inputsStale(.sourceRemoved(.primary)))
        }
        let other = root.appendingPathComponent("other.png")
        try writePNG(to: other, red: 0.5)
        let otherAsset = try await LocalMediaAdmission().admit(other)
        XCTAssertThrowsError(try builder.build(result, currentInputs: LocalMediaPlanInputs(request: result.inputs.request, target: result.inputs.target, primary: asset, outgoing: otherAsset, incoming: nil))) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .inputsStale(.sourceAdded(.outgoing)))
        }
        XCTAssertThrowsError(try builder.build(result, currentInputs: inputs(request: result.inputs.request, target: result.inputs.target, primary: otherAsset))) { error in
            XCTAssertEqual(error as? LocalPlanPackageError, .inputsStale(.sourceChanged(.primary)))
        }
        // A stale plan is refused before the output root is even touched.
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: outputRoot.path)) ?? [], [])

        // Unchanged inputs still package normally.
        let package = try builder.build(result, currentInputs: result.inputs)
        XCTAssertEqual(package.url.lastPathComponent, result.plan.operationID.uuidString)
    }

    func testDriftReportsTheCommandBeforeTheTargetAndRolesInAFixedOrder() async throws {
        let result = try await planningResult()
        let asset = try XCTUnwrap(result.selection.slots.first?.media)
        XCTAssertNil(result.staleness(against: result.inputs))
        // Every field changed at once still reports the command first, so the
        // same drift never produces a different message run to run.
        XCTAssertEqual(result.staleness(against: inputs(request: "changed", target: nil, primary: nil)), .commandChanged)
        XCTAssertEqual(result.staleness(against: inputs(request: result.inputs.request, target: nil, primary: nil)), .targetChanged)
        XCTAssertEqual(result.staleness(against: inputs(request: result.inputs.request, target: result.inputs.target, primary: asset)), nil)
    }

    private func inputs(request: String, target: Target?, primary: LocalMediaAsset?) -> LocalMediaPlanInputs {
        LocalMediaPlanInputs(request: request, target: target, primary: primary, outgoing: nil, incoming: nil)
    }

    private func planningResult() async throws -> LocalMediaPlanningResult {
        let asset = try await LocalMediaAdmission().admit(source)
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let session = LocalMediaPlannerSession(
            registry: try EffectRegistry.load(from: project.appendingPathComponent("registry/effects")),
            schemaValidator: try PlanSchemaValidator(schemaURL: project.appendingPathComponent("schemas/effect-plan.schema.json"))
        )
        return try session.plan(
            request: "Give this image a slow clockwise rotation while zooming toward the point I select.",
            primary: asset,
            outgoing: nil,
            incoming: nil,
            target: .confirmed(x: 0.5, y: 0.5)
        )
    }

    private func recursiveRelativePaths(in root: URL) throws -> [String] {
        let enumerator = try FileManager.default.subpathsOfDirectory(atPath: root.path)
        return enumerator.sorted()
    }

    private func writePNG(to url: URL, red: CGFloat) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: red, green: 0.3, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
