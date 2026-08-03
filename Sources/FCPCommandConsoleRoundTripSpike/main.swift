import Foundation
import FCPCommandConsoleCore
import Darwin

@main
struct FCPCommandConsoleRoundTripSpikeCLI {
    private static let defaultFixtureRoot = "/Users/marcboyer/Movies/FCPCommandConsole/fixtures"
    private static let defaultExportRoot = "/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes"

    static func main() {
        do {
            if CommandLine.arguments.dropFirst().contains("--help") {
                guard CommandLine.arguments.count == 2 else { throw CLIError.usage }
                print(usage)
                return
            }
            let configuration = try parse(arguments: Array(CommandLine.arguments.dropFirst()))
            let package = try FCPXMLRoundTripSpikeBuilder(
                fixtureRoot: URL(fileURLWithPath: configuration.fixtureRoot),
                exportRoot: URL(fileURLWithPath: configuration.exportRoot)
            ).build(operationID: configuration.operationID ?? UUID())
            print("package: \(package.packageRoot.path)")
            print("next-step documentation: \(package.instructionsURL.path)")
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n\(usage)\n".utf8))
            exit(1)
        }
    }

    private struct Configuration {
        let fixtureRoot: String
        let exportRoot: String
        let operationID: UUID?
    }

    private enum CLIError: Error, LocalizedError {
        case usage
        case invalidUUID
        var errorDescription: String? {
            switch self {
            case .usage: return "invalid arguments"
            case .invalidUUID: return "--operation-id must be a UUID"
            }
        }
    }

    private static func parse(arguments: [String]) throws -> Configuration {
        var fixtureRoot = defaultFixtureRoot
        var exportRoot = defaultExportRoot
        var operationID: UUID?
        var seen = Set<String>()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard ["--fixture-root", "--export-root", "--operation-id"].contains(argument), !seen.contains(argument) else { throw CLIError.usage }
            seen.insert(argument)
            index += 1
            guard index < arguments.count else { throw CLIError.usage }
            let value = arguments[index]
            switch argument {
            case "--fixture-root":
                guard value.hasPrefix("/") else { throw CLIError.usage }
                fixtureRoot = value
            case "--export-root":
                guard value.hasPrefix("/") else { throw CLIError.usage }
                exportRoot = value
            case "--operation-id":
                guard let value = UUID(uuidString: value) else { throw CLIError.invalidUUID }
                operationID = value
            default: throw CLIError.usage
            }
            index += 1
        }
        return Configuration(fixtureRoot: fixtureRoot, exportRoot: exportRoot, operationID: operationID)
    }

    private static let usage = "Usage: fcpcommandconsole-roundtrip-spike [--fixture-root <absolute path>] [--export-root <absolute path>] [--operation-id <UUID>] [--help]"
}
