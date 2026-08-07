import XCTest
@testable import FCPCommandConsoleCore

/// Records what Surprise Me can *actually* offer today, per scenario.
///
/// This exists because "up to three options" is easy to claim and easy to get
/// wrong in either direction — padding a thin set, or silently returning one
/// when three were available. The numbers here are the shipped coverage, and a
/// change to them should be a deliberate edit.
final class TreatmentOptionCoverageTests: XCTestCase {
    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func catalog() throws -> EditorialKnowledgeCatalog {
        try EditorialKnowledgeCatalog.load(from: root().appendingPathComponent("registry/editorial-techniques"))
    }
    private var capabilities: Set<String> {
        Set(FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts.map(\.rawValue))
    }
    private func still(_ id: String, _ d: Character) -> LocalMediaAsset {
        LocalMediaAsset(itemID: id, url: URL(fileURLWithPath: "/tmp/\(id).png"), kind: .still,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080), durationSeconds: nil,
            frameRate: nil, hasAudio: false, canonicalPath: "/tmp/\(id).png", sha256: String(repeating: d, count: 64))
    }
    private func plans(_ a: LocalMediaAsset) throws -> [EffectID: EffectPlan] {
        let token = SelectionToken(selectionType: .singleClip, clipIDs: [a.itemID],
            sourceIdentities: [a.sourceIdentity], revision: "r1", sourceDurationFrames: 240)
        let registry = try EffectRegistry.load(from: root().appendingPathComponent("registry/effects"))
        var out: [EffectID: EffectPlan] = [:]
        for effect in EffectID.allCases {
            var p = try DeterministicPlanner(registry: registry).plan(
                request: "Make this a living still.", selection: token, target: Target.confirmed(x: 0.6, y: 0.4))
            p.effectID = effect; p.selectionToken.origin = .localMedia
            out[effect] = p
        }
        return out
    }

    /// A single admitted still with a confirmed focal target — the first
    /// shipped scenario. Motion, look, and a directed variant are all reachable.
    func testSingleStillScenarioOffersMoreThanOneGenuineChoice() throws {
        let asset = still("a", "a")
        let lock = EditorialStructureLock.establish(orderedMedia: [asset], clipDurationFrames: [120])
        let set = TreatmentOptionGenerator(catalog: try catalog(), admittedCapabilities: capabilities)
            .generate(lock: lock, media: [.primary: asset],
                      intent: TreatmentIntent(originalWording: "give this some atmosphere", intensity: .present),
                      basePlans: try plans(asset))

        XCTAssertGreaterThanOrEqual(set.options.count, 2, "a still should reach at least two genuine treatments")
        XCTAssertLessThanOrEqual(set.options.count, 3)
        // Coverage is only meaningful if the options span more than one domain.
        let cards = try catalog()
        let domains = Set(try set.options.map { try XCTUnwrap(cards.card(id: $0.techniqueCardIDs[0])).domain })
        XCTAssertGreaterThanOrEqual(domains.count, 2, "options that all come from one domain are not a real spread")
        for option in set.options { XCTAssertEqual(option.structureFingerprint, lock.fingerprint) }
    }

    /// A context whose only admitted treatment is one transition must return
    /// the genuine choice rather than three renamed versions of it.
    func testThinContextReturnsTheGenuineChoiceOnly() throws {
        let asset = still("a", "a")
        let lock = EditorialStructureLock.establish(orderedMedia: [asset], clipDurationFrames: [120])
        // Only the dissolve's contracts are admitted.
        let thin: Set<String> = ["asset_admission", "cross_dissolve_transition"]
        let set = TreatmentOptionGenerator(catalog: try catalog(), admittedCapabilities: thin)
            .generate(lock: lock, media: [.primary: asset],
                      intent: TreatmentIntent(originalWording: "soften this cut"),
                      basePlans: try plans(asset))
        XCTAssertLessThanOrEqual(set.options.count, 1, "a one-technique context must not be padded to three")
        if set.options.count < 3 { XCTAssertNotNil(set.shortfallExplanation) }
    }
}
