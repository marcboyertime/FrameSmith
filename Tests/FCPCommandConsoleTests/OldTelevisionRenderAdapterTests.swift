import XCTest
import Darwin
@testable import FCPCommandConsoleCore

final class OldTelevisionRenderAdapterTests: XCTestCase {
    private let fileManager = FileManager.default
    private var root: URL!

    override func setUpWithError() throws {
        root = fileManager.temporaryDirectory.appendingPathComponent(
            "fcpcc-old-television-render-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root, fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
        root = nil
    }

    func testRejectsUnboundedAndNonFrameAlignedRequestsBeforeLaunchingTools() throws {
        let source = root.appendingPathComponent("placeholder.mov")
        try Data("placeholder".utf8).write(to: source)
        let digest = try ContentHasher.sha256File(source)
        let unavailable = URL(fileURLWithPath: "/definitely/not/an/executable")
        let adapter = OldTelevisionRenderAdapter(ffmpeg: unavailable, ffprobe: unavailable)

        let badIntensity = request(
            source: source,
            sha256: digest,
            intensity: 1.01
        )
        assertInvalidRequest(tryResult: { try adapter.render(badIntensity, in: root) }) {
            $0.contains("intensity")
        }

        let oddDimensions = OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: digest,
            sourceKind: .movie,
            targetWidth: 63,
            targetHeight: 36,
            duration: OldTelevisionRational(1, 2),
            frameRate: OldTelevisionRational(12)
        )
        assertInvalidRequest(tryResult: { try adapter.render(oddDimensions, in: root) }) {
            $0.contains("dimensions")
        }

        let fractionalFrame = OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: digest,
            sourceKind: .movie,
            targetWidth: 64,
            targetHeight: 36,
            duration: OldTelevisionRational(1, 10),
            frameRate: OldTelevisionRational(12)
        )
        assertInvalidRequest(tryResult: { try adapter.render(fractionalFrame, in: root) }) {
            $0.contains("whole frame")
        }
    }

    func testRejectsSourceWhoseBytesDoNotMatchAdmittedSHA() throws {
        let source = root.appendingPathComponent("source.mov")
        try Data("actual source bytes".utf8).write(to: source)
        let adapter = OldTelevisionRenderAdapter(
            ffmpeg: URL(fileURLWithPath: "/usr/bin/true"),
            ffprobe: URL(fileURLWithPath: "/usr/bin/true")
        )
        let mismatched = request(source: source, sha256: String(repeating: "a", count: 64))

        XCTAssertThrowsError(try adapter.render(mismatched, in: root)) { error in
            guard case OldTelevisionRenderError.sourceHashMismatch(let expected, let actual) = error else {
                return XCTFail("Expected sourceHashMismatch, got \(error)")
            }
            XCTAssertEqual(expected, String(repeating: "a", count: 64))
            XCTAssertEqual(actual, try? ContentHasher.sha256File(source))
        }
    }

    func test23976MovieIsRetimedToDeterministicExact30FPSVideoOnlyProRes() throws {
        try requireMediaTools()
        let source = try makeMovieFixture()
        let digest = try ContentHasher.sha256File(source)
        let request = OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: digest,
            sourceKind: .movie,
            targetWidth: 64,
            targetHeight: 36,
            duration: OldTelevisionRational(1, 2),
            frameRate: OldTelevisionRational(30),
            profile: .colorCRT,
            intensity: 1,
            scanlines: 0.75,
            noise: 0.60,
            syncInstability: 1,
            chromaticSeparation: 1,
            bloom: 0.60,
            vignette: 0.50,
            ghosting: 0.40,
            flicker: 0.40,
            seed: 0
        )
        let adapter = OldTelevisionRenderAdapter()
        let firstRoot = root.appendingPathComponent("first", isDirectory: true)
        let secondRoot = root.appendingPathComponent("second", isDirectory: true)

        let first = try adapter.render(request, in: firstRoot)
        let reused = try adapter.render(request, in: firstRoot)
        let second = try adapter.render(request, in: secondRoot)

        XCTAssertEqual(first.url, reused.url)
        XCTAssertEqual(first.sha256, reused.sha256)
        XCTAssertEqual(first.recipeDigest, second.recipeDigest)
        XCTAssertEqual(first.url.lastPathComponent, second.url.lastPathComponent)
        XCTAssertEqual(first.sha256, second.sha256, "same source bytes and recipe must encode deterministically")
        XCTAssertEqual(first.sha256, try ContentHasher.sha256File(first.url))
        XCTAssertEqual(first.codec, "prores")
        XCTAssertEqual(first.codecProfile, "HQ")
        XCTAssertEqual(first.pixelFormat, "yuv422p10le")
        XCTAssertEqual(first.width, 64)
        XCTAssertEqual(first.height, 36)
        XCTAssertEqual(first.frameRate, OldTelevisionRational(30))
        XCTAssertEqual(first.frameCount, 15)
        XCTAssertEqual(first.duration, OldTelevisionRational(1, 2))
        XCTAssertTrue(first.videoOnly)
        XCTAssertEqual(try streamTypes(first.url), ["video"])
    }

    func testStillIntensityZeroIsNearSourceAndKeepsExactTiming() throws {
        try requireMediaTools()
        let source = try makeStillFixture()
        let digest = try ContentHasher.sha256File(source)
        let request = OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: digest,
            sourceKind: .still,
            targetWidth: 64,
            targetHeight: 36,
            duration: OldTelevisionRational(1001, 6000),
            frameRate: OldTelevisionRational(24_000, 1001),
            profile: .broadcastMono,
            intensity: 0,
            scanlines: 1,
            noise: 1,
            syncInstability: 1,
            chromaticSeparation: 1,
            bloom: 1,
            vignette: 1,
            ghosting: 1,
            flicker: 1,
            seed: 42
        )

        let artifact = try OldTelevisionRenderAdapter().render(
            request,
            in: root.appendingPathComponent("still-render", isDirectory: true)
        )
        XCTAssertEqual(artifact.frameRate, OldTelevisionRational(24_000, 1001))
        XCTAssertEqual(artifact.frameCount, 4)
        XCTAssertEqual(artifact.duration, OldTelevisionRational(1001, 6000))
        XCTAssertTrue(artifact.videoOnly)

        let sourceRGB = try decodedRGBFrame(source)
        let renderedRGB = try decodedRGBFrame(artifact.url)
        XCTAssertEqual(sourceRGB.count, renderedRGB.count)
        let meanAbsoluteDifference = zip(sourceRGB, renderedRGB).reduce(0.0) {
            $0 + abs(Double($1.0) - Double($1.1))
        } / Double(sourceRGB.count)
        XCTAssertLessThan(
            meanAbsoluteDifference,
            8,
            "intensity zero should differ only by bounded ProRes 422 encode loss"
        )
    }

    func testCorruptExistingContentAddressIsRejectedWithoutOverwrite() throws {
        try requireMediaTools()
        let source = try makeStillFixture()
        let digest = try ContentHasher.sha256File(source)
        let request = OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: digest,
            sourceKind: .still,
            targetWidth: 64,
            targetHeight: 36,
            duration: OldTelevisionRational(1, 4),
            frameRate: OldTelevisionRational(8),
            intensity: 0.4
        )
        let outputRoot = root.appendingPathComponent("corruption", isDirectory: true)
        let adapter = OldTelevisionRenderAdapter()
        let artifact = try adapter.render(request, in: outputRoot)

        let corrupt = Data("not a movie and must not be replaced".utf8)
        try corrupt.write(to: artifact.url, options: .atomic)
        let corruptDigest = try ContentHasher.sha256File(artifact.url)

        XCTAssertThrowsError(try adapter.render(request, in: outputRoot)) { error in
            guard case OldTelevisionRenderError.existingArtifactRejected(let url, _) = error else {
                return XCTFail("Expected existingArtifactRejected, got \(error)")
            }
            XCTAssertEqual(url, artifact.url)
        }
        XCTAssertEqual(try ContentHasher.sha256File(artifact.url), corruptDigest)
    }

    func testSourceMutationDuringRenderCannotChangePixelsBoundToAdmittedHash() async throws {
        try requireMediaTools()
        let source = try makeSolidStillFixture(named: "admitted-red.png", color: "red")
        let redReference = try makeSolidStillFixture(named: "red-reference.png", color: "red")
        let blueReplacement = try makeSolidStillFixture(named: "blue-replacement.png", color: "blue")
        let admittedHash = try ContentHasher.sha256File(source)
        let marker = root.appendingPathComponent("render-entered.marker")
        let release = root.appendingPathComponent("release-render.marker")
        let wrappedFFmpeg = root.appendingPathComponent("ffmpeg-source-race")
        try writeExecutable(
            at: wrappedFFmpeg,
            script: blockingFFmpegScript(marker: marker, release: release)
        )

        let adapter = OldTelevisionRenderAdapter(
            ffmpeg: wrappedFFmpeg,
            ffprobe: OldTelevisionRenderAdapter.ffprobeURL
        )
        let request = stillRequest(source: source, sha256: admittedHash)
        let outputRoot = root.appendingPathComponent("source-race-output", isDirectory: true)
        let renderTask = Task.detached {
            try adapter.render(request, in: outputRoot)
        }

        do {
            try await waitForFile(marker)
            // The admitted pathname now names visibly different valid media.
            // A path-based render would consume blue while still carrying the
            // already-accepted SHA-256 of the red source.
            try Data(contentsOf: blueReplacement).write(to: source, options: .atomic)
            try Data().write(to: release, options: .atomic)
        } catch {
            renderTask.cancel()
            try? Data().write(to: release, options: .atomic)
            _ = try? await renderTask.value
            throw error
        }

        let artifact = try await renderTask.value
        let renderedRGB = try decodedRGBFrame(artifact.url)
        let admittedRGB = try decodedRGBFrame(redReference)
        let replacementRGB = try decodedRGBFrame(blueReplacement)
        XCTAssertLessThan(
            meanAbsoluteDifference(renderedRGB, admittedRGB),
            8,
            "render must consume the verified red snapshot, not later blue pathname bytes"
        )
        XCTAssertGreaterThan(
            meanAbsoluteDifference(renderedRGB, replacementRGB),
            50,
            "the adversarial replacement must be visually distinguishable"
        )
    }

    func testExecutableMutationAfterIdentityCannotChangeExecutedRenderer() async throws {
        try requireMediaTools()
        let source = try makeSolidStillFixture(named: "tool-race-source.png", color: "green")
        let admittedHash = try ContentHasher.sha256File(source)
        let mutableFFmpeg = root.appendingPathComponent("ffmpeg-mutable")
        try writeExecutable(
            at: mutableFFmpeg,
            script: "#!/bin/sh\nexec \(shellQuote(OldTelevisionRenderAdapter.ffmpegURL.path)) \"$@\"\n"
        )

        let marker = root.appendingPathComponent("source-probe-entered.marker")
        let release = root.appendingPathComponent("release-source-probe.marker")
        let blockingFFprobe = root.appendingPathComponent("ffprobe-blocking")
        try writeExecutable(
            at: blockingFFprobe,
            script: blockingForwarderScript(
                realExecutable: OldTelevisionRenderAdapter.ffprobeURL,
                marker: marker,
                release: release
            )
        )

        let adapter = OldTelevisionRenderAdapter(
            ffmpeg: mutableFFmpeg,
            ffprobe: blockingFFprobe
        )
        let request = stillRequest(source: source, sha256: admittedHash)
        let outputRoot = root.appendingPathComponent("tool-race-output", isDirectory: true)
        let renderTask = Task.detached {
            try adapter.render(request, in: outputRoot)
        }

        do {
            // Source probing begins only after the adapter has hashed and
            // versioned its sealed tool snapshots. Replace the admitted
            // ffmpeg pathname before the actual render launch.
            try await waitForFile(marker)
            try writeExecutable(at: mutableFFmpeg, script: "#!/bin/sh\nexit 93\n")
            try Data().write(to: release, options: .atomic)
        } catch {
            renderTask.cancel()
            try? Data().write(to: release, options: .atomic)
            _ = try? await renderTask.value
            throw error
        }

        let artifact = try await renderTask.value
        XCTAssertEqual(artifact.sha256, try ContentHasher.sha256File(artifact.url))
        XCTAssertEqual(artifact.codecProfile, "HQ")
        XCTAssertEqual(try streamTypes(artifact.url), ["video"])
    }

    // MARK: - Fixtures and assertions

    private func request(
        source: URL,
        sha256: String,
        intensity: Double = 0.65
    ) -> OldTelevisionRenderRequest {
        OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: sha256,
            sourceKind: .movie,
            targetWidth: 64,
            targetHeight: 36,
            duration: OldTelevisionRational(1, 2),
            frameRate: OldTelevisionRational(12),
            intensity: intensity
        )
    }

    private func stillRequest(source: URL, sha256: String) -> OldTelevisionRenderRequest {
        OldTelevisionRenderRequest(
            sourceURL: source,
            sourceSHA256: sha256,
            sourceKind: .still,
            targetWidth: 64,
            targetHeight: 36,
            duration: OldTelevisionRational(1, 4),
            frameRate: OldTelevisionRational(8),
            intensity: 0
        )
    }

    private func assertInvalidRequest(
        tryResult: () throws -> OldTelevisionRenderArtifact,
        messageMatches: (String) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try tryResult(), file: file, line: line) { error in
            guard case OldTelevisionRenderError.invalidRequest(let message) = error else {
                return XCTFail("Expected invalidRequest, got \(error)", file: file, line: line)
            }
            XCTAssertTrue(messageMatches(message), "Unexpected message: \(message)", file: file, line: line)
        }
    }

    private func requireMediaTools() throws {
        try XCTSkipUnless(
            fileManager.isExecutableFile(atPath: OldTelevisionRenderAdapter.ffmpegURL.path) &&
                fileManager.isExecutableFile(atPath: OldTelevisionRenderAdapter.ffprobeURL.path),
            "Homebrew ffmpeg/ffprobe unavailable"
        )
    }

    private func makeMovieFixture() throws -> URL {
        let output = root.appendingPathComponent("fixture-with-audio.mkv")
        _ = try run(
            OldTelevisionRenderAdapter.ffmpegURL,
            arguments: [
                "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=64x36:rate=24000/1001:duration=0.501",
                "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=0.501",
                "-map", "0:v:0", "-map", "1:a:0",
                "-c:v", "ffv1", "-pix_fmt", "yuv444p10le",
                "-c:a", "pcm_s16le", "-shortest", output.path
            ]
        )
        return output
    }

    private func makeStillFixture() throws -> URL {
        let output = root.appendingPathComponent("fixture.png")
        _ = try run(
            OldTelevisionRenderAdapter.ffmpegURL,
            arguments: [
                "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                "-f", "lavfi", "-i", "testsrc2=size=64x36:rate=1:duration=1",
                "-frames:v", "1", output.path
            ]
        )
        return output
    }

    private func makeSolidStillFixture(named name: String, color: String) throws -> URL {
        let output = root.appendingPathComponent(name)
        _ = try run(
            OldTelevisionRenderAdapter.ffmpegURL,
            arguments: [
                "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                "-f", "lavfi", "-i", "color=c=\(color):size=64x36:rate=1:duration=1",
                "-frames:v", "1", output.path
            ]
        )
        return output
    }

    private func blockingFFmpegScript(marker: URL, release: URL) -> String {
        """
        #!/bin/sh
        for argument in "$@"; do
          if [ "$argument" = "-filter_complex" ]; then
            : > \(shellQuote(marker.path))
            while [ ! -e \(shellQuote(release.path)) ]; do /bin/sleep 0.01; done
            break
          fi
        done
        exec \(shellQuote(OldTelevisionRenderAdapter.ffmpegURL.path)) "$@"
        """
    }

    private func blockingForwarderScript(
        realExecutable: URL,
        marker: URL,
        release: URL
    ) -> String {
        """
        #!/bin/sh
        : > \(shellQuote(marker.path))
        while [ ! -e \(shellQuote(release.path)) ]; do /bin/sleep 0.01; done
        exec \(shellQuote(realExecutable.path)) "$@"
        """
    }

    private func writeExecutable(at url: URL, script: String) throws {
        try Data(script.utf8).write(to: url, options: .atomic)
        guard Darwin.chmod(url.path, S_IRWXU) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if fileManager.fileExists(atPath: url.path) { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw NSError(
            domain: "OldTelevisionRenderAdapterTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(url.lastPathComponent)"]
        )
    }

    private func meanAbsoluteDifference(_ lhs: Data, _ rhs: Data) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return .infinity }
        return zip(lhs, rhs).reduce(0.0) {
            $0 + abs(Double($1.0) - Double($1.1))
        } / Double(lhs.count)
    }

    private func streamTypes(_ url: URL) throws -> [String] {
        let data = try run(
            OldTelevisionRenderAdapter.ffprobeURL,
            arguments: [
                "-v", "error", "-show_entries", "stream=codec_type",
                "-of", "default=nw=1:nk=1", url.path
            ]
        )
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: { $0.isNewline })
            .map(String.init)
    }

    private func decodedRGBFrame(_ url: URL) throws -> Data {
        try run(
            OldTelevisionRenderAdapter.ffmpegURL,
            arguments: [
                "-hide_banner", "-loglevel", "error", "-nostdin",
                "-i", url.path, "-map", "0:v:0", "-frames:v", "1",
                "-f", "rawvideo", "-pix_fmt", "rgb24", "-"
            ]
        )
    }

    @discardableResult
    private func run(_ executable: URL, arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorText = String(
            decoding: stderr.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "OldTelevisionRenderAdapterTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorText]
            )
        }
        return output
    }
}
