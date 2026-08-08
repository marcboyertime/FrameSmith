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

            Runs Apple Vision subject analysis on each still and writes a mask
            visualization plus a JSON record per image. Artifacts go outside the
            repository, under the approved runtime root.
            """)
            return
        }

        var images: [String] = []
        var out = NSHomeDirectory() + "/Movies/FCPCommandConsole/exports/bakeoff"
        var index = 0
        while index < args.count {
            if args[index] == "--out", index + 1 < args.count { out = args[index + 1]; index += 2 }
            else { images.append(args[index]); index += 1 }
        }

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
                let (analysis, image, mask) = try analyzer.analyze(url: url, sourceSHA256: digest)

                let subjectText: String
                switch analysis.subject {
                case .none: subjectText = "none"
                case .single(_, let c): subjectText = String(format: "single (%.1f%% of frame)", c * 100)
                case .multiple(let i, _): subjectText = "multiple (\(i.count))"
                }
                let complexity = analysis.boundaryComplexity.map { String(format: "%.3f", $0) } ?? "—"
                rows.append("| \(name) | \(analysis.geometry.width)×\(analysis.geometry.height)\(analysis.geometry.isPortrait ? " portrait" : "") | \(subjectText) | \(complexity) |")
                print("\(name): \(analysis.geometry.width)×\(analysis.geometry.height) subject=\(subjectText) complexity=\(complexity)")

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
