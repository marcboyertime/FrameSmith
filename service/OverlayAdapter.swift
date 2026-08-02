import Foundation
import Darwin

public enum OverlayKind: String, Codable, CaseIterable, Sendable { case staticGrain = "static", scanline }

public struct OverlayRequest: Codable, Equatable, Sendable {
    public var kind: OverlayKind
    public var width: Int
    public var height: Int
    public var fps: Int
    public var durationSeconds: Double
    public var seed: Int

    public init(kind: OverlayKind, width: Int = 320, height: Int = 180, fps: Int = 24, durationSeconds: Double = 1, seed: Int = 1) {
        self.kind = kind; self.width = width; self.height = height; self.fps = fps; self.durationSeconds = durationSeconds; self.seed = seed
    }
}

public struct OverlayMetadata: Codable, Equatable, Sendable {
    public var path: URL
    public var sha256: String
    public var codec: String
    public var pixelFormat: String
    public var width: Int
    public var height: Int
    public var fps: Int
    public var durationSeconds: Double
    public var alphaCapable: Bool
    public var request: OverlayRequest

    public init(path: URL, sha256: String, codec: String, pixelFormat: String, width: Int, height: Int, fps: Int, durationSeconds: Double, alphaCapable: Bool, request: OverlayRequest) {
        self.path = path; self.sha256 = sha256; self.codec = codec; self.pixelFormat = pixelFormat; self.width = width; self.height = height; self.fps = fps; self.durationSeconds = durationSeconds; self.alphaCapable = alphaCapable; self.request = request
    }
}

public enum OverlayError: Error, LocalizedError, Equatable {
    case invalidRequest(String)
    case toolMissing(URL)
    case processFailed(String)
    case verificationFailed(String)
    case outputRejected(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let reason): return "Invalid overlay request: \(reason)"
        case .toolMissing(let url): return "Required media tool is missing: \(url.path)"
        case .processFailed(let reason): return "FFmpeg failed: \(reason)"
        case .verificationFailed(let reason): return "Overlay verification failed: \(reason)"
        case .outputRejected(let reason): return "Overlay output rejected: \(reason)"
        }
    }
}

/// A deliberately closed FFmpeg adapter. Its executable path, filter graphs,
/// and arguments are constants; callers can vary only bounded typed values.
public struct SafeFFmpegOverlayAdapter: Sendable {
    public static let ffmpegURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    public static let ffprobeURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
    public let ffmpeg: URL
    public let ffprobe: URL

    public init(ffmpeg: URL = SafeFFmpegOverlayAdapter.ffmpegURL, ffprobe: URL = SafeFFmpegOverlayAdapter.ffprobeURL) {
        self.ffmpeg = ffmpeg; self.ffprobe = ffprobe
    }

