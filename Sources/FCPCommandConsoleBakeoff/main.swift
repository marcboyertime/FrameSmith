import Foundation
import FCPCommandConsoleCore
import CoreImage
import AppKit

/// Runs Living Still analysis over a set of stills and writes inspectable
/// artifacts for the v2 bakeoff.
///
/// Separate from the production app on purpose: a bakeoff is a measurement
/// tool, and measurement tools that share code paths with the thing being
/// measured tend to flatter it.
@main
struct BakeoffCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard !args.isEmpty, !args.contains("--help") else {
            print("""
            usage: fcpcommandconsole-bakeoff <image> [<image> …] [--out DIR]
                   [--analyze] [--render-depth] [--render-crt]
                   [--depth-motion-strength 0...1] [--depth-push-in 0...0.15]

            Analysis writes Apple Vision diagnostics. Render modes exercise the
            exact production Living Still v2 and Old Television adapters and
            write checksum-addressed ProRes movies outside the repository.
            """)
            return
        }

        var images: [String] = []
        var out = NSHomeDirectory() + "/Movies/FCPCommandConsole/exports/bakeoff"
        var analyze = false
        var renderDepth = false
        var renderCRT = false
        var depthMotionStrength = 0.90
        var depthPushIn = 0.03
        var index = 0
        while index < args.count {
            if args[index] == "--out", index + 1 < args.count { out = args[index + 1]; index += 2 }
            else if args[index] == "--analyze" { analyze = true; index += 1 }
            else if args[index] == "--render-depth" { renderDepth = true; index += 1 }
            else if args[index] == "--render-crt" { renderCRT = true; index += 1 }
            else if args[index] == "--depth-motion-strength", index + 1 < args.count,
                    let value = Double(args[index + 1]), (0...1).contains(value) {
                depthMotionStrength = value
                index += 2
            }
            else if args[index] == "--depth-push-in", index + 1 < args.count,
                    let value = Double(args[index + 1]), (0...0.15).contains(value) {
                depthPushIn = value
                index += 2
            }
            else if args[index].hasPrefix("--") {
                print("invalid or incomplete bakeoff option: \(args[index])")
                return
            }
            else { images.append(args[index]); index += 1 }
        }
        if !analyze && !renderDepth && !renderCRT { analyze = true }

        let outURL = URL(fileURLWithPath: out, isDirectory: true)
        try? FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
        let analyzer = LivingStillSubjectAnalyzer()
        let context = CIContext()
        var rows: [String] = []

        for path in images {
            let url = URL(fileURLWithPath: path)
            let name = url.deletingPathExtension().lastPathComponent
            do {
                let digest = try ContentHasher.sha256File(url)
                if renderDepth || renderCRT {
                    let admitted = try await LocalMediaAdmission().admit(url)
                    guard admitted.kind == .still else {
                        throw StandaloneExportError.wrongMediaKind("bakeoff render inputs must be still images")
                    }
                    let geometry = try RenderedOutputGeometry(source: admitted.dimensions, maximumLongEdge: 1920)
                    if renderDepth {
                        let request = LivingStillDepthRenderRequest(
                            sourceURL: admitted.url,
                            sourceSHA256: admitted.sha256,
                            targetWidth: geometry.width,
                            targetHeight: geometry.height,
                            durationSeconds: 4,
                            fps: 30,
                            motionStrength: depthMotionStrength,
                            pushIn: depthPushIn,
                            panX: 0.012,
                            panY: -0.006,
                            depthSmoothing: 0.35,
                            seed: UInt64(admitted.sha256.prefix(16), radix: 16) ?? 0
                        )
                        let artifact = try LivingStillDepthRenderer().render(
                            request,
                            in: outURL.appendingPathComponent("living-still-v2", isDirectory: true)
                        )
                        print("\(name): LIVING STILL v2 \(artifact.movieURL.path) sha256=\(artifact.movieSHA256)")
                    }
                    if renderCRT {
                        let request = OldTelevisionRenderRequest(
                            sourceURL: admitted.url,
                            sourceSHA256: admitted.sha256,
                            sourceKind: .still,
                            targetWidth: geometry.width,
                            targetHeight: geometry.height,
                            duration: OldTelevisionRational(4),
                            frameRate: OldTelevisionRational(30),
                            profile: .broadcastMono,
                            intensity: 0.68,
                            scanlines: 0.42,
                            noise: 0.28,
                            syncInstability: 0.22,
                            chromaticSeparation: 0.18,
                            bloom: 0.20,
                            vignette: 0.34,
                            ghosting: 0.10,
                            flicker: 0.12,
                            seed: 7341
                        )
                        let artifact = try OldTelevisionRenderAdapter().render(
                            request,
                            in: outURL.appendingPathComponent("old-television-v2", isDirectory: true)
                        )
                        print("\(name): OLD TELEVISION v2 \(artifact.url.path) sha256=\(artifact.sha256)")
                    }
                }

                guard analyze else { continue }
                let (analysisResult, image, mask) = try analyzer.analyze(url: url, sourceSHA256: digest)

                let subjectText: String
                switch analysisResult.subject {
                case .none: subjectText = "none"
                case .single(_, let c): subjectText = String(format: "single (%.1f%% of frame)", c * 100)
                case .multiple(let i, _): subjectText = "multiple (\(i.count))"
                }
                let complexity = analysisResult.boundaryComplexity.map { String(format: "%.3f", $0) } ?? "—"
                rows.append("| \(name) | \(analysisResult.geometry.width)×\(analysisResult.geometry.height)\(analysisResult.geometry.isPortrait ? " portrait" : "") | \(subjectText) | \(complexity) |")
                print("\(name): \(analysisResult.geometry.width)×\(analysisResult.geometry.height) subject=\(subjectText) complexity=\(complexity)")

                // Mask visualization: subject in colour, background dimmed, so
                // halos and matte errors are visible at a glance.
                if let mask {
                    let dimmed = image.applyingFilter("CIColorControls", parameters: ["inputBrightness": -0.45, "inputSaturation": 0.15])
                    let composited = image.applyingFilter("CIBlendWithMask", parameters: [
                        kCIInputBackgroundImageKey: dimmed,
                        kCIInputMaskImageKey: mask.transformed(by: CGAffineTransform(
                            scaleX: image.extent.width / max(mask.extent.width, 1),
                            y: image.extent.height / max(mask.extent.height, 1)))
                    ])
                    write(composited, to: outURL.appendingPathComponent("\(name)-subject.png"), context: context)
                    write(mask, to: outURL.appendingPathComponent("\(name)-mask.png"), context: context)
                } else {
                    print("  (no subject mask — depth route only)")
                }
            } catch {
                print("\(name): FAILED — \(error.localizedDescription)")
                rows.append("| \(name) | — | **failed** | — |")
            }
        }

        let table = ("| image | normalized | subject | boundary complexity |\n| --- | --- | --- | --- |\n"
                     + rows.joined(separator: "\n") + "\n")
        try? table.write(to: outURL.appendingPathComponent("analysis.md"), atomically: true, encoding: .utf8)
        print("\nartifacts: \(outURL.path)")
    }

    private static func write(_ image: CIImage, to url: URL, context: CIContext) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        try? context.writePNGRepresentation(of: image, to: url, format: .RGBA8, colorSpace: space)
    }
}
