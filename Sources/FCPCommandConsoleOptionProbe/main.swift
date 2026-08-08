import Foundation
import FCPCommandConsoleCore

@main struct OptionProbe {
    struct Output: Codable { let optionIDs: [String]; let signatures: [String]; let names: [String]; let shortfall: String? }
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let registry = try EffectRegistry.load(from: root.appendingPathComponent("registry/effects"))
        let catalog = try EditorialKnowledgeCatalog.load(from: root.appendingPathComponent("registry/editorial-techniques"), knownSourceIDs: EditorialKnowledgeCatalog.sourceIDs(fromCSV: root.appendingPathComponent("docs/editorial-intelligence/sources.csv")))
        let asset = LocalMediaAsset(itemID: "probe", url: URL(fileURLWithPath: "/tmp/probe.png"), kind: .still, dimensions: .init(width: 1920, height: 1080), durationSeconds: nil, frameRate: nil, hasAudio: false, canonicalPath: "/tmp/probe.png", sha256: String(repeating: "a", count: 64))
        let token = SelectionToken(selectionType: .singleClip, clipIDs: [asset.itemID], sourceIdentities: [asset.sourceIdentity], revision: "probe", sourceDurationFrames: 240)
        var plans: [EffectID: EffectPlan] = [:]
        for effect in [EffectID.livingStill, .targetedRotateZoom, .oldTelevision] {
            let request: String
            switch effect {
            case .livingStill: request = "Make this a living still."
            case .targetedRotateZoom: request = "Use a targeted rotate and zoom."
            case .oldTelevision: request = "Make this old television."
            case .naturalDissolve: request = "Use a natural dissolve."
            }
            var plan = try DeterministicPlanner(registry: registry).plan(request: request, selection: token, target: .confirmed(x: 0.6, y: 0.4))
            plan.selectionToken.origin = .localMedia; plans[effect] = plan
        }
        let capabilities = Set(FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts.map(\.rawValue))
        let lock = EditorialStructureLock.establish(orderedMedia: [asset], clipDurationFrames: [120])
        let set = TreatmentOptionGenerator(catalog: catalog, admittedCapabilities: capabilities).generate(lock: lock, media: [.primary: asset], intent: TreatmentIntent(originalWording: "quiet cinematic"), basePlans: plans, seed: 42)
        let output = Output(optionIDs: set.options.map(\.optionID), signatures: set.options.map(\.constructionSignature), names: set.options.map(\.name), shortfall: set.shortfallExplanation)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        FileHandle.standardOutput.write(try encoder.encode(output)); FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
