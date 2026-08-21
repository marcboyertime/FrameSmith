import AVFoundation
import CoreImage
import CoreML
import Darwin
import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class LivingStillDepthRendererTests: XCTestCase {
    private let fileManager = FileManager.default

    func testRequestValidationPinsEvenBoundedExactFramesAndVersion() throws {
        XCTAssertEqual(
            LivingStillDepthRenderRequest.currentDeterministicVersion,
            "living-still-depth-warp-v2-hq",
            "the HQ codec change must retain its own cache and recipe identity"
        )
        let base = request()
        XCTAssertEqual(try LivingStillDepthRenderer.validate(base), 24)

        XCTAssertThrowsError(try LivingStillDepthRenderer.validate(request(width: 127))) { error in
            guard case LivingStillDepthRenderError.invalidRequest(let detail) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(detail.contains("dimensions"))
        }
        XCTAssertThrowsError(try LivingStillDepthRenderer.validate(request(duration: 0.1))) { error in
            guard case LivingStillDepthRenderError.invalidRequest(let detail) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(detail.contains("whole frame"))
        }
        XCTAssertThrowsError(try LivingStillDepthRenderer.validate(request(panX: 0.081)))
        XCTAssertThrowsError(try LivingStillDepthRenderer.validate(request(deterministicVersion: "future-version")))
        XCTAssertThrowsError(try LivingStillDepthRenderer.validate(request(hash: String(repeating: "A", count: 64))))
    }

    func testAspectFitPolicyPreservesGeometryAndPinsModelShape() throws {
        let landscape = try LivingStillDepthAspectMapping.make(
            sourceWidth: 1_920,
            sourceHeight: 1_080,
            policy: .aspectFitEdgeExtended
        )
        XCTAssertEqual(landscape.scaleX, landscape.scaleY, accuracy: 0.000_000_1)
        XCTAssertEqual(landscape.contentRect.width, 518, accuracy: 0.000_001)
        XCTAssertEqual(landscape.contentRect.height, 291.375, accuracy: 0.000_001)
        XCTAssertEqual(landscape.contentRect.minY, 50.3125, accuracy: 0.000_001)

        let portrait = try LivingStillDepthAspectMapping.make(
            sourceWidth: 1_080,
            sourceHeight: 1_920,
            policy: .aspectFitEdgeExtended
        )
        XCTAssertEqual(portrait.scaleX, portrait.scaleY, accuracy: 0.000_000_1)
        XCTAssertEqual(portrait.contentRect.height, 392, accuracy: 0.000_001)
        XCTAssertEqual(portrait.contentRect.width, 220.5, accuracy: 0.000_001)
        XCTAssertEqual(portrait.contentRect.minX, 148.75, accuracy: 0.000_001)
    }

    func testStretchPolicyIsExplicitlyNonUniformAndUsesWholeModelRect() throws {
        let mapping = try LivingStillDepthAspectMapping.make(
            sourceWidth: 1_920,
            sourceHeight: 1_080,
            policy: .stretchToFixedModelInput
        )
        XCTAssertNotEqual(mapping.scaleX, mapping.scaleY)
        XCTAssertEqual(mapping.contentRect, CGRect(x: 0, y: 0, width: 518, height: 392))
    }

    func testSmootherstepHasPinnedEndpointsMonotonicMotionAndFlatEnds() {
        XCTAssertEqual(LivingStillDepthMotionCurve.smootherstep(-1), 0)
        XCTAssertEqual(LivingStillDepthMotionCurve.smootherstep(0), 0)
        XCTAssertEqual(LivingStillDepthMotionCurve.smootherstep(1), 1)
        XCTAssertEqual(LivingStillDepthMotionCurve.smootherstep(2), 1)

        let samples = (0...100).map { LivingStillDepthMotionCurve.smootherstep(Double($0) / 100) }
        for pair in zip(samples, samples.dropFirst()) { XCTAssertLessThanOrEqual(pair.0, pair.1) }
        XCTAssertLessThan(LivingStillDepthMotionCurve.smootherstep(0.001), 0.000_001)
        XCTAssertLessThan(1 - LivingStillDepthMotionCurve.smootherstep(0.999), 0.000_001)

        let motion = LivingStillDepthMotionCurve.sample(progress: 1, request: request(pushIn: 0.1, panX: 0.02, panY: -0.03))
        XCTAssertEqual(motion.scale, 1.1, accuracy: 0.000_000_1)
        XCTAssertEqual(motion.panX, 0.02, accuracy: 0.000_000_1)
        XCTAssertEqual(motion.panY, -0.03, accuracy: 0.000_000_1)
    }

    func testDepthSmoothingIsDeterministicBoundedAndNeverEightBit() throws {
        var values = [Float](repeating: 0, count: 25)
        values[12] = 1
        let bits = values.map { Float16($0).bitPattern }

        let unsmoothed = try LivingStillDepthFieldProcessor.process(bits: bits, width: 5, height: 5, smoothing: 0)
        let smoothed = try LivingStillDepthFieldProcessor.process(bits: bits, width: 5, height: 5, smoothing: 1)
        let repeated = try LivingStillDepthFieldProcessor.process(bits: bits, width: 5, height: 5, smoothing: 1)

        XCTAssertEqual(unsmoothed.values[12], 1, accuracy: 0.000_001)
        XCTAssertLessThan(smoothed.values[12], unsmoothed.values[12])
        XCTAssertGreaterThan(smoothed.values[11], 0)
        XCTAssertLessThanOrEqual(abs(smoothed.values[12] - unsmoothed.values[12]), 0.180_001)
        XCTAssertEqual(smoothed, repeated)
        XCTAssertNotEqual(unsmoothed.digest, smoothed.digest)
        XCTAssertEqual(smoothed.digest.count, 64)

        let rawDigest = LivingStillDepthFieldProcessor.rawFP16Digest(bits: bits, width: 5, height: 5)
        let changedHalf = bits.enumerated().map { index, value in index == 0 ? Float16(0.000_1).bitPattern : value }
        XCTAssertNotEqual(rawDigest, LivingStillDepthFieldProcessor.rawFP16Digest(bits: changedHalf, width: 5, height: 5))

        let padded = LivingStillProcessedDepthField(
            width: 4,
            height: 2,
            values: [0, 0, 1, 1, 0, 0, 1, 1],
            mean: 0.5,
            digest: "fixture"
        )
        XCTAssertEqual(
            LivingStillDepthFieldProcessor.mean(padded, in: CGRect(x: 2, y: 0, width: 2, height: 2)),
            1,
            accuracy: 0.000_001,
            "model padding must not bias the depth center used by the warp"
        )
    }

    func testModelLocatorOverrideWinsWithoutConsultingDefaultPath() {
        let override = URL(fileURLWithPath: "/tmp/frame-smith-explicit-depth-model", isDirectory: true)
        let locator = LivingStillDepthModelLocator(explicitModelRoot: override)
        XCTAssertEqual(locator.resolvedModelRoot, override)
        XCTAssertEqual(locator.compiledModelURL.lastPathComponent, "DepthAnythingV2SmallF16.mlmodelc")
    }

    func testLocatorRejectsUnknownSourceBytesBeforeCompiledCache() throws {
        let root = try temporaryDirectory("bad-model")
        defer { try? fileManager.removeItem(at: root) }
        let manifest = root.appendingPathComponent("DepthAnythingV2SmallF16.mlpackage/Manifest.json")
        try fileManager.createDirectory(at: manifest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not the pinned manifest".utf8).write(to: manifest)
        try fileManager.createDirectory(
            at: root.appendingPathComponent("DepthAnythingV2SmallF16.mlmodelc"),
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(try LivingStillDepthModelLocator(explicitModelRoot: root).locate()) { error in
            guard case LivingStillDepthRenderError.modelSourceHashMismatch(let path, _, _) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(path, "DepthAnythingV2SmallF16.mlpackage/Manifest.json")
        }
    }

    func testPinnedPackageCompilationIgnoresArbitrarySameShapeCompiledCacheAndSurvivesOriginalPathSwap() throws {
        let installed = LivingStillDepthModelLocator()
        try XCTSkipUnless(installed.runtimeArtifactIsPresent, "Pinned DA-V2 source package is not installed")

        let root = try temporaryDirectory("untrusted-compiled-cache")
        defer { try? fileManager.removeItem(at: root) }
        try copyPinnedPackage(from: installed.resolvedModelRoot, to: root)

        // A plausible cache with the expected names and metadata shape is still
        // not evidence that it was compiled from Apple's pinned package.
        let untrusted = root.appendingPathComponent(LivingStillDepthModelLocator.compiledModelName, isDirectory: true)
        try fileManager.createDirectory(at: untrusted.appendingPathComponent("weights"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: untrusted.appendingPathComponent("analytics"), withIntermediateDirectories: true)
        try Data("same-shape-but-not-the-pinned-model".utf8).write(to: untrusted.appendingPathComponent("model.mil"))
        try Data(repeating: 0x41, count: 830).write(to: untrusted.appendingPathComponent("coremldata.bin"))
        try Data("[]".utf8).write(to: untrusted.appendingPathComponent("metadata.json"))
        try Data("not-apple-weights".utf8).write(to: untrusted.appendingPathComponent("weights/weight.bin"))
        try Data("not-apple-analytics".utf8).write(to: untrusted.appendingPathComponent("analytics/coremldata.bin"))

        let admission = try LivingStillDepthModelLocator(explicitModelRoot: root).locate()
        defer { admission.close() }
        XCTAssertEqual(admission.identity.sourceRevision, LivingStillDepthModelLocator.sourceRevision)
        XCTAssertEqual(admission.identity.compilationMode, LivingStillDepthModelLocator.compilationMode)
        XCTAssertEqual(admission.identity.compilerInputDigest.count, 64)
        XCTAssertEqual(admission.identity.compiledArtifactDigest.count, 64)
        XCTAssertEqual(admission.identity.compiledSnapshotDigest.count, 64)
        XCTAssertTrue(admission.compiledModelURL.path.hasPrefix(admission.snapshotRootURL.path + "/"))
        XCTAssertFalse(admission.compiledModelURL.path.hasPrefix(root.path + "/"))
        XCTAssertNoThrow(try admission.verifySnapshot())

        // Replacing both the acquired cache and the original source package
        // after admission cannot redirect Core ML's already-private snapshot.
        let movedPackage = root.appendingPathComponent("original-package-moved", isDirectory: true)
        try fileManager.moveItem(
            at: root.appendingPathComponent(LivingStillDepthModelLocator.packageName, isDirectory: true),
            to: movedPackage
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent(LivingStillDepthModelLocator.packageName, isDirectory: true),
            withIntermediateDirectories: false
        )
        try fileManager.removeItem(at: untrusted)
        try fileManager.createDirectory(at: untrusted, withIntermediateDirectories: false)
        XCTAssertNoThrow(try admission.verifySnapshot())

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        XCTAssertNoThrow(try MLModel(contentsOf: admission.compiledModelURL, configuration: configuration))
    }

    func testPrivateCompiledSnapshotIsReadOnlyAndDetectsTamperAndPathReplacement() throws {
        let locator = LivingStillDepthModelLocator()
        try XCTSkipUnless(locator.runtimeArtifactIsPresent, "Pinned DA-V2 source package is not installed")

        let tampered = try locator.locate()
        let modelMIL = tampered.compiledModelURL.appendingPathComponent("model.mil")
        let ordinaryWrite = Darwin.open(modelMIL.path, O_WRONLY | O_TRUNC | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertEqual(ordinaryWrite, -1, "sealed compiled payload unexpectedly allowed an ordinary write")
        if ordinaryWrite >= 0 { Darwin.close(ordinaryWrite) }

        // Even code running as the same filesystem owner that deliberately
        // re-enables writes cannot make changed bytes retain pinned attribution.
        XCTAssertEqual(Darwin.chmod(modelMIL.path, 0o600), 0)
        let malicious = Data("tampered-compiled-program".utf8)
        try malicious.write(to: modelMIL)
        XCTAssertThrowsError(try tampered.verifySnapshot()) { error in
            guard case LivingStillDepthRenderError.modelSnapshotChanged = error else {
                return XCTFail("unexpected tamper error: \(error)")
            }
        }
        let tamperedRoot = tampered.snapshotRootURL
        tampered.close()
        XCTAssertFalse(fileManager.fileExists(atPath: tamperedRoot.path))

        let swapped = try locator.locate()
        let originalRoot = swapped.snapshotRootURL
        let movedRoot = originalRoot.deletingLastPathComponent().appendingPathComponent(
            originalRoot.lastPathComponent + ".moved",
            isDirectory: true
        )
        // macOS refuses to rename a mode-0500 directory carrying provenance
        // metadata. Model the same-owner attacker explicitly restoring write
        // permission before replacing the path; verification must still bind
        // the retained descriptor to the original inode and reject the swap.
        XCTAssertEqual(Darwin.chmod(originalRoot.path, 0o700), 0)
        try fileManager.moveItem(at: originalRoot, to: movedRoot)
        try fileManager.createDirectory(at: originalRoot, withIntermediateDirectories: false)
        XCTAssertThrowsError(try swapped.verifySnapshot()) { error in
            guard case LivingStillDepthRenderError.modelSnapshotChanged = error else {
                return XCTFail("unexpected swap error: \(error)")
            }
        }
        swapped.close()
        try? fileManager.removeItem(at: originalRoot)
        try? fileManager.removeItem(at: movedRoot)
    }

    func testAcquisitionVerifierRejectsArbitraryCompiledTreeNextToPinnedPackage() throws {
        let installed = LivingStillDepthModelLocator()
        try XCTSkipUnless(installed.runtimeArtifactIsPresent, "Pinned DA-V2 source package is not installed")

        let runtime = try temporaryDirectory("acquisition-script")
        defer { try? fileManager.removeItem(at: runtime) }
        let target = runtime
            .appendingPathComponent("models/apple-coreml-depth-anything-v2-small", isDirectory: true)
            .appendingPathComponent(LivingStillDepthModelLocator.sourceRevision, isDirectory: true)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        try copyPinnedPackage(from: installed.resolvedModelRoot, to: target)

        let compiled = target.appendingPathComponent(LivingStillDepthModelLocator.compiledModelName, isDirectory: true)
        try fileManager.createDirectory(at: compiled.appendingPathComponent("analytics"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: compiled.appendingPathComponent("weights"), withIntermediateDirectories: true)
        try Data("same-shape-analytics".utf8).write(to: compiled.appendingPathComponent("analytics/coremldata.bin"))
        try Data(repeating: 0x42, count: 830).write(to: compiled.appendingPathComponent("coremldata.bin"))
        try Data("[]".utf8).write(to: compiled.appendingPathComponent("metadata.json"))
        try Data("same-shape-program".utf8).write(to: compiled.appendingPathComponent("model.mil"))
        try Data("same-shape-weights".utf8).write(to: compiled.appendingPathComponent("weights/weight.bin"))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let process = Process()
        process.executableURL = repositoryRoot.appendingPathComponent("Scripts/acquire-depth-model")
        process.arguments = ["--verify-only"]
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["FRAMESMITH_RUNTIME_ROOT": runtime.path],
            uniquingKeysWith: { _, replacement in replacement }
        )
        let standardError = Pipe()
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()
        let message = String(
            decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        XCTAssertNotEqual(process.terminationStatus, 0)
        XCTAssertTrue(message.contains("integrity check failed"), message)
    }

    func testSourceHashMismatchStopsBeforeModelLookup() throws {
        let root = try temporaryDirectory("source-hash")
        defer { try? fileManager.removeItem(at: root) }
        let source = root.appendingPathComponent("source.png")
        try writeTestStill(to: source)
        let renderer = LivingStillDepthRenderer(
            modelLocator: .init(explicitModelRoot: root.appendingPathComponent("model-does-not-exist"))
        )
        let request = LivingStillDepthRenderRequest(
            sourceURL: source,
            sourceSHA256: String(repeating: "0", count: 64),
            targetWidth: 64,
            targetHeight: 64,
            durationSeconds: 1,
            fps: 1
        )
        XCTAssertThrowsError(try renderer.render(request, in: root.appendingPathComponent("output"))) { error in
            guard case LivingStillDepthRenderError.sourceHashMismatch = error else {
                return XCTFail("source was not rejected before model lookup: \(error)")
            }
        }
    }

    /// Fast installed-artifact proof. Absence is an intentional skip; a present
    /// but corrupt or provenance-mismatched artifact is a real test failure.
    func testPinnedModelRendersVerifiedVideoOnlyProRes422HQ() throws {
        let locator = LivingStillDepthModelLocator()
        try XCTSkipUnless(locator.runtimeArtifactIsPresent, "Pinned DA-V2 Small F16 runtime artifact is not installed")

        let root = try temporaryDirectory("integration")
        defer { try? fileManager.removeItem(at: root) }
        let source = root.appendingPathComponent("source.png")
        try writeTestStill(to: source)
        let sourceHash = try ContentHasher.sha256File(source)
        let request = LivingStillDepthRenderRequest(
            sourceURL: source,
            sourceSHA256: sourceHash,
            targetWidth: 64,
            targetHeight: 64,
            durationSeconds: 1,
            fps: 2,
            motionStrength: 0.5,
            pushIn: 0.025,
            panX: 0.01,
            panY: -0.005,
            depthSmoothing: 0.5,
            seed: 73
        )

        let artifact = try LivingStillDepthRenderer(modelLocator: locator).render(
            request,
            in: root.appendingPathComponent("output", isDirectory: true)
        )

        XCTAssertTrue(fileManager.fileExists(atPath: artifact.movieURL.path))
        XCTAssertEqual(artifact.movieSHA256, try ContentHasher.sha256File(artifact.movieURL))
        XCTAssertEqual(artifact.sourceSHA256, sourceHash)
        XCTAssertEqual(artifact.model.identifier, LivingStillDepthModelLocator.modelIdentifier)
        XCTAssertEqual(artifact.model.sourceRevision, LivingStillDepthModelLocator.sourceRevision)
        XCTAssertEqual(artifact.model.sourceFileHashes, LivingStillDepthModelLocator.expectedSourceFileHashes)
        XCTAssertEqual(artifact.model.inputWidth, 518)
        XCTAssertEqual(artifact.model.inputHeight, 392)
        XCTAssertEqual(artifact.codec, "prores")
        XCTAssertEqual(artifact.codecProfile, "HQ")
        XCTAssertEqual(artifact.codecFourCC, "apch")
        XCTAssertEqual(artifact.pixelFormat, "yuv422p10le")
        XCTAssertEqual(artifact.width, 64)
        XCTAssertEqual(artifact.height, 64)
        XCTAssertEqual(artifact.fps, 2)
        XCTAssertEqual(artifact.frameCount, 2)
        XCTAssertEqual(artifact.durationSeconds, 1, accuracy: 0.000_001)
        XCTAssertTrue(artifact.videoOnly)
        XCTAssertEqual(artifact.aspectPolicy, .aspectFitEdgeExtended)
        XCTAssertGreaterThanOrEqual(artifact.overscanScale, 1.08)
        XCTAssertLessThanOrEqual(artifact.maximumDepthDisplacementPixels, 64 * 0.016)
        XCTAssertEqual(artifact.depthFieldDigest.count, 64)
        XCTAssertEqual(artifact.rawDepthFieldDigest.count, 64)
        XCTAssertEqual(artifact.recipeDigest.count, 64)
        XCTAssertEqual(artifact.movieURL.lastPathComponent, "living-still-depth-\(artifact.recipeDigest.prefix(32)).mov")

        let decoded = try decodedBGRAFrames(artifact.movieURL)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertGreaterThan(meanVisibleChannel(decoded[0]), 20, "render unexpectedly collapsed to black")
        XCTAssertGreaterThan(meanAbsoluteDifference(decoded[0], decoded[1]), 0.01, "camera/depth motion unexpectedly collapsed to a frozen frame")

        let originalModificationDate = try artifact.movieURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let reused = try LivingStillDepthRenderer(modelLocator: locator).render(
            request,
            in: artifact.movieURL.deletingLastPathComponent()
        )
        XCTAssertEqual(reused.movieURL, artifact.movieURL)
        XCTAssertEqual(reused.movieSHA256, artifact.movieSHA256)
        XCTAssertEqual(
            try artifact.movieURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
            originalModificationDate,
            "content-addressed reuse overwrote the verified movie"
        )

        let entries = try fileManager.contentsOfDirectory(atPath: artifact.movieURL.deletingLastPathComponent().path)
        XCTAssertEqual(entries, [artifact.movieURL.lastPathComponent], "temporary movie was not removed after atomic publish")
    }

    private func request(
        hash: String = String(repeating: "a", count: 64),
        width: Int = 128,
        height: Int = 72,
        duration: Double = 1,
        fps: Int = 24,
        motionStrength: Double = 0.5,
        pushIn: Double = 0.04,
        panX: Double = 0.01,
        panY: Double = 0,
        smoothing: Double = 0.5,
        deterministicVersion: String = LivingStillDepthRenderRequest.currentDeterministicVersion
    ) -> LivingStillDepthRenderRequest {
        LivingStillDepthRenderRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/source.png"),
            sourceSHA256: hash,
            targetWidth: width,
            targetHeight: height,
            durationSeconds: duration,
            fps: fps,
            motionStrength: motionStrength,
            pushIn: pushIn,
            panX: panX,
            panY: panY,
            depthSmoothing: smoothing,
            seed: 9,
            deterministicVersion: deterministicVersion
        )
    }

    private func temporaryDirectory(_ label: String) throws -> URL {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("fcpcc-living-still-depth-\(label)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func copyPinnedPackage(from sourceRoot: URL, to destinationRoot: URL) throws {
        for expected in LivingStillDepthModelLocator.expectedSourceFileHashes {
            let source = sourceRoot.appendingPathComponent(expected.relativePath)
            let destination = destinationRoot.appendingPathComponent(expected.relativePath)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private func writeTestStill(to url: URL) throws {
        let width = 128
        let height = 96
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let foreground = (28..<100).contains(x) && (18..<82).contains(y)
                bytes[offset] = foreground ? UInt8(80 + x) : UInt8(15 + x / 3)
                bytes[offset + 1] = foreground ? UInt8(45 + y * 2) : UInt8(30 + y)
                bytes[offset + 2] = foreground ? 210 : UInt8(110 + x / 4)
                bytes[offset + 3] = 255
            }
        }
        let image = CIImage(
            bitmapData: Data(bytes),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        try CIContext().writePNGRepresentation(
            of: image,
            to: url,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )
    }

    private func decodedBGRAFrames(_ url: URL) throws -> [Data] {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw LivingStillDepthRenderError.movieVerificationFailed("integration movie has no video track")
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? LivingStillDepthRenderError.movieVerificationFailed("integration reader did not start")
        }
        var frames: [Data] = []
        while let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample) {
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            guard let base = CVPixelBufferGetBaseAddress(buffer) else {
                CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
                continue
            }
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
            var packed = Data(count: width * height * 4)
            packed.withUnsafeMutableBytes { destination in
                for y in 0..<height {
                    destination.baseAddress!.advanced(by: y * width * 4)
                        .copyMemory(from: base.advanced(by: y * rowBytes), byteCount: width * 4)
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            frames.append(packed)
        }
        return frames
    }

    private func meanVisibleChannel(_ frame: Data) -> Double {
        var total = 0.0
        for index in stride(from: 0, to: frame.count, by: 4) {
            total += Double(frame[index]) + Double(frame[index + 1]) + Double(frame[index + 2])
        }
        return total / Double((frame.count / 4) * 3)
    }

    private func meanAbsoluteDifference(_ lhs: Data, _ rhs: Data) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var total = 0.0
        var count = 0
        for index in stride(from: 0, to: lhs.count, by: 4) {
            total += abs(Double(lhs[index]) - Double(rhs[index]))
            total += abs(Double(lhs[index + 1]) - Double(rhs[index + 1]))
            total += abs(Double(lhs[index + 2]) - Double(rhs[index + 2]))
            count += 3
        }
        return total / Double(count)
    }
}
