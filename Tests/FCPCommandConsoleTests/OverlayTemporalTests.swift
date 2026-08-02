import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class OverlayTemporalTests: XCTestCase {
    private struct ToolFailure: Error, CustomStringConvertible {
        let executable: URL
        let arguments: [String]
        let status: Int32
        let stderr: String

        var description: String {
            "\(executable.path) exited \(status): \(stderr) (args: \(arguments))"
        }
    }

    private struct Probe {
        let codec: String
        let pixelFormat: String
        let width: Int
        let height: Int
        let fps: Double
        let duration: Double
        let frameCount: Int
    }

    private let fileManager = FileManager.default

    func testOverlayBytesAreDeterministicAndFrameExactAcrossRoots() throws {
        try requireMediaTools()
        let rootA = try temporaryRoot("a")
        let rootB = try temporaryRoot("b")
        defer {
            try? fileManager.removeItem(at: rootA)
            try? fileManager.removeItem(at: rootB)
        }

        let adapter = SafeFFmpegOverlayAdapter()
        for kind in OverlayKind.allCases {
            let request = OverlayRequest(kind: kind, width: 64, height: 36, fps: 12, durationSeconds: 1, seed: 41)
            let first = try adapter.generate(request, in: rootA)
            let second = try adapter.generate(request, in: rootB)
            let firstBytes = try Data(contentsOf: first.path)
            let secondBytes = try Data(contentsOf: second.path)
            XCTAssertEqual(firstBytes, secondBytes, "\(kind.rawValue) bytes differ across roots")
            XCTAssertEqual(first.sha256, second.sha256, "\(kind.rawValue) SHA-256 differs across roots")
            XCTAssertEqual(first.sha256, ContentHasher.sha256(firstBytes))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let requestKey = ContentHasher.sha256(try encoder.encode(request))
            XCTAssertEqual(first.path.lastPathComponent, "\(kind.rawValue)-\(requestKey.prefix(24)).mov")

            let repeated = try adapter.generate(request, in: rootA)
            XCTAssertEqual(repeated.path, first.path)
            XCTAssertEqual(repeated.sha256, first.sha256)
            XCTAssertEqual(try Data(contentsOf: repeated.path), firstBytes)

            let probe = try probe(first.path)
            XCTAssertEqual(probe.codec, "prores")
            XCTAssertTrue(probe.pixelFormat.lowercased().hasPrefix("yuva") || probe.pixelFormat.lowercased().contains("rgba"))
            XCTAssertEqual(probe.width, request.width)
            XCTAssertEqual(probe.height, request.height)
            XCTAssertEqual(probe.fps, Double(request.fps), accuracy: 0.000001)
            XCTAssertEqual(probe.frameCount, 12)
            XCTAssertEqual(probe.duration, 1, accuracy: 0.000001)
        }
    }

    func testStaticGrainTemporalDifferenceIsBelowUnfilteredDecodedBaseline() throws {
        try requireMediaTools()
        let root = try temporaryRoot("static")
        defer { try? fileManager.removeItem(at: root) }
        let request = OverlayRequest(kind: .staticGrain, width: 64, height: 36, fps: 12, durationSeconds: 1, seed: 41)
        let coherent = try SafeFFmpegOverlayAdapter().generate(request, in: root)
        let baseline = root.appendingPathComponent("baseline-static.mov")
        try writeUnfilteredBaseline(request, to: baseline)

        let coherentFrames = try decodedRGBAFrames(coherent.path, width: request.width, height: request.height, expectedCount: 12)
        let baselineFrames = try decodedRGBAFrames(baseline, width: request.width, height: request.height, expectedCount: 12)
        XCTAssertGreaterThan(Set(coherentFrames).count, 1, "static grain unexpectedly collapsed to one decoded frame")

        let coherentDifference = meanAdjacentLumaDifference(coherentFrames, width: request.width, height: request.height)
        let baselineDifference = meanAdjacentLumaDifference(baselineFrames, width: request.width, height: request.height)
        XCTAssertGreaterThan(coherentDifference, 0.01)
        XCTAssertGreaterThan(baselineDifference, coherentDifference)
        XCTAssertLessThanOrEqual(coherentDifference, baselineDifference * 0.60 + 0.25,
                                 "coherent static difference \(coherentDifference) was not bounded below baseline \(baselineDifference)")
    }

    func testScanlineRowsRemainStableWhileDecodedMotionIsBounded() throws {
        try requireMediaTools()
        let root = try temporaryRoot("scanline")
        defer { try? fileManager.removeItem(at: root) }
        let request = OverlayRequest(kind: .scanline, width: 64, height: 36, fps: 12, durationSeconds: 1, seed: 41)
        let coherent = try SafeFFmpegOverlayAdapter().generate(request, in: root)
        let baseline = root.appendingPathComponent("baseline-scanline.mov")
        try writeUnfilteredBaseline(request, to: baseline)

        let coherentFrames = try decodedRGBAFrames(coherent.path, width: request.width, height: request.height, expectedCount: 12)
        let baselineFrames = try decodedRGBAFrames(baseline, width: request.width, height: request.height, expectedCount: 12)
        let coherentDifference = meanAdjacentLumaDifference(coherentFrames, width: request.width, height: request.height)
        let baselineDifference = meanAdjacentLumaDifference(baselineFrames, width: request.width, height: request.height)
        XCTAssertGreaterThan(coherentDifference, 0.01)
        XCTAssertGreaterThan(baselineDifference, coherentDifference)
        XCTAssertLessThanOrEqual(coherentDifference, baselineDifference * 0.60 + 0.25)

        for frame in coherentFrames {
            let rows = rowMeans(frame, width: request.width, height: request.height)
            let evenRows = stride(from: 0, to: request.height, by: 2).map { rows[$0] }
            let oddRows = stride(from: 1, to: request.height, by: 2).map { rows[$0] }
            let evenMean = evenRows.reduce(0, +) / Double(evenRows.count)
            let oddMean = oddRows.reduce(0, +) / Double(oddRows.count)
            XCTAssertGreaterThan(evenMean - oddMean, 5, "scanline row contrast was not stable")
        }
    }

    private func requireMediaTools() throws {
        try XCTSkipUnless(fileManager.isExecutableFile(atPath: SafeFFmpegOverlayAdapter.ffmpegURL.path) &&
                          fileManager.isExecutableFile(atPath: SafeFFmpegOverlayAdapter.ffprobeURL.path),
                          "Homebrew ffmpeg/ffprobe unavailable")
    }

    private func temporaryRoot(_ label: String) throws -> URL {
        let root = fileManager.temporaryDirectory.appendingPathComponent("fcpcc-overlay-\(label)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func probe(_ url: URL) throws -> Probe {
        let bytes = try run(SafeFFmpegOverlayAdapter.ffprobeURL, arguments: [
            "-v", "error", "-count_frames", "-select_streams", "v:0",
            "-show_entries", "stream=codec_name,pix_fmt,width,height,r_frame_rate,duration,nb_read_frames",
            "-of", "default=nw=1:nk=0", url.path
        ])
        var values = [String: String]()
        for line in String(decoding: bytes, as: UTF8.self).split(whereSeparator: { $0.isNewline }) {
            let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { values[pair[0]] = pair[1] }
        }
        guard let codec = values["codec_name"], let pixelFormat = values["pix_fmt"],
              let width = Int(values["width"] ?? ""), let height = Int(values["height"] ?? ""),
              let fps = parseRational(values["r_frame_rate"] ?? ""), let duration = Double(values["duration"] ?? ""),
              let frameCount = Int(values["nb_read_frames"] ?? "") ?? Int(values["nb_frames"] ?? "") else {
            throw ToolFailure(executable: SafeFFmpegOverlayAdapter.ffprobeURL, arguments: [url.path], status: -1, stderr: "incomplete ffprobe response: \(values)")
        }
        return Probe(codec: codec, pixelFormat: pixelFormat, width: width, height: height, fps: fps, duration: duration, frameCount: frameCount)
    }

    private func parseRational(_ value: String) -> Double? {
        if let slash = value.firstIndex(of: "/") {
            guard let numerator = Double(value[..<slash]), let denominator = Double(value[value.index(after: slash)...]), denominator != 0 else { return nil }
            return numerator / denominator
        }
        return Double(value)
    }

    private func writeUnfilteredBaseline(_ request: OverlayRequest, to output: URL) throws {
        let source = "color=c=black@0.0:s=\(request.width)x\(request.height):r=\(request.fps):d=\(String(format: "%.6f", request.durationSeconds)),format=rgba"
        let filter: String
        switch request.kind {
        case .staticGrain:
            filter = "\(source),noise=alls=22:allf=t+u:all_seed=\(request.seed),format=yuva444p10le"
        case .scanline:
            filter = "\(source),noise=alls=5:allf=t+u:all_seed=\(request.seed),drawgrid=w=iw:h=2:t=1:c=white@0.10,format=yuva444p10le"
        }
        _ = try run(SafeFFmpegOverlayAdapter.ffmpegURL, arguments: [
            "-hide_banner", "-loglevel", "error", "-nostdin", "-bitexact", "-fflags", "+bitexact",
            "-f", "lavfi", "-i", filter, "-map_metadata", "-1", "-map_chapters", "-1", "-an",
            "-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
            "-frames:v", String(max(1, Int((request.durationSeconds * Double(request.fps)).rounded(.up)))), output.path
        ])
    }

    private func decodedRGBAFrames(_ url: URL, width: Int, height: Int, expectedCount: Int) throws -> [Data] {
        let bytes = try run(SafeFFmpegOverlayAdapter.ffmpegURL, arguments: [
            "-hide_banner", "-loglevel", "error", "-nostdin", "-i", url.path, "-map", "0:v:0",
            "-frames:v", String(expectedCount), "-f", "rawvideo", "-pix_fmt", "rgba", "-"
        ])
        let frameSize = width * height * 4
        guard frameSize > 0, bytes.count % frameSize == 0 else {
            throw ToolFailure(executable: SafeFFmpegOverlayAdapter.ffmpegURL, arguments: [url.path], status: -1, stderr: "decoded RGBA byte count \(bytes.count) is not divisible by \(frameSize)")
        }
        let frames = stride(from: 0, to: bytes.count, by: frameSize).map { bytes.subdata(in: $0..<$0 + frameSize) }
        guard frames.count == expectedCount else {
            throw ToolFailure(executable: SafeFFmpegOverlayAdapter.ffmpegURL, arguments: [url.path], status: -1, stderr: "decoded \(frames.count) frames, expected \(expectedCount)")
        }
        return frames
    }

    private func luma(_ frame: Data) -> [Double] {
        stride(from: 0, to: frame.count, by: 4).map { index in
            let red = Double(frame[index]); let green = Double(frame[index + 1]); let blue = Double(frame[index + 2])
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
    }

    private func rowMeans(_ frame: Data, width: Int, height: Int) -> [Double] {
        let values = luma(frame)
        return (0..<height).map { row in
            let start = row * width
            return values[start..<(start + width)].reduce(0, +) / Double(width)
        }
    }

    private func meanAdjacentLumaDifference(_ frames: [Data], width: Int, height: Int) -> Double {
        guard frames.count > 1 else { return 0 }
        let lumaFrames = frames.map(luma)
        let pixelCount = width * height
        var total = 0.0
        for frameIndex in 1..<lumaFrames.count {
            for pixel in 0..<pixelCount {
                total += abs(lumaFrames[frameIndex][pixel] - lumaFrames[frameIndex - 1][pixel])
            }
        }
        return total / Double((lumaFrames.count - 1) * pixelCount)
    }

    private func run(_ executable: URL, arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdoutURL = fileManager.temporaryDirectory.appendingPathComponent("fcpcc-overlay-tool-\(UUID().uuidString).out")
        fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        defer { try? fileManager.removeItem(at: stdoutURL) }
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = Pipe()
        process.standardOutput = stdout; process.standardError = stderr
        do { try process.run() } catch { throw ToolFailure(executable: executable, arguments: arguments, status: -1, stderr: error.localizedDescription) }
        process.waitUntilExit()
        try? stdout.close()
        let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw ToolFailure(executable: executable, arguments: arguments, status: process.terminationStatus, stderr: errorText)
        }
        return try Data(contentsOf: stdoutURL)
    }
}