    public func generate(_ request: OverlayRequest, in allowedOverlayRoot: URL) throws -> OverlayMetadata {
        try validate(request)
        guard FileManager.default.isExecutableFile(atPath: ffmpeg.path) else { throw OverlayError.toolMissing(ffmpeg) }
        guard FileManager.default.isExecutableFile(atPath: ffprobe.path) else { throw OverlayError.toolMissing(ffprobe) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let contentKey = ContentHasher.sha256(try encoder.encode(request))
        let root = allowedOverlayRoot.standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent("\(request.kind.rawValue)-\(contentKey.prefix(24)).mov")
        let policy = PathPolicy(allowedInputRoots: [], outputRoot: root)
        // Validate containment while allowing the deterministic content-addressed
        // path to be reused. A mismatched/corrupt existing file is rejected by
        // ffprobe verification; it is never overwritten.
        _ = try policy.validateOutput(output, overwrite: true)
        if FileManager.default.fileExists(atPath: output.path) { return try verify(output: output, request: request) }

        let temporary = root.appendingPathComponent(".tmp-\(contentKey)-\(UUID().uuidString).mov")
        defer {
            if FileManager.default.fileExists(atPath: temporary.path) { try? FileManager.default.removeItem(at: temporary) }
        }
        let filter = filterGraph(for: request)
        var process = Process()
        process.executableURL = ffmpeg
        process.arguments = ["-hide_banner", "-loglevel", "error", "-nostdin", "-f", "lavfi", "-i", filter, "-an", "-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le", "-frames:v", String(max(1, Int((request.durationSeconds * Double(request.fps)).rounded(.up)))), temporary.path]
        let errorPipe = Pipe(); process.standardError = errorPipe; process.standardOutput = Pipe()
        do { try process.run() } catch { throw OverlayError.processFailed(error.localizedDescription) }
        try wait(process, timeout: 30)
        guard process.terminationStatus == 0 else {
            let errorText = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
            throw OverlayError.processFailed(errorText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard FileManager.default.fileExists(atPath: temporary.path) else { throw OverlayError.processFailed("FFmpeg produced no output") }
        do { try FileManager.default.moveItem(at: temporary, to: output) } catch { throw OverlayError.outputRejected(error.localizedDescription) }
        return try verify(output: output, request: request)
    }

    public func generate(kind: OverlayKind, width: Int = 320, height: Int = 180, fps: Int = 24, durationSeconds: Double = 1, seed: Int = 1, in root: URL) throws -> OverlayMetadata {
        try generate(OverlayRequest(kind: kind, width: width, height: height, fps: fps, durationSeconds: durationSeconds, seed: seed), in: root)
    }

    private func validate(_ request: OverlayRequest) throws {
        guard request.width >= 16, request.width <= 1920, request.height >= 16, request.height <= 1080 else { throw OverlayError.invalidRequest("resolution outside 16..1920x1080") }
        guard request.fps >= 1, request.fps <= 60, request.durationSeconds.isFinite, request.durationSeconds > 0, request.durationSeconds <= 30 else { throw OverlayError.invalidRequest("fps/duration outside bounded range") }
        guard request.seed >= 0 else { throw OverlayError.invalidRequest("seed must be non-negative") }
    }

    private func filterGraph(for request: OverlayRequest) -> String {
        let source = "color=c=black@0.0:s=\(request.width)x\(request.height):r=\(request.fps):d=\(String(format: "%.6f", request.durationSeconds)),format=rgba"
        switch request.kind {
        case .staticGrain:
            return "\(source),noise=alls=22:allf=t+u:all_seed=\(request.seed),format=yuva444p10le"
        case .scanline:
            return "\(source),drawgrid=w=iw:h=2:t=1:c=white@0.10,noise=alls=5:allf=t+u:all_seed=\(request.seed),format=yuva444p10le"
        }
    }

    private func verify(output: URL, request: OverlayRequest) throws -> OverlayMetadata {
        let probe = try runProbe(output)
        let fields = probe.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "|" || $0 == "," || $0.isWhitespace }).map(String.init)
        guard fields.count >= 6 else { throw OverlayError.verificationFailed("ffprobe response was incomplete: \(probe.debugDescription)") }
        let codec = fields[0]
        guard let pixelIndex = fields.firstIndex(where: { $0.lowercased().hasPrefix("yuva") || $0.lowercased().hasPrefix("rgba") }) else {
            throw OverlayError.verificationFailed("FFmpeg did not report an alpha-capable pixel format; probe=\(fields.joined(separator: ","))")
        }
        let pixelFormat = fields[pixelIndex]
        let width = fields.dropFirst().compactMap(Int.init).first ?? 0
        let height = fields.dropFirst().compactMap(Int.init).dropFirst().first ?? 0
        let fps = fields.dropFirst(pixelIndex + 1).compactMap(Int.init).first ?? 0
        let duration = fields.reversed().compactMap(Double.init).first ?? 0
        guard codec == "prores" || codec == "prores_ks" else { throw OverlayError.verificationFailed("codec is \(codec), expected ProRes") }
        let alpha = pixelFormat.lowercased().hasPrefix("yuva") || pixelFormat.lowercased().contains("rgba")
        guard alpha else { throw OverlayError.verificationFailed("FFmpeg did not produce an alpha-capable pixel format (\(pixelFormat)); probe=\(fields.joined(separator: ","))") }
        guard width == request.width, height == request.height, fps > 0, duration > 0 else { throw OverlayError.verificationFailed("dimensions, frame rate, or duration mismatch") }
        return OverlayMetadata(path: output, sha256: try ContentHasher.sha256File(output), codec: codec, pixelFormat: pixelFormat, width: width, height: height, fps: fps, durationSeconds: duration, alphaCapable: alpha, request: request)
    }

    private func runProbe(_ output: URL) throws -> String {
        var process = Process(); process.executableURL = ffprobe
        process.arguments = ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,pix_fmt,width,height,r_frame_rate,duration", "-of", "csv=p=0:s=|", output.path]
        let stdout = Pipe(); let stderr = Pipe(); process.standardOutput = stdout; process.standardError = stderr
        do { try process.run() } catch { throw OverlayError.processFailed(error.localizedDescription) }
        try wait(process, timeout: 15)
        guard process.terminationStatus == 0 else { throw OverlayError.verificationFailed(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "ffprobe failed") }
        let raw = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var fields = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(omittingEmptySubsequences: false, whereSeparator: { $0 == "|" || $0 == "," || $0.isWhitespace }).map(String.init)
        // ffprobe reports frame rate as a rational; retain only the bounded
        // integer numerator for the metadata contract.
        if fields.count >= 6, fields[4].contains("/") { fields[4] = fields[4].split(separator: "/").first.map(String.init) ?? fields[4] }
        return fields.joined(separator: "|")
    }

    private func wait(_ process: Process, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                throw OverlayError.processFailed("media tool exceeded \(Int(timeout)) second timeout")
            }
            usleep(10_000)
        }
    }
}

public typealias FFmpegOverlayAdapter = SafeFFmpegOverlayAdapter
