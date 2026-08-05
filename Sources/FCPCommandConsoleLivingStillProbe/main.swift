import Foundation
import FCPCommandConsoleCore
import Darwin

/// Generates the living still admission probe package.
///
/// A separate executable from the round-trip spike on purpose: that one
/// produces the four spent dissolve probes, and those packages are evidence.
@main
struct FCPCommandConsoleLivingStillProbeCLI {
    private static let defaultFixtureRoot = "/Users/marcboyer/Movies/FCPCommandConsole/fixtures"
    private static let defaultExportRoot = "/Users/marcboyer/Movies/FCPCommandConsole/exports/living-still-probes"

    static func main() {
        do {
            if CommandLine.arguments.dropFirst().contains("--help") {
                guard CommandLine.arguments.count == 2 else { throw CLIError.usage }
                print(usage)
                return
            }
            let configuration = try parse(arguments: Array(CommandLine.arguments.dropFirst()))
            let builder = LivingStillProbeBuilder(
                fixtureRoot: URL(fileURLWithPath: configuration.fixtureRoot),
                exportRoot: URL(fileURLWithPath: configuration.exportRoot),
                fcpxmlVersion: configuration.fcpxmlVersion
            )
            guard NativeFCPXMLDTD.isInstalled(version: configuration.fcpxmlVersion) else {
                throw CLIError.missingDTD(configuration.fcpxmlVersion)
            }
            let package = try builder.build(operationID: configuration.operationID ?? UUID())
            print("package: \(package.packageRoot.path)")
            print("fcpxml: \(package.fcpxmlURL.path)")
            print("fcpxml version: \(package.fcpxmlVersion)")
            print("media sha256: \(package.mediaSHA256)")
            print("next-step documentation: \(package.instructionsURL.path)")
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n\(usage)\n".utf8))
            exit(1)
        }
    }

    private struct Configuration {
        let fixtureRoot: String
        let exportRoot: String
        let fcpxmlVersion: String
        let operationID: UUID?
    }

    private enum CLIError: Error, LocalizedError {
        case usage
        case invalidUUID
        case missingDTD(String)

        var errorDescription: String? {
            switch self {
            case .usage: return "invalid arguments"
            case .invalidUUID: return "--operation-id must be a UUID"
            case .missingDTD(let version):
                return "FCPXML \(version) DTD is not installed at \(NativeFCPXMLDTD.url(forVersion: version).path). Refusing to silently emit against a different version."
            }
        }
    }

    private static func parse(arguments: [String]) throws -> Configuration {
        var fixtureRoot = defaultFixtureRoot
        var exportRoot = defaultExportRoot
        var fcpxmlVersion = LivingStillProbeBuilder.preferredFCPXMLVersion
        var operationID: UUID?
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard index + 1 < arguments.count else { throw CLIError.usage }
            let value = arguments[index + 1]
            switch argument {
            case "--fixture-root": fixtureRoot = value
            case "--export-root": exportRoot = value
            case "--fcpxml-version": fcpxmlVersion = value
            case "--operation-id":
                guard let parsed = UUID(uuidString: value) else { throw CLIError.invalidUUID }
                operationID = parsed
            default: throw CLIError.usage
            }
            index += 2
        }
        return Configuration(fixtureRoot: fixtureRoot, exportRoot: exportRoot, fcpxmlVersion: fcpxmlVersion, operationID: operationID)
    }

    private static var usage: String {
        """
        usage: fcpcommandconsole-living-still-probe [--fixture-root PATH] [--export-root PATH] [--fcpxml-version V] [--operation-id UUID]

        Generates one immutable living still admission probe package. It does not
        launch or automate Final Cut Pro. DTD validation is a syntax check, not
        acceptance: dissolve revisions 1 and 3 were both valid and both were
        rewritten on import.
        """
    }
}
