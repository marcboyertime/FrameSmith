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
        case "plan-bounded": try planBounded(args: Array(args.dropFirst()), registry: registry)
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
        try emit(plan, registry: registry)
    }

    /// Bounded, offline plan construction. The command intentionally accepts
    /// only a request, explicit source paths/IDs, a revision, and an optional
    /// confirmed normalized target; it has no method, shell, or backend flags.
    static func planBounded(args: [String], registry: EffectRegistry) throws {
        var request: String?
        var sourcePaths: [String] = []
        var sourceIDs: [String] = []
        var revision: String?
        var x: Double?
        var y: Double?
        var index = 0
        while index < args.count {
            let argument = args[index]
            switch argument {
            case "--request":
                guard request == nil, let value = nextArgument(args, index: &index), !value.isEmpty else { throw CLIError.usage(usage) }
                request = value
            case "--source":
                guard let value = nextArgument(args, index: &index), !value.isEmpty else { throw CLIError.usage(usage) }
                sourcePaths.append(value)
            case "--source-id":
                guard let value = nextArgument(args, index: &index), !value.isEmpty else { throw CLIError.usage(usage) }
                sourceIDs.append(value)
            case "--revision":
                guard revision == nil, let value = nextArgument(args, index: &index), !value.isEmpty else { throw CLIError.usage(usage) }
                revision = value
            case "--target-x":
                guard x == nil, let value = nextArgument(args, index: &index), let parsed = Double(value), parsed.isFinite else { throw CLIError.usage(usage) }
                x = parsed
            case "--target-y":
                guard y == nil, let value = nextArgument(args, index: &index), let parsed = Double(value), parsed.isFinite else { throw CLIError.usage(usage) }
                y = parsed
            default:
                throw CLIError.usage(usage)
            }
            index += 1
        }

        guard let request, let revision, !sourcePaths.isEmpty, sourcePaths.count <= 2, sourcePaths.count == sourceIDs.count else {
            throw CLIError.usage(usage)
        }
        let point: Target?
        if let x, let y {
            guard (0...1).contains(x), (0...1).contains(y) else { throw CLIError.usage("confirmed target coordinates must be within [0,1]") }
            point = Target(x: x, y: y, confirmed: true)
        } else if x != nil || y != nil {
            throw CLIError.usage("--target-x and --target-y must be supplied together")
        } else {
            point = nil
        }

        let planner = DeterministicPlanner(registry: registry)
        let effectID = try planner.parser.parse(request).effectID
        let expectedSources = effectID == .naturalDissolve ? 2 : 1
        guard sourcePaths.count == expectedSources else {
            throw CLIError.usage("\(effectID?.rawValue ?? "effect") requires exactly \(expectedSources) source path(s)")
        }
        let identities = try zip(sourcePaths, sourceIDs).map { try sourceIdentity(path: $0, itemID: $1) }
        let clips = sourceIDs
        let isDissolve = effectID == .naturalDissolve
        let tokenSeed = [request, revision] + identities.flatMap { [$0.itemID, $0.canonicalPath, $0.sha256] }
        let tokenID = deterministicUUID(seed: tokenSeed.joined(separator: "|"), salt: "selection")
        let selection = SelectionToken(
            tokenID: tokenID.uuidString,
            selectionType: isDissolve ? .twoAdjacentClips : .singleClip,
            timelineID: "bounded-cli-timeline",
            origin: .unverifiedExternal,
            clipIDs: clips,
            sourceIdentities: identities,
            revision: revision,
            startFrame: isDissolve ? 100 : 0,
            endFrame: isDissolve ? 112 : 24,
            sourceDurationFrames: isDissolve ? 1000 : 240,
            sourceRangeStartFrame: isDissolve ? 0 : nil,
            sourceRangeEndFrame: isDissolve ? 500 : nil,
            boundaryFrame: isDissolve ? 100 : nil,
            frameRate: isDissolve ? 24 : nil,
            handleBeforeFrames: isDissolve ? 12 : 0,
            handleAfterFrames: isDissolve ? 12 : 0,
            isSpine: true,
            adjacent: true
        )
        let operationID = deterministicUUID(seed: tokenSeed.joined(separator: "|"), salt: "operation")
        let plan = try planner.plan(request: request, selection: selection, target: point, operationID: operationID)
        try emit(plan, registry: registry)
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
        let data = try Data(contentsOf: URL(fileURLWithPath: args[0]))
        try PlanSchemaValidator(schemaURL: schemaURL()).validate(data)
        let plan = try decoder.decode(EffectPlan.self, from: data)
        try PlanValidator(registry: registry).validate(plan)
        print("valid: \(plan.operationID.uuidString) \(plan.effectID.rawValue)")
    }

    private static func emit(_ plan: EffectPlan, registry: EffectRegistry) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(plan)
        try PlanSchemaValidator(schemaURL: schemaURL()).validate(data)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        try PlanValidator(registry: registry).validate(try decoder.decode(EffectPlan.self, from: data))
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func schemaURL() throws -> URL {
        let fileManager = FileManager.default
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("schemas/effect-plan.schema.json"),
            URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("schemas/effect-plan.schema.json")
        ]
        guard let result = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            throw CLIError.missing("EffectPlan schema not found")
        }
        return result
    }

    private static func nextArgument(_ args: [String], index: inout Int) -> String? {
        index += 1
        guard index < args.count else { return nil }
        return args[index]
    }

    private static func sourceIdentity(path: String, itemID: String) throws -> SourceIdentity {
        guard isSafeStableItemID(itemID) else {
            throw CLIError.usage("source IDs must be non-empty stable identifiers without shell/path syntax")
        }
        let rawURL = URL(fileURLWithPath: path).absoluteURL
        let canonical = rawURL.standardizedFileURL
        guard canonical.path.hasPrefix("/"), !canonical.path.unicodeScalars.contains(where: { ";&|`$()<>*?{}\n\r".unicodeScalars.contains($0) }) else {
            throw CLIError.usage("source paths must be absolute after canonicalization and contain no shell metacharacters")
        }
        let resolved = canonical.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == canonical.path else { throw CLIError.usage("source paths must not be symlinks") }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: canonical.path, isDirectory: &isDirectory), !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: canonical.path) else {
            throw CLIError.missing("source fixture is not a readable regular file: \(canonical.path)")
        }
        guard !canonical.path.contains(".fcpbundle"), !canonical.path.contains("/Final Cut Pro Libraries/") else {
            throw CLIError.usage("Final Cut application/library paths are not accepted")
        }
        return SourceIdentity(itemID: itemID, canonicalPath: canonical.path, sha256: try ContentHasher.sha256File(canonical))
    }

    private static func isSafeStableItemID(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 256 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...90, 97...122, 45, 46, 58, 95:
                return true
            default:
                return false
            }
        }
    }

    private static func deterministicUUID(seed: String, salt: String) -> UUID {
        let digest = ContentHasher.sha256(Data("\(salt)|\(seed)".utf8))
        let value = "\(digest.prefix(8))-\(digest.dropFirst(8).prefix(4))-5\(digest.dropFirst(13).prefix(3))-8\(digest.dropFirst(16).prefix(3))-\(digest.dropFirst(19).prefix(12))"
        return UUID(uuidString: value)!
    }

    static let usage = """
    fcpcommandconsole doctor-core
    fcpcommandconsole plan --request <text> --selection-fixture <path> [--target-x <0..1> --target-y <0..1>]
    fcpcommandconsole plan-bounded --request <text> --source <fixture-path> --source-id <stable-id> [--source <fixture-path> --source-id <stable-id>] --revision <revision> [--target-x <0..1> --target-y <0..1>]
    fcpcommandconsole generate-overlays --fixture <path>
    fcpcommandconsole validate-plan <path>
    """
}
