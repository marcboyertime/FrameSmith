import Foundation
import Darwin

/// An exact positive rational used for both frame rate and duration.
///
/// Keeping these values rational prevents `29.97`-style approximations from
/// quietly changing the frame count or the timestamps written to the render.
public struct OldTelevisionRational: Codable, Equatable, Hashable, Sendable {
    public let numerator: Int64
    public let denominator: Int64

    public init(_ numerator: Int64, _ denominator: Int64 = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public var doubleValue: Double {
        Double(numerator) / Double(denominator)
    }

    fileprivate func normalized(named name: String) throws -> Self {
        guard numerator > 0, denominator > 0 else {
            throw OldTelevisionRenderError.invalidRequest("\(name) must be a positive rational")
        }
        let divisor = Self.greatestCommonDivisor(numerator, denominator)
        return Self(numerator / divisor, denominator / divisor)
    }

    private static func greatestCommonDivisor(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return a
    }
}

public enum OldTelevisionSourceKind: String, Codable, CaseIterable, Sendable {
    case still
    case movie
}

public enum OldTelevisionProfile: String, Codable, CaseIterable, Sendable {
    case broadcastMono = "broadcast_mono"
    case colorCRT = "color_crt"
}

/// A closed, bounded request for a rendered CRT treatment.
///
/// Every creative control is normalized to `0...1`. The adapter owns the
/// actual FFmpeg graph and maps these controls to conservative, measured
/// ranges; callers cannot inject filters or process arguments.
public struct OldTelevisionRenderRequest: Codable, Equatable, Sendable {
    public let sourceURL: URL
    public let sourceSHA256: String
    public let sourceKind: OldTelevisionSourceKind
    public let targetWidth: Int
    public let targetHeight: Int
    public let duration: OldTelevisionRational
    public let frameRate: OldTelevisionRational
    public let profile: OldTelevisionProfile
    public let intensity: Double
    public let scanlines: Double
    public let noise: Double
    public let syncInstability: Double
    public let chromaticSeparation: Double
    public let bloom: Double
    public let vignette: Double
    public let ghosting: Double
    public let flicker: Double
    public let seed: Int

    public init(
        sourceURL: URL,
        sourceSHA256: String,
        sourceKind: OldTelevisionSourceKind,
        targetWidth: Int,
        targetHeight: Int,
        duration: OldTelevisionRational,
        frameRate: OldTelevisionRational,
        profile: OldTelevisionProfile = .broadcastMono,
        intensity: Double = 0.65,
        scanlines: Double = 0.55,
        noise: Double = 0.30,
        syncInstability: Double = 0.25,
        chromaticSeparation: Double = 0.15,
        bloom: Double = 0.22,
        vignette: Double = 0.20,
        ghosting: Double = 0.15,
        flicker: Double = 0.15,
        seed: Int = 1977
    ) {
        self.sourceURL = sourceURL
        self.sourceSHA256 = sourceSHA256
        self.sourceKind = sourceKind
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.duration = duration
        self.frameRate = frameRate
        self.profile = profile
        self.intensity = intensity
        self.scanlines = scanlines
        self.noise = noise
        self.syncInstability = syncInstability
        self.chromaticSeparation = chromaticSeparation
        self.bloom = bloom
        self.vignette = vignette
        self.ghosting = ghosting
        self.flicker = flicker
        self.seed = seed
    }
}

/// The verified immutable render consumed by preview and export.
public struct OldTelevisionRenderArtifact: Codable, Equatable, Sendable {
    public let url: URL
    public let sha256: String
    public let recipeDigest: String
    public let codec: String
    public let codecProfile: String
    public let pixelFormat: String
    public let width: Int
    public let height: Int
    public let frameRate: OldTelevisionRational
    public let frameCount: Int
    public let duration: OldTelevisionRational
    public let videoOnly: Bool

    fileprivate init(
        url: URL,
        sha256: String,
        recipeDigest: String,
        codec: String,
        codecProfile: String,
        pixelFormat: String,
        width: Int,
        height: Int,
        frameRate: OldTelevisionRational,
        frameCount: Int,
        duration: OldTelevisionRational
    ) {
        self.url = url
        self.sha256 = sha256
        self.recipeDigest = recipeDigest
        self.codec = codec
        self.codecProfile = codecProfile
        self.pixelFormat = pixelFormat
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.frameCount = frameCount
        self.duration = duration
        self.videoOnly = true
    }
}

public enum OldTelevisionRenderError: Error, LocalizedError, Equatable, Sendable {
    case invalidRequest(String)
    case sourceMissing(URL)
    case sourceHashMismatch(expected: String, actual: String)
    case sourceRejected(String)
    case toolMissing(URL)
    case toolFailed(URL, status: Int32, message: String)
    case toolTimedOut(URL, seconds: Int)
    case verificationFailed(String)
    case existingArtifactRejected(URL, reason: String)
    case publicationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let reason):
            return "Invalid Old Television render request: \(reason)"
        case .sourceMissing(let url):
            return "Old Television source is missing or unreadable: \(url.path)"
        case .sourceHashMismatch(let expected, let actual):
            return "Old Television source SHA-256 mismatch (expected \(expected), found \(actual))"
        case .sourceRejected(let reason):
            return "Old Television source was rejected: \(reason)"
        case .toolMissing(let url):
            return "Required Old Television media tool is missing: \(url.path)"
        case .toolFailed(let url, let status, let message):
            return "\(url.lastPathComponent) failed with status \(status): \(message)"
        case .toolTimedOut(let url, let seconds):
            return "\(url.lastPathComponent) exceeded the \(seconds)-second limit"
        case .verificationFailed(let reason):
            return "Old Television render verification failed: \(reason)"
        case .existingArtifactRejected(let url, let reason):
            return "Existing Old Television artifact was rejected at \(url.path): \(reason)"
        case .publicationFailed(let reason):
            return "Old Television render could not be published: \(reason)"
        }
    }
}

