import XCTest
@testable import FCPCommandConsoleCore

/// The generator's contract: never change the edit, never pad the list, never
/// offer something that cannot run, and never produce a different answer for
/// the same inputs.
final class TreatmentOptionGeneratorTests: XCTestCase {
    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }
    private func catalog() throws -> EditorialKnowledgeCatalog {
        try EditorialKnowledgeCatalog.load(
            from: projectRoot().appendingPathComponent("registry/editorial-techniques"),
            knownSourceIDs: EditorialKnowledgeCatalog.sourceIDs(
                fromCSV: projectRoot().appendingPathComponent("docs/editorial-intelligence/sources.csv"))
        )
    }
    private var capabilities: Set<String> {
        Set(FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts.map(\.rawValue))
    }

    private func still(_ id: String, digest: Character = "a") -> LocalMediaAsset {
        LocalMediaAsset(
            itemID: id, url: URL(fileURLWithPath: "/tmp/\(id).png"), kind: .still,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: nil, frameRate: nil, hasAudio: false,
            canonicalPath: "/tmp/\(id).png", sha256: String(repeating: digest, count: 64)
        )
    }

    private func lock(_ assets: [LocalMediaAsset]) -> EditorialStructureLock {
        EditorialStructureLock.establish(orderedMedia: assets, clipDurationFrames: assets.map { _ in 120 })
    }

    private func basePlans(for assets: [LocalMediaAsset]) throws -> [EffectID: EffectPlan] {
        let source = assets[0].sourceIdentity
        let token = SelectionToken(
            selectionType: .singleClip, clipIDs: [assets[0].itemID],
            sourceIdentities: [source], revision: "r1", sourceDurationFrames: 240
        )
        var plans: [EffectID: EffectPlan] = [:]
        for effect in [EffectID.livingStill, .targetedRotateZoom, .oldTelevision] {
            var plan = try DeterministicPlanner(registry: registry()).plan(
                request: "Make this a living still.", selection: token, target: Target.confirmed(x: 0.6, y: 0.4)
            )
            plan.effectID = effect
            plan.selectionToken.origin = .localMedia
            plans[effect] = plan
        }
        return plans
    }

    private func generator() throws -> TreatmentOptionGenerator {
        TreatmentOptionGenerator(catalog: try catalog(), admittedCapabilities: capabilities)
    }

    private func intent(_ wording: String, intensity: TreatmentIntensity = .restrained) -> TreatmentIntent {
        TreatmentIntent(originalWording: wording, intensity: intensity)
    }

    // MARK: - The edit is never touched

    /// The single most important assertion in this file.
    func testEveryOptionCarriesTheInputStructureFingerprint() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let set = try generator().generate(
            lock: locked, media: [.primary: assets[0]],
            intent: intent("give this a quiet cinematic push"),
            basePlans: try basePlans(for: assets)
        )
        XCTAssertFalse(set.options.isEmpty)
        XCTAssertEqual(set.structureFingerprint, locked.fingerprint)
        for option in set.options {
            XCTAssertEqual(option.structureFingerprint, locked.fingerprint, option.name)
        }
    }

    /// Treatment options must never carry an authorization to restructure.
    func testOptionsNeverAuthorizeStructuralChange() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        XCTAssertTrue(locked.authorizedDeltas.isEmpty)
        let set = try generator().generate(
            lock: locked, media: [.primary: assets[0]],
            intent: intent("quiet"), basePlans: try basePlans(for: assets)
        )
        for option in set.options {
            let card = try XCTUnwrap(try catalog().card(id: option.techniqueCardIDs[0]))
            XCTAssertEqual(card.lockedStructureEffect, .none, option.name)
        }
    }

    // MARK: - Determinism

    func testIdenticalInputsAndSeedProduceIdenticalOptions() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let plans = try basePlans(for: assets)
        let first = try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet cinematic"), basePlans: plans, seed: 42)
        let second = try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet cinematic"), basePlans: plans, seed: 42)
        XCTAssertEqual(first.options.map(\.name), second.options.map(\.name))
        XCTAssertEqual(first.options.map(\.techniqueCardIDs), second.options.map(\.techniqueCardIDs))
    }

    // MARK: - Diversity, not padding

    /// Two options that differ on fewer than two dimensions are the same idea
    /// twice, and showing both costs the user attention for nothing.
    func testDisplayedOptionsDifferOnAtLeastTwoDimensions() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("something atmospheric and bold", intensity: .present),
            basePlans: try basePlans(for: assets)
        )
        guard set.options.count > 1 else { return }
        for i in set.options.indices {
            for j in set.options.indices where j > i {
                XCTAssertTrue(
                    set.options[i].differsMaterially(from: set.options[j]),
                    "\(set.options[i].name) and \(set.options[j].name) are not materially different"
                )
            }
        }
    }

    func testNeverExceedsTheOptionCap() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("anything"), basePlans: try basePlans(for: assets)
        )
        XCTAssertLessThanOrEqual(set.options.count, 3)
    }

    /// Fewer honest options is correct; the shortfall must be explained rather
    /// than left as an unexplained short list.
    func testShortfallIsExplainedRatherThanPadded() throws {
        let assets = [still("a", digest: "a")]
        let restricted = TreatmentOptionGenerator(
            catalog: try catalog(), admittedCapabilities: capabilities, maximumOptions: 3
        )
        let set = restricted.generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("quiet"), basePlans: try basePlans(for: assets)
        )
        if set.options.count < 3 {
            XCTAssertNotNil(set.shortfallExplanation)
            XCTAssertTrue(set.shortfallExplanation!.contains("rather than"), set.shortfallExplanation!)
        }
    }

    /// An empty capability profile means nothing can run, and the generator has
    /// to say so instead of returning a plausible-looking list.
    func testNoCapabilitiesYieldsNoOptionsAndAnExplanation() throws {
        let assets = [still("a", digest: "a")]
        let set = TreatmentOptionGenerator(catalog: try catalog(), admittedCapabilities: [])
            .generate(lock: lock(assets), media: [.primary: assets[0]], intent: intent("quiet"), basePlans: try basePlans(for: assets))
        XCTAssertTrue(set.options.isEmpty)
        XCTAssertNotNil(set.shortfallExplanation)
    }

    // MARK: - Only executable, only safe

    func testEveryDisplayedOptionIsExecutable() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("quiet"), basePlans: try basePlans(for: assets)
        )
        let loaded = try catalog()
        for option in set.options {
            for id in option.techniqueCardIDs {
                let card = try XCTUnwrap(loaded.card(id: id))
                XCTAssertTrue(card.isExecutable(admittedCapabilities: capabilities), "\(id) was offered but cannot run")
            }
        }
    }

    func testPaidOrUploadingTechniquesAreNeverSelectedWithoutApproval() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("anything"), basePlans: try basePlans(for: assets)
        )
        for option in set.options {
            XCTAssertEqual(option.monetary, .free, option.name)
            XCTAssertEqual(option.privacy, .localOnly, option.name)
        }
    }

    /// Reference-only cards are knowledge, not offers. They must never surface
    /// as something the user can pick.
    func testReferenceOnlyKnowledgeIsNeverOffered() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("readable captions with good contrast"), basePlans: try basePlans(for: assets)
        )
        let loaded = try catalog()
        for option in set.options {
            for id in option.techniqueCardIDs {
                XCTAssertEqual(try XCTUnwrap(loaded.card(id: id)).status, .validated, id)
            }
        }
    }

    // MARK: - Anchors adapt rather than impose

    /// A subtle request should yield three subtle options, not one subtle and
    /// two loud ones. The anchors lean *from* the request.
    func testAnchorsAdaptToTheRequestedIntensity() {
        XCTAssertEqual(TreatmentAnchor.quiet.adaptedIntensity(from: .barelyThere), .barelyThere)
        XCTAssertEqual(TreatmentAnchor.expressive.adaptedIntensity(from: .barelyThere), .restrained)
        XCTAssertEqual(TreatmentAnchor.bold.adaptedIntensity(from: .barelyThere), .present)

        // A bold request never gets quieter than it asked for.
        XCTAssertEqual(TreatmentAnchor.quiet.adaptedIntensity(from: .strong), .strong)
        XCTAssertEqual(TreatmentAnchor.bold.adaptedIntensity(from: .strong), .bold)
        XCTAssertEqual(TreatmentAnchor.bold.adaptedIntensity(from: .bold), .bold, "the ladder must clamp rather than wrap")
    }

    // MARK: - Rejections are explained

    func testRejectedCandidatesCarryReadableExplanations() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("quiet"), basePlans: try basePlans(for: assets)
        )
        for entry in set.rejected {
            XCTAssertFalse(entry.explanation.isEmpty)
            XCTAssertTrue(entry.explanation.contains(entry.name), entry.explanation)
        }
    }

    // MARK: - Intent survives

    func testOriginalWordingSurvivesIntoEveryOption() throws {
        let assets = [still("a", digest: "a")]
        let wording = "make it feel like a memory, but keep it restrained"
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent(wording), basePlans: try basePlans(for: assets)
        )
        for option in set.options {
            XCTAssertEqual(option.intent.originalWording, wording, "the user's own words must survive")
        }
    }

    /// The revision case the semantic plan exists for: change the atmosphere
    /// reading without disturbing the motion reading.
    func testSemanticRevisionTouchesOnlyTheIntendedDimension() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: TreatmentIntent(originalWording: "magical and deep", emotional: "magical", motion: "slow depth push", intensity: .strong),
            basePlans: try basePlans(for: assets)
        )
        let original = try XCTUnwrap(set.options.first)
        let revised = original.revising { intent in
            intent.emotional = "less magical"
            intent.intensity = .restrained
        }
        XCTAssertEqual(revised.intent.motion, original.intent.motion, "the depth reading must survive untouched")
        XCTAssertEqual(revised.intent.originalWording, original.intent.originalWording)
        XCTAssertNotEqual(revised.intent.emotional, original.intent.emotional)
        XCTAssertEqual(revised.structureFingerprint, original.structureFingerprint)
    }

    // MARK: - Admission

    func testAdmissionRefusesAnOptionAfterTheStructureDrifts() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let set = try generator().generate(
            lock: locked, media: [.primary: assets[0]],
            intent: intent("quiet"), basePlans: try basePlans(for: assets)
        )
        let option = try XCTUnwrap(set.options.first)
        let admission = TreatmentAdmission(lock: locked, catalog: try catalog(), admittedCapabilities: capabilities)
        XCTAssertNoThrow(try admission.admit(option))

        // The user reorders or retimes after planning: the option is stale.
        let drifted = EditorialStructureLock.establish(orderedMedia: assets, clipDurationFrames: [90])
        let staleAdmission = TreatmentAdmission(lock: drifted, catalog: try catalog(), admittedCapabilities: capabilities)
        XCTAssertThrowsError(try staleAdmission.admit(option)) { error in
            guard case TreatmentAdmissionError.structureDrifted = error else {
                return XCTFail("expected a structure-drift refusal, got \(error)")
            }
        }
    }

    func testAdmissionRefusesWhenACapabilityIsRevoked() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let set = try generator().generate(
            lock: locked, media: [.primary: assets[0]],
            intent: intent("quiet"), basePlans: try basePlans(for: assets)
        )
        let option = try XCTUnwrap(set.options.first)
        let revoked = TreatmentAdmission(lock: locked, catalog: try catalog(), admittedCapabilities: [])
        XCTAssertThrowsError(try revoked.admit(option)) { error in
            guard case TreatmentAdmissionError.cardNotExecutable = error else {
                return XCTFail("expected a card-not-executable refusal, got \(error)")
            }
        }
    }
}
