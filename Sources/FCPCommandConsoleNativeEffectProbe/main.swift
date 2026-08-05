import Foundation
import FCPCommandConsoleCore
import Darwin

/// Generates the targeted rotate/zoom and old television admission probes.
///
/// A third probe executable, separate from the round-trip spike and the living
/// still probe on purpose: those two regenerate packages that are spent
/// evidence, and nothing here may be able to alter what they emit.
@main
struct FCPCommandConsoleNativeEffectProbeCLI {
    private static let defaultFixtureRoot = "/Users/marcboyer/Movies/FCPCommandConsole/fixtures"
    private static let defaultExportRoot = "/Users/marcboyer/Movies/FCPCommandConsole/exports/native-effect-probes"

    static func main() {
        do {
            if CommandLine.arguments.dropFirst().contains("--help") {
                guard CommandLine.arguments.count == 2 else { throw CLIError.usage }
                print(usage)
                return
            }
            let configuration = try parse(arguments: Array(CommandLine.arguments.dropFirst()))
            guard NativeFCPXMLDTD.isInstalled(version: configuration.fcpxmlVersion) else {
                throw CLIError.missingDTD(configuration.fcpxmlVersion)
            }
            for kind in configuration.kinds {
                let builder = NativeEffectProbeBuilder(
                    kind: kind,
                    fixtureRoot: URL(fileURLWithPath: configuration.fixtureRoot),
                    exportRoot: URL(fileURLWithPath: configuration.exportRoot),
                    fcpxmlVersion: configuration.fcpxmlVersion
                )
                let package = try builder.build()
                print("probe: \(kind.rawValue)")
                print("  effect: \(kind.effectID.rawValue)")
                print("  package: \(package.packageRoot.path)")
                print("  fcpxml: \(package.fcpxmlURL.path)")
                for (name, hash) in package.mediaSHA256.sorted(by: { $0.key < $1.key }) {
                    print("  media \(name): \(hash)")
                }
                print("  next-step documentation: \(package.instructionsURL.path)")
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n\(usage)\n".utf8))
            exit(1)
        }
    }

    private struct Configuration {
        let fixtureRoot: String
        let exportRoot: String
        let fcpxmlVersion: String
        let kinds: [NativeEffectProbeKind]
    }

    private enum CLIError: Error, LocalizedError {
        case usage
        case unknownKind(String)
        case missingDTD(String)

        var errorDescription: String? {
            switch self {
            case .usage: return "invalid arguments"
            case .unknownKind(let value):
                return "--kind must be one of \(NativeEffectProbeKind.allCases.map(\.rawValue).joined(separator: ", ")), got \(value)"
            case .missingDTD(let version):
                return "FCPXML \(version) DTD is not installed at \(NativeFCPXMLDTD.url(forVersion: version).path). Refusing to silently emit against a different version."
            }
        }
    }

    private static func parse(arguments: [String]) throws -> Configuration {
        var fixtureRoot = defaultFixtureRoot
        var exportRoot = defaultExportRoot
        var fcpxmlVersion = NativeEffectProbeBuilder.preferredFCPXMLVersion
        var kinds = NativeEffectProbeKind.allCases
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard index + 1 < arguments.count else { throw CLIError.usage }
            let value = arguments[index + 1]
            switch argument {
            case "--fixture-root": fixtureRoot = value
            case "--export-root": exportRoot = value
            case "--fcpxml-version": fcpxmlVersion = value
            case "--kind":
                guard let parsed = NativeEffectProbeKind(rawValue: value) else { throw CLIError.unknownKind(value) }
                kinds = [parsed]
            default: throw CLIError.usage
            }
            index += 2
        }
        return Configuration(fixtureRoot: fixtureRoot, exportRoot: exportRoot, fcpxmlVersion: fcpxmlVersion, kinds: kinds)
    }

    private static var usage: String {
        """
        usage: fcpcommandconsole-native-effect-probe [--kind targeted-rotate-zoom|old-television]
                                                    [--fixture-root PATH] [--export-root PATH]
                                                    [--fcpxml-version VERSION]

        Generates admission probe packages for the two Phase 1 effects whose
        encodings were captured on 2026-08-05. With no --kind, generates both.

        Each package is inert: it writes media, an FCPXML, an evidence ledger,
        and import instructions. Nothing is imported and no capability moves.
        """
    }
}