/// Deterministic local renderer for the production Old Television treatment.
///
/// The output is deliberately opaque, video-only ProRes 422 HQ 10-bit. It is
/// intended to sit above the unchanged source clip: the spine therefore keeps
/// the director's original source identity and audio while this file supplies
/// only the visual treatment.
public struct OldTelevisionRenderAdapter: Sendable {
    public static let ffmpegURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    public static let ffprobeURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
    public static let rendererVersion = "fcpcommandconsole-old-television-render-v1"

    public let ffmpeg: URL
    public let ffprobe: URL

    public init(
        ffmpeg: URL = OldTelevisionRenderAdapter.ffmpegURL,
        ffprobe: URL = OldTelevisionRenderAdapter.ffprobeURL
    ) {
        self.ffmpeg = ffmpeg
        self.ffprobe = ffprobe
    }

    /// Renders or safely reuses a verified content-addressed artifact.
    ///
    /// Existing files are never overwritten. A valid file at the deterministic
    /// address is reused; a corrupt or mismatched one causes a hard failure.
    public func render(
        _ request: OldTelevisionRenderRequest,
        in outputRoot: URL
    ) throws -> OldTelevisionRenderArtifact {
        let validated = try validate(request)
        let fileManager = FileManager.default
        let source = try canonicalSource(request.sourceURL)
        return try withSealedInputs(source: source) { sealed in
            // Hash the exact private source snapshot that every later probe and
            // render consumes. Mutating or replacing the admitted pathname can
            // no longer change pixels after this identity check.
            let actualSourceHash = try ContentHasher.sha256File(sealed.source).lowercased()
            guard actualSourceHash == validated.sourceSHA256 else {
                throw OldTelevisionRenderError.sourceHashMismatch(
                    expected: validated.sourceSHA256,
                    actual: actualSourceHash
                )
            }

            // Tool identity is likewise derived from, and executed through, the
            // same verified snapshots used for all subsequent work.
            let toolIdentity = try toolIdentity(
                ffmpegExecutable: sealed.ffmpeg,
                ffprobeExecutable: sealed.ffprobe
            )
            let sourceProbe = try probe(
                sealed.source,
                countFrames: validated.sourceKind == .still,
                timeout: validated.sourceKind == .still ? 30 : 20,
                executable: sealed.ffprobe
            )
            try validateSource(sourceProbe, for: validated)

            let recipe = Recipe(validated: validated, tools: toolIdentity)
            let recipeDigest = try StablePlanHasher.hashJSON(recipe)
            let root = try prepareOutputRoot(outputRoot)
            let filename = "old-television-\(validated.profile.rawValue)-\(recipeDigest.prefix(32)).mov"
            let output = root.appendingPathComponent(filename, isDirectory: false)
            let policy = PathPolicy(allowedInputRoots: [], outputRoot: root)
            _ = try policy.validateOutput(output, overwrite: true)

            if fileManager.fileExists(atPath: output.path) {
                do {
                    return try verify(
                        output,
                        validated: validated,
                        recipeDigest: recipeDigest,
                        ffprobeExecutable: sealed.ffprobe
                    )
                } catch {
                    throw OldTelevisionRenderError.existingArtifactRejected(
                        output,
                        reason: error.localizedDescription
                    )
                }
            }

            let temporary = root.appendingPathComponent(
                ".tmp-old-television-\(recipeDigest)-\(UUID().uuidString).mov",
                isDirectory: false
            )
            _ = try policy.validateOutput(temporary)
            defer {
                if fileManager.fileExists(atPath: temporary.path) {
                    try? fileManager.removeItem(at: temporary)
                }
            }

            let graph = filterGraph(for: validated)
            let arguments = renderArguments(
                source: sealed.source,
                temporary: temporary,
                validated: validated,
                recipeDigest: recipeDigest,
                filterGraph: graph
            )
            try runRender(
                executable: sealed.ffmpeg,
                arguments: arguments,
                timeout: renderTimeout(for: validated)
            )
            guard fileManager.fileExists(atPath: temporary.path) else {
                throw OldTelevisionRenderError.verificationFailed("FFmpeg produced no output file")
            }

            // Verify before publication, then atomically move on the same filesystem.
            _ = try verify(
                temporary,
                validated: validated,
                recipeDigest: recipeDigest,
                ffprobeExecutable: sealed.ffprobe
            )
            do {
                try fileManager.moveItem(at: temporary, to: output)
            } catch {
                // Another renderer may have won the same content-addressed race. Its
                // result is acceptable only if it independently passes every check.
                if fileManager.fileExists(atPath: output.path) {
                    do {
                        return try verify(
                            output,
                            validated: validated,
                            recipeDigest: recipeDigest,
                            ffprobeExecutable: sealed.ffprobe
                        )
                    } catch {
                        throw OldTelevisionRenderError.existingArtifactRejected(
                            output,
                            reason: error.localizedDescription
                        )
                    }
                }
                throw OldTelevisionRenderError.publicationFailed(error.localizedDescription)
            }
            return try verify(
                output,
                validated: validated,
                recipeDigest: recipeDigest,
                ffprobeExecutable: sealed.ffprobe
            )
        }
    }

    // MARK: - Validation

    private struct ValidatedRequest: Sendable {
        let sourceSHA256: String
        let sourceKind: OldTelevisionSourceKind
        let width: Int
        let height: Int
        let duration: OldTelevisionRational
        let frameRate: OldTelevisionRational
        let frameCount: Int
        let profile: OldTelevisionProfile
        let intensity: Double
        let scanlines: Double
        let noise: Double
        let syncInstability: Double
        let chromaticSeparation: Double
        let bloom: Double
        let vignette: Double
        let ghosting: Double
        let flicker: Double
        let seed: Int
    }

