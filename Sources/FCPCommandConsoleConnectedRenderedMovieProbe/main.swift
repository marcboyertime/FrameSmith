import Foundation
import FCPCommandConsoleCore
import Darwin

/// Builds an inert connected-rendered-movie admission package, or verifies a
/// returned Final Cut export without writing to the evidence package.
@main
struct FCPCommandConsoleConnectedRenderedMovieProbeCLI {
    private static let runtimeRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/FCPCommandConsole", isDirectory: true)
    private static let defaultFixtureRoot = runtimeRoot.appendingPathComponent("fixtures").path
    private static let defaultExportRoot = runtimeRoot.appendingPathComponent("exports/connected-rendered-movie-probes").path

    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments == ["--help"] || arguments == ["help"] {
                print(usage)
                return
            }
            guard let command = arguments.first else { throw CLIError.usage }
            switch command {
            case "build":
                try runBuild(arguments: Array(arguments.dropFirst()))
            case "verify":
                try runVerify(arguments: Array(arguments.dropFirst()))
            default:
                throw CLIError.usage
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n\(usage)\n".utf8))
            exit(1)
        }
    }

    private static func runBuild(arguments: [String]) throws {
        let configuration = try parseBuild(arguments: arguments)
        guard NativeFCPXMLDTD.isInstalled(version: configuration.fcpxmlVersion) else {
            throw CLIError.missingDTD(configuration.fcpxmlVersion)
        }
        let builder = ConnectedRenderedMovieProbeBuilder(
            parentKind: configuration.parentKind,
            fixtureRoot: URL(fileURLWithPath: configuration.fixtureRoot),
            exportRoot: URL(fileURLWithPath: configuration.exportRoot),
            fcpxmlVersion: configuration.fcpxmlVersion
        )
        let package = try builder.build(operationID: configuration.operationID ?? UUID())
        print("probe: connected-rendered-movie-over-\(package.parentKind.rawValue)")
        print("package: \(package.packageRoot.path)")
        print("fcpxml: \(package.fcpxmlURL.path)")
        print("source: \(package.sourceMediaURL.path)")
        print("source sha256: \(package.sourceSHA256)")
        print("rendered movie: \(package.renderedMediaURL.path)")
        print("rendered sha256: \(package.renderedSHA256)")
        print("next-step documentation: \(package.instructionsURL.path)")
    }

    private static func runVerify(arguments: [String]) throws {
        let configuration = try parseVerify(arguments: arguments)
        guard NativeFCPXMLDTD.isInstalled(version: configuration.fcpxmlVersion) else {
            throw CLIError.missingDTD(configuration.fcpxmlVersion)
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier(
            fcpxmlVersion: configuration.fcpxmlVersion
        ).verify(
            packageRoot: URL(fileURLWithPath: configuration.packageRoot),
            returnedXMLURL: URL(fileURLWithPath: configuration.returnedXML)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        if report.status != .pass { exit(2) }
    }

    private struct BuildConfiguration {
        let parentKind: ConnectedRenderedMovieProbeParentKind
        let fixtureRoot: String
        let exportRoot: String
        let fcpxmlVersion: String
        let operationID: UUID?
    }

    private struct VerifyConfiguration {
        let packageRoot: String
        let returnedXML: String
        let fcpxmlVersion: String
    }

    private enum CLIError: Error, LocalizedError {
        case usage
        case missingParent
        case invalidParent(String)
        case invalidUUID
        case missingPackage
        case missingReturnedXML
        case missingDTD(String)

        var errorDescription: String? {
            switch self {
            case .usage:
                return "invalid arguments"
            case .missingParent:
                return "build requires --parent still|movie"
            case .invalidParent(let value):
                return "--parent must be still or movie, got \(value)"
            case .invalidUUID:
                return "--operation-id must be a UUID"
            case .missingPackage:
                return "verify requires --package PATH"
            case .missingReturnedXML:
                return "verify requires --returned PATH"
            case .missingDTD(let version):
                return "FCPXML \(version) DTD is not installed at \(NativeFCPXMLDTD.url(forVersion: version).path). Refusing to silently use a different version."
            }
        }
    }

    private static func parseBuild(arguments: [String]) throws -> BuildConfiguration {
        var parentKind: ConnectedRenderedMovieProbeParentKind?
        var fixtureRoot = defaultFixtureRoot
        var exportRoot = defaultExportRoot
        var fcpxmlVersion = ConnectedRenderedMovieProbeBuilder.preferredFCPXMLVersion
        var operationID: UUID?
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw CLIError.usage }
            let argument = arguments[index]
            let value = arguments[index + 1]
            switch argument {
            case "--parent":
                guard let parsed = ConnectedRenderedMovieProbeParentKind(rawValue: value) else {
                    throw CLIError.invalidParent(value)
                }
                parentKind = parsed
            case "--fixture-root":
                fixtureRoot = value
            case "--export-root":
                exportRoot = value
            case "--fcpxml-version":
                fcpxmlVersion = value
            case "--operation-id":
                guard let parsed = UUID(uuidString: value) else { throw CLIError.invalidUUID }
                operationID = parsed
            default:
                throw CLIError.usage
            }
            index += 2
        }
        guard let parentKind else { throw CLIError.missingParent }
        return BuildConfiguration(
            parentKind: parentKind,
            fixtureRoot: fixtureRoot,
            exportRoot: exportRoot,
            fcpxmlVersion: fcpxmlVersion,
            operationID: operationID
        )
    }

    private static func parseVerify(arguments: [String]) throws -> VerifyConfiguration {
        var packageRoot: String?
        var returnedXML: String?
        var fcpxmlVersion = ConnectedRenderedMovieProbeBuilder.preferredFCPXMLVersion
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw CLIError.usage }
            let argument = arguments[index]
            let value = arguments[index + 1]
            switch argument {
            case "--package":
                packageRoot = value
            case "--returned":
                returnedXML = value
            case "--fcpxml-version":
                fcpxmlVersion = value
            default:
                throw CLIError.usage
            }
            index += 2
        }
        guard let packageRoot else { throw CLIError.missingPackage }
        guard let returnedXML else { throw CLIError.missingReturnedXML }
        return VerifyConfiguration(
            packageRoot: packageRoot,
            returnedXML: returnedXML,
            fcpxmlVersion: fcpxmlVersion
        )
    }

    private static var usage: String {
        """
        usage: fcpcommandconsole-connected-rendered-movie-probe build --parent still|movie
                   [--fixture-root PATH] [--export-root PATH]
                   [--fcpxml-version VERSION] [--operation-id UUID]
               fcpcommandconsole-connected-rendered-movie-probe verify --package PATH
                   --returned PATH [--fcpxml-version VERSION]

        build creates one immutable, inert admission package. It does not launch
        or automate Final Cut Pro. verify is read-only and returns exit 2 when
        the returned document is well-formed but fails one or more contract checks.
        """
    }
}
