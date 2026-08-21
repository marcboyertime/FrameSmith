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
            var inputs = [URL(fileURLWithPath: configuration.mediaPath)]
            if let second = configuration.secondMediaPath { inputs.append(URL(fileURLWithPath: second)) }
            let admitted = try await admission.admitAll(inputs)
            guard let asset = admitted.assets.first else { throw CLIError.admissionProducedNoEvidence }
            let mediaEvidence = admitted.evidence
            let secondAsset = admitted.assets.count > 1 ? admitted.assets[1] : nil

            let registry = try EffectRegistry.load(from: URL(fileURLWithPath: configuration.registryPath))
            // A dissolve is a two-clip effect: the selection carries both
            // identities in the order the user supplied them, because order is
            // exactly what the editorial-structure lock protects.
            let selection = try makeSelection(
                effectID: configuration.effectID,
                first: asset,
                second: secondAsset,
                dissolveFrames: configuration.dissolveFrames
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
            let media = mediaRoles(
                effectID: configuration.effectID,
                first: asset,
                second: secondAsset
            )
            guard let emitter = StandaloneEmitterCatalog().emitter(for: plan.effectID) else {
                throw StandaloneExportError.noEmitter(
                    plan.effectID,
                    reason: StandaloneFCPXMLExportBuilder.missingEmitterReason(for: plan.effectID)
                )
            }
            let construction: StandaloneExportConstruction
            if let rendered = emitter as? any StandaloneRenderedEffectEmitter {
                let prepared = try rendered.prepareRenderedAsset(
                    plan: plan,
                    media: media,
                    outputRoot: StandaloneFCPXMLExportBuilder.defaultRenderCacheRoot
                )
                construction = .rendered(prepared)
            } else {
                construction = .native
            }
            let builder = StandaloneFCPXMLExportBuilder(gate: gate, registry: registry)
            let package = try builder.export(
                plan: plan,
                media: media,
                mediaEvidence: mediaEvidence,
                construction: construction,
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
        let secondMediaPath: String?
        let request: String
        let targetX: Double
        let targetY: Double
        let registryPath: String
        let dissolveFrames: Int
    }

    private enum CLIError: Error, LocalizedError {
        case usage
        case unknownEffect(String)
        case invalidNumber(String)
        case admissionProducedNoEvidence
        case insufficientHandle(Int)

        var errorDescription: String? {
            switch self {
            case .usage: return "invalid arguments"
            case .unknownEffect(let value):
                return "--effect must be one of \(EffectID.allCases.map(\.rawValue).joined(separator: ", ")), got \(value)"
            case .invalidNumber(let value): return "expected a number, got \(value)"
            case .admissionProducedNoEvidence:
                return "local media admission produced no usable evidence"
            case .insufficientHandle(let frames):
                return "each clip needs at least \(frames) frames of unused source for this dissolve; the edit point will not be moved to make room"
            }
        }
    }

    private static func parse(arguments: [String]) throws -> Configuration {
        var effectID = EffectID.livingStill
        var mediaPath: String?
        var secondMediaPath: String?
        var request: String?
        var targetX = 0.5
        var targetY = 0.5
        var registryPath = FileManager.default.currentDirectoryPath + "/registry/effects"
        var dissolveFrames = 12

        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw CLIError.usage }
            let value = arguments[index + 1]
            switch arguments[index] {
            case "--effect":
                guard let parsed = EffectID(identifier: value) else { throw CLIError.unknownEffect(value) }
                effectID = parsed
            case "--media": mediaPath = value
            case "--second-media", "--incoming": secondMediaPath = value
            case "--request": request = value
            case "--target-x":
                guard let parsed = Double(value) else { throw CLIError.invalidNumber(value) }
                targetX = parsed
            case "--target-y":
                guard let parsed = Double(value) else { throw CLIError.invalidNumber(value) }
                targetY = parsed
            case "--registry": registryPath = value
            case "--dissolve-frames":
                guard let parsed = Int(value) else { throw CLIError.invalidNumber(value) }
                dissolveFrames = parsed
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
            secondMediaPath: secondMediaPath,
            request: request ?? defaultRequest(for: effectID),
            targetX: targetX,
            targetY: targetY,
            registryPath: registryPath,
            dissolveFrames: dissolveFrames
        )
    }

    /// Builds the selection the validator expects.
    ///
    /// A dissolve is the interesting case. The validator requires a
    /// frame-quantized boundary, matching left/right source ranges, and enough
    /// handle on both sides for the requested duration — which is the same
    /// invariant the emitter enforces and the same one the director-control
    /// contract demands. The clips are butt-joined at the boundary and the
    /// handle is carved out of each clip's *unused* source, so the visible cut
    /// never moves to make room.
    private static func makeSelection(
        effectID: EffectID,
        first: LocalMediaAsset,
        second: LocalMediaAsset?,
        dissolveFrames: Int
    ) throws -> SelectionToken {
        let rate = 30
        guard effectID == .naturalDissolve, let second else {
            return SelectionToken(
                selectionType: .singleClip,
                clipIDs: [first.itemID],
                sourceIdentities: [first.sourceIdentity],
                revision: "standalone-1",
                sourceDurationFrames: first.durationSeconds.map { Int(($0 * Double(rate)).rounded()) }
            )
        }

        let leftSource = Int(((first.durationSeconds ?? 8) * Double(rate)).rounded())
        let rightSource = Int(((second.durationSeconds ?? 8) * Double(rate)).rounded())
        let handle = max(1, Int(ceil(Double(dissolveFrames) / 2.0)))
        guard leftSource > handle, rightSource > handle else {
            throw CLIError.insufficientHandle(handle)
        }

        // Left clip gives up its tail as handle; right clip gives up its head.
        let leftVisibleEnd = leftSource - handle
        let boundary = leftVisibleEnd
        let rightVisibleFrames = rightSource - handle

        return SelectionToken(
            selectionType: .twoAdjacentClips,
            clipIDs: [first.itemID, second.itemID],
            sourceIdentities: [first.sourceIdentity, second.sourceIdentity],
            revision: "standalone-1",
            startFrame: 0,
            endFrame: boundary + rightVisibleFrames,
            sourceDurationFrames: leftSource,
            sourceRangeStartFrame: 0,
            sourceRangeEndFrame: leftVisibleEnd,
            leftSourceDurationFrames: leftSource,
            rightSourceDurationFrames: rightSource,
            leftSourceRangeStartFrame: 0,
            leftSourceRangeEndFrame: leftVisibleEnd,
            rightSourceRangeStartFrame: handle,
            rightSourceRangeEndFrame: rightSource,
            leftClipEndFrame: boundary,
            rightClipStartFrame: boundary,
            boundaryFrame: boundary,
            frameRate: rate,
            handleBeforeFrames: handle,
            handleAfterFrames: handle,
            adjacent: true
        )
    }

    /// Maps admitted media onto the roles each effect expects.
    ///
    /// A dissolve wants outgoing/incoming; old television wants a base plus an
    /// overlay in the incoming slot. Getting this wrong produces a confusing
    /// "no admitted media for role" rather than a useful message.
    private static func mediaRoles(
        effectID: EffectID,
        first: LocalMediaAsset,
        second: LocalMediaAsset?
    ) -> [LocalMediaRole: LocalMediaAsset] {
        guard let second else { return [.primary: first] }
        switch effectID {
        case .naturalDissolve: return [.outgoing: first, .incoming: second]
        case .oldTelevision: return [.primary: first, .overlay: second]
        default: return [.primary: first, .incoming: second]
        }
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
        usage: fcpcommandconsole-standalone-export --media PATH [--second-media PATH]
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