    private func validate(_ request: OldTelevisionRenderRequest) throws -> ValidatedRequest {
        guard request.sourceURL.isFileURL else {
            throw OldTelevisionRenderError.invalidRequest("sourceURL must be a local file URL")
        }
        let sourceHash = request.sourceSHA256.lowercased()
        guard sourceHash.count == 64,
              sourceHash.unicodeScalars.allSatisfy({
                  (48...57).contains($0.value) || (97...102).contains($0.value)
              }) else {
            throw OldTelevisionRenderError.invalidRequest("sourceSHA256 must contain exactly 64 hexadecimal characters")
        }
        guard (16...8192).contains(request.targetWidth),
              (16...4320).contains(request.targetHeight),
              request.targetWidth.isMultiple(of: 2),
              request.targetHeight.isMultiple(of: 2) else {
            throw OldTelevisionRenderError.invalidRequest(
                "target dimensions must be even and inside 16...8192 by 16...4320"
            )
        }

        let duration = try request.duration.normalized(named: "duration")
        let frameRate = try request.frameRate.normalized(named: "frameRate")
        let fps = frameRate.doubleValue
        let seconds = duration.doubleValue
        guard fps.isFinite, (1...120).contains(fps) else {
            throw OldTelevisionRenderError.invalidRequest("frameRate must be inside 1...120 fps")
        }
        guard seconds.isFinite, seconds > 0, seconds <= 300 else {
            throw OldTelevisionRenderError.invalidRequest("duration must be greater than zero and no longer than 300 seconds")
        }
        guard frameRate.numerator <= Int64(Int32.max) else {
            throw OldTelevisionRenderError.invalidRequest("frameRate numerator is too large for a QuickTime timescale")
        }

        let first = duration.numerator.multipliedReportingOverflow(by: frameRate.numerator)
        let second = duration.denominator.multipliedReportingOverflow(by: frameRate.denominator)
        guard !first.overflow, !second.overflow, second.partialValue > 0,
              first.partialValue % second.partialValue == 0 else {
            throw OldTelevisionRenderError.invalidRequest(
                "duration must resolve to an exact whole frame count at frameRate"
            )
        }
        let count = first.partialValue / second.partialValue
        guard count > 0, count <= 36_000, count <= Int64(Int.max) else {
            throw OldTelevisionRenderError.invalidRequest("render frame count must be inside 1...36000")
        }

        let controls: [(String, Double)] = [
            ("intensity", request.intensity),
            ("scanlines", request.scanlines),
            ("noise", request.noise),
            ("syncInstability", request.syncInstability),
            ("chromaticSeparation", request.chromaticSeparation),
            ("bloom", request.bloom),
            ("vignette", request.vignette),
            ("ghosting", request.ghosting),
            ("flicker", request.flicker)
        ]
        for (name, value) in controls {
            guard value.isFinite, (0...1).contains(value) else {
                throw OldTelevisionRenderError.invalidRequest("\(name) must be a finite value inside 0...1")
            }
        }
        guard (0...Int(Int32.max)).contains(request.seed) else {
            throw OldTelevisionRenderError.invalidRequest("seed must be inside 0...\(Int32.max)")
        }

        return ValidatedRequest(
            sourceSHA256: sourceHash,
            sourceKind: request.sourceKind,
            width: request.targetWidth,
            height: request.targetHeight,
            duration: duration,
            frameRate: frameRate,
            frameCount: Int(count),
            profile: request.profile,
            intensity: canonicalZero(request.intensity),
            scanlines: canonicalZero(request.scanlines),
            noise: canonicalZero(request.noise),
            syncInstability: canonicalZero(request.syncInstability),
            chromaticSeparation: canonicalZero(request.chromaticSeparation),
            bloom: canonicalZero(request.bloom),
            vignette: canonicalZero(request.vignette),
            ghosting: canonicalZero(request.ghosting),
            flicker: canonicalZero(request.flicker),
            seed: request.seed
        )
    }

    private func canonicalZero(_ value: Double) -> Double {
        value == 0 ? 0 : value
    }

