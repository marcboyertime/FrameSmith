import Foundation
import FCPCommandConsoleCore
import Darwin

/// Drives the standalone FCPXML export route end to end from real local media.
///
/// The route was gated, emitted, and unit-tested before this existed, but no
/// package it produced had ever been shown to Final Cut. This project's whole
/// discipline is that a passing test is not acceptance, so the route could not
/// be called finished until something it generated was imported.
@main
struct FCPCommandConsoleStandaloneExportCLI {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.contains("--help") {
                print(usage)
                return
            }
            let configuration = try parse(arguments: arguments)

            // Media goes through the real admission path; the gate will not
            // accept anything that did not.
            let admission = LocalMediaAdmission()
            let admitted = try await admission.admitAll([URL(fileURLWithPath: configuration.mediaPath)])
            guard let asset = admitted.assets.first else { throw CLIError.admissionProducedNoEvidence }
            let mediaEvidence = admitted.evidence

            let registry = try EffectRegistry.load(from: URL(fileURLWithPath: configuration.registryPath))
            let selection = SelectionToken(
                selectionType: .singleClip,
                clipIDs: [asset.itemID],
                sourceIdentities: [asset.sourceIdentity],
                revision: "standalone-1"
            )
            var plan = try DeterministicPlanner(registry: registry).plan(
                request: configuration.request,
                selection: selection,
                target: Target.confirmed(x: configuration.targetX, y: configuration.targetY)
            )
            plan.effectID = configuration.effectID
            plan.selectionToken.origin = .localMedia

            let installed = InstalledFinalCutVersionReader().read()
            let gate = CapabilityGate(
                manualSemanticsEvidence: installed.map { FinalCutSemanticProfileStore.evidence(forInstalled: $0) } ?? .unknown
            )
            let builder = StandaloneFCPXMLExportBuilder(gate: gate)
            let package = try builder.export(
                plan: plan,
                media: [.primary: asset],
                mediaEvidence: mediaEvidence,
                installedFinalCut: installed
            )

            print("effect: \(package.effectID.rawValue)")
            print("package: \(package.packageRoot.path)")
            print("fcpxml: \(package.fcpxmlURL.path)")
            print("provenance: \(package.provenanceURL.path)")
            print("instructions: \(package.instructionsURL.path)")
            print("admitted against: \(package.admittedAgainst?.description ?? "no profile")")
            for (name, hash) in package.mediaSHA256.sorted(by: { $0.key < $1.key }) {
                print("media \(name): \(hash)")
            }
            print("")
            print("This generated a NEW project. It did not modify any existing timeline.")
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n\n\(usage)\n".utf8))
            exit(1)
        }
    }

    private struct Configuration {
        let effectID: EffectID
        let mediaPath: String
        let request: String
        let targetX: Double
        let targetY: Double
        let registryPath: String
    }

    private enum CLIError: Error, LocalizedError {
        case usage
        case unknownEffect(String)
        case invalidNumber(String)
        case admissionProducedNoEvidence

        var errorDescription: String? {
            switch self {
            case .usage: return "invalid arguments"
            case .unknownEffect(let value):
                return "--effect must be one of \(EffectID.allCases.map(\.rawValue).joined(separator: ", ")), got \(value)"
            case .invalidNumber(let value): return "expected a number, got \(value)"
            case .admissionProducedNoEvidence:
                return "local media admission produced no usable evidence"
            }
        }
    }

    private static func parse(arguments: [String]) throws -> Configuration {
        var effectID = EffectID.livingStill
        var mediaPath: String?
        var request: String?
        var targetX = 0.5
        var targetY = 0.5
        var registryPath = FileManager.default.currentDirectoryPath + "/registry/effects"

        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw CLIError.usage }
            let value = arguments[index + 1]
            switch arguments[index] {
            case "--effect":
                guard let parsed = EffectID(identifier: value) else { throw CLIError.unknownEffect(value) }
                effectID = parsed
            case "--media": mediaPath = value
            case "--request": request = value
            case "--target-x":
                guard let parsed = Double(value) else { throw CLIError.invalidNumber(value) }
                targetX = parsed
            case "--target-y":
                guard let parsed = Double(value) else { throw CLIError.invalidNumber(value) }
                targetY = parsed
            case "--registry": registryPath = value
            default: throw CLIError.usage
            }
            index += 2
        }
        guard let mediaPath else { throw CLIError.usage }
        // The deterministic planner fails closed on an ambiguous request, and
        // several effects share vocabulary ("push in" matches both the living
        // still and rotate/zoom). Defaulting per effect keeps --request a
        // refinement rather than something the caller has to get exactly right.
        return Configuration(
            effectID: effectID,
            mediaPath: mediaPath,
            request: request ?? defaultRequest(for: effectID),
            targetX: targetX,
            targetY: targetY,
            registryPath: registryPath
        )
    }

    private static func defaultRequest(for effectID: EffectID) -> String {
        switch effectID {
        case .livingStill: return "Make this a living still."
        case .targetedRotateZoom: return "Give this image a slow clockwise rotation while zooming toward the point I select."
        case .naturalDissolve: return "Put a natural dissolve between these two clips."
        case .oldTelevision: return "Give this an old television look."
        }
    }

    private static var usage: String {
        """
        usage: fcpcommandconsole-standalone-export --media PATH
                                                  [--effect motion.living_still|native.targeted_rotate_zoom]
                                                  [--request TEXT] [--target-x N] [--target-y N]
                                                  [--registry PATH]

        Generates a NEW Final Cut project from admitted local media and writes a
        self-contained package. It does not open Final Cut and does not modify
        any existing timeline.

        The capability gate runs first and refuses anything the installed Final
        Cut build's semantic profile does not admit.
        """
    }
}
