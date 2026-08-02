import Foundation
import FCPCommandConsoleCore
import Darwin

enum CLIError: Error, LocalizedError {
    case usage(String)
    case missing(String)
    var errorDescription: String? {
        switch self { case .usage(let value), .missing(let value): return value }
    }
}

@main
struct FCPCommandConsoleCLI {
    static func main() {
        do {
            try run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func run(_ args: [String]) throws {
        guard let command = args.first else { throw CLIError.usage(usage) }
        let registry = try EffectRegistry.discover()
        switch command {
        case "doctor-core": try doctor(registry)
        case "plan": try plan(args: Array(args.dropFirst()), registry: registry)
        case "generate-overlays": try generate(args: Array(args.dropFirst()))
        case "validate-plan": try validate(args: Array(args.dropFirst()), registry: registry)
        default: throw CLIError.usage(usage)
        }
    }

    static func doctor(_ registry: EffectRegistry) throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let registryURL = cwd.appendingPathComponent("registry/effects")
        let schemaURL = cwd.appendingPathComponent("schemas/effect-plan.schema.json")
        let runtime = PathPolicy.defaultOutputRoot
        let lines = [
            "registry: \(registryURL.path) (\(registry.all.count) definitions)",
            "schema: \(schemaURL.path) (\(fm.fileExists(atPath: schemaURL.path) ? "present" : "missing"))",
            "runtime-root: \(runtime.path)",
            "overlays-root: \(runtime.appendingPathComponent("overlays").path)",
            "ffmpeg: \(SafeFFmpegOverlayAdapter.ffmpegURL.path) (\(fm.isExecutableFile(atPath: SafeFFmpegOverlayAdapter.ffmpegURL.path) ? "executable" : "missing"))",
            "ffprobe: \(SafeFFmpegOverlayAdapter.ffprobeURL.path) (\(fm.isExecutableFile(atPath: SafeFFmpegOverlayAdapter.ffprobeURL.path) ? "executable" : "missing"))",
            "network: disabled",
            "final-cut-runtime: not touched"
        ]
        print(lines.joined(separator: "\n"))
    }

    static func plan(args: [String], registry: EffectRegistry) throws {
        var request: String?
        var selectionPath: String?
        var x: Double?
        var y: Double?
        var index = 0
        while index < args.count {
            switch args[index] {
            case "--request": index += 1; guard index < args.count else { throw CLIError.usage(usage) }; request = args[index]
            case "--selection-fixture": index += 1; guard index < args.count else { throw CLIError.usage(usage) }; selectionPath = args[index]
            case "--target-x": index += 1; guard index < args.count else { throw CLIError.usage(usage) }; x = Double(args[index])
            case "--target-y": index += 1; guard index < args.count else { throw CLIError.usage(usage) }; y = Double(args[index])
            default: throw CLIError.usage(usage)
            }
            index += 1
        }
        guard let request, let selectionPath else { throw CLIError.usage(usage) }
        let point: Target?
        if let x, let y { point = Target.confirmed(x: x, y: y) }
        else if x != nil || y != nil { throw CLIError.usage("--target-x and --target-y must be supplied together") }
        else { point = nil }
        let planner = DeterministicPlanner(registry: registry)
        let plan = try planner.plan(request: request, selectionFixture: URL(fileURLWithPath: selectionPath), target: point)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        FileHandle.standardOutput.write(try encoder.encode(plan)); print()
    }

    private struct OverlayFixture: Codable {
        var request: OverlayRequest
        var outputRoot: String
    }

    static func generate(args: [String]) throws {
        guard args.count == 2, args[0] == "--fixture" else { throw CLIError.usage(usage) }
        let fixture = try JSONDecoder().decode(OverlayFixture.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        let outputURL = fixture.outputRoot.hasPrefix("file:") ? (URL(string: fixture.outputRoot) ?? URL(fileURLWithPath: fixture.outputRoot)) : URL(fileURLWithPath: fixture.outputRoot)
        let metadata = try SafeFFmpegOverlayAdapter().generate(fixture.request, in: outputURL)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(metadata)); print()
    }

    static func validate(args: [String], registry: EffectRegistry) throws {
        guard args.count == 1 else { throw CLIError.usage(usage) }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let plan = try decoder.decode(EffectPlan.self, from: Data(contentsOf: URL(fileURLWithPath: args[0])))
        try PlanValidator(registry: registry).validate(plan)
        print("valid: \(plan.operationID.uuidString) \(plan.effectID.rawValue)")
    }

    static let usage = """
    fcpcommandconsole doctor-core
    fcpcommandconsole plan --request <text> --selection-fixture <path> [--target-x <0..1> --target-y <0..1>]
    fcpcommandconsole generate-overlays --fixture <path>
    fcpcommandconsole validate-plan <path>
    """
}