    private func canonicalSource(_ source: URL) throws -> URL {
        let fileManager = FileManager.default
        let resolved = source.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: resolved.path) else {
            throw OldTelevisionRenderError.sourceMissing(source)
        }
        let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else {
            throw OldTelevisionRenderError.sourceMissing(source)
        }
        return resolved
    }

    // MARK: - Sealed inputs

    /// Private, per-render snapshots close pathname races for both admitted
    /// media and the executables whose hashes enter the recipe identity.
    private struct SealedInputs {
        let root: URL
        let source: URL
        let ffmpeg: URL
        let ffprobe: URL
    }

    private func withSealedInputs<T>(
        source: URL,
        _ body: (SealedInputs) throws -> T
    ) throws -> T {
        let fileManager = FileManager.default
        let root = try makePrivateTemporaryRoot()
        defer { try? fileManager.removeItem(at: root) }

        let extensionScalars = source.pathExtension.unicodeScalars
        let safeExtension = !extensionScalars.isEmpty && extensionScalars.count <= 16 &&
            extensionScalars.allSatisfy {
                (48...57).contains($0.value) ||
                    (65...90).contains($0.value) ||
                    (97...122).contains($0.value)
            } ? source.pathExtension.lowercased() : "media"
        let sealedSource = root
            .appendingPathComponent("source", isDirectory: false)
            .appendingPathExtension(safeExtension)
        do {
            try snapshotRegularFile(from: source, to: sealedSource, mode: S_IRUSR)
        } catch {
            throw OldTelevisionRenderError.sourceMissing(source)
        }

        let sourceFFmpeg = try canonicalExecutable(ffmpeg)
        let sourceFFprobe = try canonicalExecutable(ffprobe)
        let sealedFFmpeg = root.appendingPathComponent("ffmpeg", isDirectory: false)
        let sealedFFprobe = root.appendingPathComponent("ffprobe", isDirectory: false)
        do {
            try snapshotRegularFile(
                from: sourceFFmpeg,
                to: sealedFFmpeg,
                mode: S_IRUSR | S_IXUSR
            )
        } catch {
            throw OldTelevisionRenderError.toolFailed(
                ffmpeg,
                status: -1,
                message: "could not create verified executable snapshot: \(error.localizedDescription)"
            )
        }
        do {
            try snapshotRegularFile(
                from: sourceFFprobe,
                to: sealedFFprobe,
                mode: S_IRUSR | S_IXUSR
            )
        } catch {
            throw OldTelevisionRenderError.toolFailed(
                ffprobe,
                status: -1,
                message: "could not create verified executable snapshot: \(error.localizedDescription)"
            )
        }

        return try body(
            SealedInputs(
                root: root,
                source: sealedSource,
                ffmpeg: sealedFFmpeg,
                ffprobe: sealedFFprobe
            )
        )
    }

    private func canonicalExecutable(_ executable: URL) throws -> URL {
        guard executable.isFileURL else {
            throw OldTelevisionRenderError.toolMissing(executable)
        }
        let fileManager = FileManager.default
        let resolved = executable.resolvingSymlinksInPath().standardizedFileURL
        let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true,
              fileManager.isExecutableFile(atPath: resolved.path) else {
            throw OldTelevisionRenderError.toolMissing(executable)
        }
        return resolved
    }

    private func makePrivateTemporaryRoot() throws -> URL {
        let parent = FileManager.default.temporaryDirectory.standardizedFileURL
        var template = Array(
            parent.appendingPathComponent("fcpcc-old-television-sealed.XXXXXX").path.utf8CString
        )
        let createdPath = template.withUnsafeMutableBufferPointer { buffer -> String? in
            guard let baseAddress = buffer.baseAddress,
                  let created = mkdtemp(baseAddress) else { return nil }
            return String(cString: created)
        }
        guard let createdPath else {
            throw OldTelevisionRenderError.verificationFailed(
                "could not create a private sealed-input directory: \(String(cString: strerror(errno)))"
            )
        }
        guard Darwin.chmod(createdPath, S_IRWXU) == 0 else {
            try? FileManager.default.removeItem(atPath: createdPath)
            throw OldTelevisionRenderError.verificationFailed(
                "could not protect the sealed-input directory: \(String(cString: strerror(errno)))"
            )
        }
        return URL(fileURLWithPath: createdPath, isDirectory: true)
    }

    /// Copies through an already-open regular-file descriptor. Replacing a
    /// source pathname during the copy cannot redirect the operation; an
    /// in-place mutation can only yield bytes whose later digest must match.
    private func snapshotRegularFile(from source: URL, to destination: URL, mode: mode_t) throws {
        let sourceDescriptor = Darwin.open(source.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard sourceDescriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let sourceHandle = FileHandle(fileDescriptor: sourceDescriptor, closeOnDealloc: true)
        defer { try? sourceHandle.close() }

        var sourceStatus = stat()
        guard fstat(sourceDescriptor, &sourceStatus) == 0,
              sourceStatus.st_mode & S_IFMT == S_IFREG else {
            throw POSIXError(.EINVAL)
        }

        let destinationDescriptor = Darwin.open(
            destination.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            S_IRUSR | S_IWUSR
        )
        guard destinationDescriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let destinationHandle = FileHandle(fileDescriptor: destinationDescriptor, closeOnDealloc: true)
        var published = false
        defer {
            try? destinationHandle.close()
            if !published { try? FileManager.default.removeItem(at: destination) }
        }

        while let chunk = try sourceHandle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try destinationHandle.write(contentsOf: chunk)
        }
        try destinationHandle.synchronize()
        guard Darwin.fchmod(destinationDescriptor, mode) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try destinationHandle.close()
        published = true
    }

    private func prepareOutputRoot(_ requestedRoot: URL) throws -> URL {
        guard requestedRoot.isFileURL else {
            throw OldTelevisionRenderError.invalidRequest("output root must be a local file URL")
        }
        let fileManager = FileManager.default
        let lexical = requestedRoot.standardizedFileURL
        guard lexical.path != "/" else {
            throw OldTelevisionRenderError.invalidRequest("filesystem root cannot be used as the render output root")
        }
        do {
            try fileManager.createDirectory(at: lexical, withIntermediateDirectories: true)
        } catch {
            throw OldTelevisionRenderError.publicationFailed(error.localizedDescription)
        }
        let root = lexical.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              fileManager.isWritableFile(atPath: root.path) else {
            throw OldTelevisionRenderError.publicationFailed("output root is not a writable directory")
        }
        return root
    }

    // MARK: - Canonical recipe

    private struct ToolIdentity: Codable, Equatable, Sendable {
        let ffmpegVersion: String
        let ffmpegSHA256: String
        let ffprobeSHA256: String
    }

    private struct Recipe: Codable, Equatable, Sendable {
        let rendererVersion: String
        let sourceSHA256: String
        let sourceKind: OldTelevisionSourceKind
        let width: Int
        let height: Int
        let duration: OldTelevisionRational
        let frameRate: OldTelevisionRational
        let profile: OldTelevisionProfile
        let intensity: Double
        let scanlines: Double
        let noise: Double
        let syncInstability: Double
        let chromaticSeparation: Double
        let bloom: Double
        let vignette: Double
        let ghosting: Double
        let flicker: Double
        let seed: Int
        let tools: ToolIdentity

        init(validated: ValidatedRequest, tools: ToolIdentity) {
            rendererVersion = OldTelevisionRenderAdapter.rendererVersion
            sourceSHA256 = validated.sourceSHA256
            sourceKind = validated.sourceKind
            width = validated.width
            height = validated.height
            duration = validated.duration
            frameRate = validated.frameRate
            profile = validated.profile
            intensity = validated.intensity
            scanlines = validated.scanlines
            noise = validated.noise
            syncInstability = validated.syncInstability
            chromaticSeparation = validated.chromaticSeparation
            bloom = validated.bloom
            vignette = validated.vignette
            ghosting = validated.ghosting
            flicker = validated.flicker
            seed = validated.seed
            self.tools = tools
        }
    }

    private func toolIdentity(
        ffmpegExecutable: URL,
        ffprobeExecutable: URL
    ) throws -> ToolIdentity {
        let ffmpegHash = try ContentHasher.sha256File(ffmpegExecutable)
        let ffprobeHash = try ContentHasher.sha256File(ffprobeExecutable)
        let versionData = try runCapture(
            executable: ffmpegExecutable,
            reportedAs: ffmpeg,
            arguments: ["-hide_banner", "-version"],
            timeout: 10
        )
        guard let firstLine = String(decoding: versionData, as: UTF8.self)
            .split(whereSeparator: { $0.isNewline })
            .first.map(String.init),
              !firstLine.isEmpty else {
            throw OldTelevisionRenderError.verificationFailed("FFmpeg returned no version identity")
        }
        return ToolIdentity(
            ffmpegVersion: firstLine,
            ffmpegSHA256: ffmpegHash,
            ffprobeSHA256: ffprobeHash
        )
    }

    // MARK: - Filter graph

    /// Builds the closed graph. All numeric fragments come from bounded values,
    /// and no string supplied by a caller is interpolated into the graph.
    private func filterGraph(for request: ValidatedRequest) -> String {
        var filters: [String] = []
        var stage = 0
        var current = "crt\(stage)"

        let rate = "\(request.frameRate.numerator)/\(request.frameRate.denominator)"
        let setPTS = "N*\(request.frameRate.denominator)/(\(request.frameRate.numerator)*TB)"
        var inputTiming = "setpts=PTS-STARTPTS"
        if request.sourceKind == .movie {
            // Movie sources may have any valid decodable cadence. Convert them
            // explicitly to the requested CFR, allow at most one cloned terminal
            // frame for EOF rounding, and trim to the exact locked frame count.
            inputTiming += ",fps=fps=\(rate):start_time=0:round=near:eof_action=pass," +
                "tpad=stop=1:stop_mode=clone"
        }
        inputTiming += ",trim=start_frame=0:end_frame=\(request.frameCount),setpts='\(setPTS)'"
        filters.append(
            "[0:v:0]scale=w=\(request.width):h=\(request.height):flags=lanczos," +
            "setsar=1,format=yuv444p10le,\(inputTiming)[\(current)]"
        )

        func append(_ filter: String) {
            stage += 1
            let next = "crt\(stage)"
            filters.append("[\(current)]\(filter)[\(next)]")
            current = next
        }

        // Intensity zero is intentionally a clean scale/encode path. This keeps
        // A/B validation meaningful and avoids hidden baseline styling.
        if request.intensity > 0 {
            let profileSaturation: Double
            switch request.profile {
            case .broadcastMono:
                profileSaturation = max(0.04, 1 - 1.35 * request.intensity)
            case .colorCRT:
                profileSaturation = 1 - 0.22 * request.intensity
            }
            let contrast = 1 + 0.12 * request.intensity
            let flickerAmplitude = 0.020 * request.intensity * request.flicker
            let timeScale = Double(request.frameRate.denominator) / Double(request.frameRate.numerator)
            let flickerExpression =
                "\(decimal(flickerAmplitude))*(0.52*sin(2*PI*n*7.13*\(decimal(timeScale)))" +
                "+0.31*sin(2*PI*n*3.71*\(decimal(timeScale))+0.9)" +
                "+0.17*sin(2*PI*n*11.17*\(decimal(timeScale))+2.1))"
            append(
                "eq=contrast=\(decimal(contrast)):saturation=\(decimal(profileSaturation)):" +
                "brightness='\(flickerExpression)':eval=frame"
            )

            // Very mild barrel geometry, followed by proportional overscan so
            // the treatment never exposes black lens-correction corners.
            let curvature = 0.016 * request.intensity
            if curvature > 0.000_001 {
                let overscanX = max(2, Int(ceil(Double(request.width) * curvature * 0.75)))
                let overscanY = max(2, Int(ceil(Double(request.height) * curvature * 0.75)))
                append(
                    "lenscorrection=k1=-\(decimal(curvature)):k2=\(decimal(curvature * 0.12)):i=bilinear," +
                    "scale=w=\(request.width + overscanX * 2):h=\(request.height + overscanY * 2):flags=lanczos," +
                    "crop=w=\(request.width):h=\(request.height):x=\(overscanX):y=\(overscanY):exact=1"
                )
            }

            let chromaPixels = Int((2 * request.intensity * request.chromaticSeparation).rounded())
            if request.profile == .colorCRT, chromaPixels > 0 {
                append(
                    "format=gbrp10le,rgbashift=rh=\(chromaPixels):gh=0:bh=-\(chromaPixels):edge=smear," +
                    "format=yuv444p10le"
                )
            }

            let ghostWeight = 0.12 * request.intensity * request.ghosting
            if ghostWeight > 0.000_001 {
                append("tmix=frames=2:weights='1 \(decimal(ghostWeight))'")
            }

            // Averaged temporal luma noise reads as coherent CRT grain without
            // adding modern chroma speckle to the monochrome profile.
            let noiseStrength = Int((12 * request.intensity * request.noise).rounded())
            if noiseStrength > 0 {
                append(
                    "noise=c0s=\(noiseStrength):c0f=t+u+a:c0_seed=\(request.seed):" +
                    "c1s=0:c2s=0"
                )
            }

            let bloomOpacity = 0.18 * request.intensity * request.bloom
            if bloomOpacity > 0.000_001 {
                let sharp = "crt\(stage)-sharp"
                let bloomInput = "crt\(stage)-bloom-input"
                let bloomOutput = "crt\(stage)-bloom"
                filters.append("[\(current)]split=2[\(sharp)][\(bloomInput)]")
                let sigma = max(0.35, Double(request.height) / 1080 * (1.2 + 2.0 * request.intensity * request.bloom))
                filters.append(
                    "[\(bloomInput)]" +
                    "lutyuv=y='if(gte(val\\,maxval*0.70)\\,val\\,minval)':" +
                    "u='(maxval+1)/2':v='(maxval+1)/2'," +
                    "gblur=sigma=\(decimal(sigma)):steps=2[\(bloomOutput)]"
                )
                stage += 1
                let next = "crt\(stage)"
                filters.append(
                    "[\(sharp)][\(bloomOutput)]blend=all_mode=screen:" +
                    "all_opacity=\(decimal(bloomOpacity))[\(next)]"
                )
                current = next
            }

            let jitterAmplitude = 2 * request.intensity * request.syncInstability
            if jitterAmplitude > 0.000_001 {
                // A tiny overscan supplies real edge pixels while the crop moves;
                // there are no black flashes at the jitter extremes.
                let margin = 2
                let jitter =
                    "\(decimal(jitterAmplitude))*(0.68*sin(2*PI*n*9.17*\(decimal(timeScale))+0.4)" +
                    "+0.32*sin(2*PI*n*4.03*\(decimal(timeScale))+1.7))"
                append(
                    "scale=w=\(request.width + margin * 2):h=\(request.height + margin * 2):flags=lanczos," +
                    "crop=w=\(request.width):h=\(request.height):x='\(margin)+\(jitter)':y=\(margin):exact=1"
                )

                if jitterAmplitude >= 0.5 {
                    // A two-frame, content-derived horizontal band appears only
                    // every few seconds. It is bounded to two pixels and never
                    // changes the stream's frame count or timestamps.
                    let tearShift = max(1, Int(jitterAmplitude.rounded()))
                    let bandHeight = max(2, request.height / 24)
                    let maxY = max(1, request.height - bandHeight)
                    let period = max(12, Int((request.frameRate.doubleValue * 3.7).rounded()))
                    let base = "crt\(stage)-tear-base"
                    let tearSource = "crt\(stage)-tear-source"
                    let tearBand = "crt\(stage)-tear-band"
                    let tearY = "mod(n*37+\(request.seed % maxY)\\,\(maxY))"
                    filters.append("[\(current)]split=2[\(base)][\(tearSource)]")
                    filters.append(
                        "[\(tearSource)]crop=w=\(request.width):h=\(bandHeight):x=0:" +
                        "y='\(tearY)':exact=1[\(tearBand)]"
                    )
                    stage += 1
                    let next = "crt\(stage)"
                    filters.append(
                        "[\(base)][\(tearBand)]overlay=x=\(tearShift):y='\(tearY)':" +
                        "enable='lt(mod(n+\(request.seed)\\,\(period))\\,2)':" +
                        "eof_action=pass:shortest=1:format=yuv444p10[\(next)]"
                    )
                    current = next
                }
            }

            let vignetteAngle = 0.17 * request.intensity * request.vignette
            if vignetteAngle > 0.000_001 {
                append(
                    "vignette=angle=\(decimal(vignetteAngle)):mode=forward:eval=init:dither=1"
                )
            }

            // Lines stay display-fixed by applying them after picture jitter.
            let scanlineOpacity = 0.22 * request.intensity * request.scanlines
            if scanlineOpacity > 0.000_001 {
                let pitch = max(2, Int((Double(request.height) / 360).rounded()))
                let thickness = max(1, pitch / 3)
                append(
                    "drawgrid=x=0:y=0:w=0:h=\(pitch):t=\(thickness):" +
                    "c=black@\(decimal(scanlineOpacity)):replace=0"
                )
            }
        }

        filters.append("[\(current)]format=yuv422p10le[crtout]")
        return filters.joined(separator: ";")
    }

    private func decimal(_ value: Double) -> String {
        let formatted = String(
            format: "%.9f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
        let trimmed = formatted.replacingOccurrences(
            of: "(?:\\.0+|(?<=\\.[0-9]*?)0+)$",
            with: "",
            options: .regularExpression
        )
        return trimmed == "-0" ? "0" : trimmed
    }

    // MARK: - Process arguments

    private func renderArguments(
        source: URL,
        temporary: URL,
        validated: ValidatedRequest,
        recipeDigest: String,
        filterGraph: String
    ) -> [String] {
        let rate = "\(validated.frameRate.numerator)/\(validated.frameRate.denominator)"
        var arguments = [
            "-hide_banner", "-loglevel", "error", "-nostdin", "-n",
            "-bitexact", "-fflags", "+bitexact"
        ]
        if validated.sourceKind == .still {
            arguments += ["-loop", "1", "-framerate", rate]
        }
        arguments += ["-i", source.path]
        arguments += [
            "-filter_complex_threads", "1",
            "-filter_complex", filterGraph,
            "-map", "[crtout]",
            "-an", "-sn", "-dn",
            "-frames:v", String(validated.frameCount),
            "-c:v", "prores_ks",
            "-profile:v", "3",
            "-pix_fmt", "yuv422p10le",
            "-threads:v", "1",
            "-fps_mode", "passthrough",
            "-enc_time_base:v", "\(validated.frameRate.denominator)/\(validated.frameRate.numerator)",
            "-video_track_timescale", String(validated.frameRate.numerator),
            "-map_metadata", "-1",
            "-map_chapters", "-1",
            "-metadata", "comment=fcpcommandconsole-old-television:\(recipeDigest)",
            "-metadata", "encoder=\(Self.rendererVersion)",
            "-movflags", "+faststart",
            temporary.path
        ]
        return arguments
    }

    private func renderTimeout(for request: ValidatedRequest) -> Int {
        // A finite upper bound prevents an orphaned media process. Large jobs
        // receive proportionally more time without allowing an infinite wait.
        let megapixelFrames = Double(request.width * request.height) * Double(request.frameCount) / 1_000_000
        return min(900, max(30, Int(ceil(megapixelFrames * 0.75))))
    }

    // MARK: - Probe and verification

    private struct ProbeEnvelope: Decodable {
        let streams: [ProbeStream]
        let format: ProbeFormat?
    }

    private struct ProbeStream: Decodable {
        let codecName: String?
        let codecType: String?
        let profile: String?
        let codecTagString: String?
        let pixelFormat: String?
        let width: Int?
        let height: Int?
        let frameRate: String?
        let averageFrameRate: String?
        let timeBase: String?
        let durationTicks: Int64?
        let duration: String?
        let decodedFrameCount: String?
        let declaredFrameCount: String?

        enum CodingKeys: String, CodingKey {
            case codecName = "codec_name"
            case codecType = "codec_type"
            case profile
            case codecTagString = "codec_tag_string"
            case pixelFormat = "pix_fmt"
            case width, height
            case frameRate = "r_frame_rate"
            case averageFrameRate = "avg_frame_rate"
            case timeBase = "time_base"
            case durationTicks = "duration_ts"
            case duration
            case decodedFrameCount = "nb_read_frames"
            case declaredFrameCount = "nb_frames"
        }
    }

    private struct ProbeFormat: Decodable {
        let duration: String?
        let tags: [String: String]?
    }

    private func probe(
        _ url: URL,
        countFrames: Bool,
        timeout: Int,
        executable: URL
    ) throws -> ProbeEnvelope {
        var arguments = ["-v", "error"]
        if countFrames { arguments.append("-count_frames") }
        arguments += ["-show_streams", "-show_format", "-of", "json", url.path]
        let data = try runCapture(
            executable: executable,
            reportedAs: ffprobe,
            arguments: arguments,
            timeout: timeout
        )
        do {
            return try JSONDecoder().decode(ProbeEnvelope.self, from: data)
        } catch {
            throw OldTelevisionRenderError.verificationFailed(
                "ffprobe returned undecodable metadata: \(error.localizedDescription)"
            )
        }
    }

    private func validateSource(_ probe: ProbeEnvelope, for request: ValidatedRequest) throws {
        let videos = probe.streams.filter { $0.codecType == "video" }
        guard let video = videos.first else {
            throw OldTelevisionRenderError.sourceRejected("source contains no video stream")
        }
        guard video.width != nil, video.height != nil else {
            throw OldTelevisionRenderError.sourceRejected("source video dimensions are unavailable")
        }
        if request.sourceKind == .still {
            guard let countText = video.decodedFrameCount ?? video.declaredFrameCount,
                  Int(countText) == 1 else {
                throw OldTelevisionRenderError.sourceRejected(
                    "a still request must identify a source with exactly one decoded frame"
                )
            }
        } else {
            let sourceRates = [video.averageFrameRate, video.frameRate].compactMap { $0 }
            guard sourceRates.contains(where: { (try? parseRational($0)) != nil }) else {
                throw OldTelevisionRenderError.sourceRejected(
                    "movie has no valid decodable frame-rate metadata"
                )
            }
            if let durationText = video.duration ?? probe.format?.duration,
               let sourceDuration = Double(durationText), sourceDuration.isFinite {
                let oneFrame = 1 / request.frameRate.doubleValue
                guard sourceDuration + oneFrame * 0.01 >= request.duration.doubleValue else {
                    throw OldTelevisionRenderError.sourceRejected("movie is shorter than the exact requested duration")
                }
            }
        }
    }

    private func verify(
        _ output: URL,
        validated: ValidatedRequest,
        recipeDigest: String,
        ffprobeExecutable: URL
    ) throws -> OldTelevisionRenderArtifact {
        let probe = try probe(
            output,
            countFrames: true,
            timeout: max(120, renderTimeout(for: validated)),
            executable: ffprobeExecutable
        )
        let videos = probe.streams.filter { $0.codecType == "video" }
        let audio = probe.streams.filter { $0.codecType == "audio" }
        guard videos.count == 1, let video = videos.first else {
            throw OldTelevisionRenderError.verificationFailed(
                "expected exactly one video stream, found \(videos.count)"
            )
        }
        guard audio.isEmpty else {
            throw OldTelevisionRenderError.verificationFailed(
                "render contains \(audio.count) audio stream(s); treatment artifacts must be video-only"
            )
        }
        guard video.codecName == "prores",
              video.profile == "HQ",
              video.codecTagString == "apch",
              video.pixelFormat == "yuv422p10le" else {
            throw OldTelevisionRenderError.verificationFailed(
                "expected ProRes 422 HQ 10-bit (prores/HQ/apch/yuv422p10le), found " +
                "\(video.codecName ?? "nil")/\(video.profile ?? "nil")/" +
                "\(video.codecTagString ?? "nil")/\(video.pixelFormat ?? "nil")"
            )
        }
        guard video.width == validated.width, video.height == validated.height else {
            throw OldTelevisionRenderError.verificationFailed(
                "dimensions were \(video.width ?? -1)x\(video.height ?? -1), expected \(validated.width)x\(validated.height)"
            )
        }
        guard let rawRate = video.frameRate,
              let rate = try? parseRational(rawRate),
              rate == validated.frameRate else {
            throw OldTelevisionRenderError.verificationFailed(
                "frame rate \(video.frameRate ?? "nil") does not match exact requested rate"
            )
        }
        if let average = video.averageFrameRate,
           let averageRate = try? parseRational(average),
           averageRate != validated.frameRate {
            throw OldTelevisionRenderError.verificationFailed(
                "average frame rate \(average) differs from exact requested rate"
            )
        }
        guard let countText = video.decodedFrameCount ?? video.declaredFrameCount,
              let count = Int(countText),
              count == validated.frameCount else {
            throw OldTelevisionRenderError.verificationFailed(
                "decoded frame count \(video.decodedFrameCount ?? video.declaredFrameCount ?? "nil") " +
                "does not match \(validated.frameCount)"
            )
        }
        guard let ticks = video.durationTicks,
              let timeBaseText = video.timeBase,
              let timeBase = try? parseRational(timeBaseText),
              let probedDuration = try? multiplied(timeBase, by: ticks),
              probedDuration == validated.duration else {
            throw OldTelevisionRenderError.verificationFailed(
                "stream duration \(video.duration ?? "nil") is not the exact requested rational duration"
            )
        }
        let expectedComment = "fcpcommandconsole-old-television:\(recipeDigest)"
        guard probe.format?.tags?["comment"] == expectedComment else {
            throw OldTelevisionRenderError.verificationFailed("recipe identity metadata is missing or mismatched")
        }

        let digest = try ContentHasher.sha256File(output)
        return OldTelevisionRenderArtifact(
            url: output,
            sha256: digest,
            recipeDigest: recipeDigest,
            codec: video.codecName ?? "prores",
            codecProfile: video.profile ?? "HQ",
            pixelFormat: video.pixelFormat ?? "yuv422p10le",
            width: validated.width,
            height: validated.height,
            frameRate: validated.frameRate,
            frameCount: validated.frameCount,
            duration: validated.duration
        )
    }

    private func parseRational(_ raw: String) throws -> OldTelevisionRational {
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 1, let value = Int64(parts[0]) {
            return try OldTelevisionRational(value, 1).normalized(named: "probed rational")
        }
        guard parts.count == 2,
              let numerator = Int64(parts[0]),
              let denominator = Int64(parts[1]) else {
            throw OldTelevisionRenderError.verificationFailed("invalid rational \(raw)")
        }
        return try OldTelevisionRational(numerator, denominator).normalized(named: "probed rational")
    }

    private func multiplied(_ rational: OldTelevisionRational, by integer: Int64) throws -> OldTelevisionRational {
        let product = rational.numerator.multipliedReportingOverflow(by: integer)
        guard !product.overflow else {
            throw OldTelevisionRenderError.verificationFailed("probed duration overflowed")
        }
        return try OldTelevisionRational(product.partialValue, rational.denominator)
            .normalized(named: "probed duration")
    }

    // MARK: - Process execution

    private func runCapture(
        executable: URL,
        reportedAs reportedExecutable: URL,
        arguments: [String],
        timeout: Int
    ) throws -> Data {
        let fileManager = FileManager.default
        let token = UUID().uuidString
        let stdoutURL = fileManager.temporaryDirectory.appendingPathComponent(
            "fcpcc-old-television-tool-\(token).stdout"
        )
        let stderrURL = fileManager.temporaryDirectory.appendingPathComponent(
            "fcpcc-old-television-tool-\(token).stderr"
        )
        guard fileManager.createFile(atPath: stdoutURL.path, contents: nil),
              fileManager.createFile(atPath: stderrURL.path, contents: nil) else {
            throw OldTelevisionRenderError.toolFailed(
                reportedExecutable,
                status: -1,
                message: "could not create bounded process capture files"
            )
        }
        let stdoutHandle: FileHandle
        let stderrHandle: FileHandle
        do {
            stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            stderrHandle = try FileHandle(forWritingTo: stderrURL)
        } catch {
            try? fileManager.removeItem(at: stdoutURL)
            try? fileManager.removeItem(at: stderrURL)
            throw OldTelevisionRenderError.toolFailed(
                reportedExecutable,
                status: -1,
                message: error.localizedDescription
            )
        }
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            try? fileManager.removeItem(at: stdoutURL)
            try? fileManager.removeItem(at: stderrURL)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        do {
            try process.run()
        } catch {
            throw OldTelevisionRenderError.toolFailed(
                reportedExecutable,
                status: -1,
                message: error.localizedDescription
            )
        }
        try wait(process, executable: reportedExecutable, timeout: timeout)
        try? stdoutHandle.synchronize()
        try? stderrHandle.synchronize()
        try? stdoutHandle.close()
        try? stderrHandle.close()
        let output = (try? Data(contentsOf: stdoutURL)) ?? Data()
        let errorData = (try? Data(contentsOf: stderrURL)) ?? Data()
        guard process.terminationStatus == 0 else {
            throw OldTelevisionRenderError.toolFailed(
                reportedExecutable,
                status: process.terminationStatus,
                message: diagnostic(errorData)
            )
        }
        return output
    }

    private func runRender(executable: URL, arguments: [String], timeout: Int) throws {
        let fileManager = FileManager.default
        let stderrURL = fileManager.temporaryDirectory.appendingPathComponent(
            "fcpcc-old-television-render-\(UUID().uuidString).stderr"
        )
        guard fileManager.createFile(atPath: stderrURL.path, contents: nil) else {
            throw OldTelevisionRenderError.toolFailed(
                ffmpeg,
                status: -1,
                message: "could not create bounded render diagnostic file"
            )
        }
        let stderrHandle: FileHandle
        do {
            stderrHandle = try FileHandle(forWritingTo: stderrURL)
        } catch {
            try? fileManager.removeItem(at: stderrURL)
            throw OldTelevisionRenderError.toolFailed(
                ffmpeg,
                status: -1,
                message: error.localizedDescription
            )
        }
        defer {
            try? stderrHandle.close()
            try? fileManager.removeItem(at: stderrURL)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrHandle
        do {
            try process.run()
        } catch {
            throw OldTelevisionRenderError.toolFailed(
                ffmpeg,
                status: -1,
                message: error.localizedDescription
            )
        }
        try wait(process, executable: ffmpeg, timeout: timeout)
        try? stderrHandle.synchronize()
        try? stderrHandle.close()
        let errorData = (try? Data(contentsOf: stderrURL)) ?? Data()
        guard process.terminationStatus == 0 else {
            throw OldTelevisionRenderError.toolFailed(
                ffmpeg,
                status: process.terminationStatus,
                message: diagnostic(errorData)
            )
        }
    }

    private func wait(_ process: Process, executable: URL, timeout: Int) throws {
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                let grace = Date().addingTimeInterval(2)
                while process.isRunning, Date() < grace { usleep(10_000) }
                if process.isRunning { process.interrupt() }
                throw CancellationError()
            }
            if Date() >= deadline {
                process.terminate()
                let grace = Date().addingTimeInterval(2)
                while process.isRunning, Date() < grace { usleep(10_000) }
                if process.isRunning { process.interrupt() }
                throw OldTelevisionRenderError.toolTimedOut(executable, seconds: timeout)
            }
            usleep(10_000)
        }
    }

    private func diagnostic(_ data: Data) -> String {
        let text = String(decoding: data.prefix(12_000), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "no diagnostic output" : text
    }
}
