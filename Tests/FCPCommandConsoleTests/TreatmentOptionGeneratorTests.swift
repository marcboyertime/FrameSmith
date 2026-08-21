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
            let request: String
            switch effect {
            case .livingStill: request = "Make this a living still."
            case .targetedRotateZoom: request = "Use a targeted rotate and zoom."
            case .oldTelevision: request = "Make this old television."
            case .naturalDissolve: request = "Use a natural dissolve."
            }
            var plan = try DeterministicPlanner(registry: registry()).plan(
                request: request, selection: token, target: Target.confirmed(x: 0.6, y: 0.4)
            )
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
        XCTAssertEqual(first.options.map(\.optionID), second.options.map(\.optionID))
        XCTAssertEqual(first.options.map(\.constructionSignature), second.options.map(\.constructionSignature))
        XCTAssertEqual(first.options.map { $0.effectPlan.operationID }, second.options.map { $0.effectPlan.operationID }, "generation must not mint an execution operation ID")
    }

    func testIndependentGenerationDoesNotRetainRandomTemplateOperationIDs() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let first = try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet"), basePlans: try basePlans(for: assets), seed: 9)
        let second = try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet"), basePlans: try basePlans(for: assets), seed: 9)
        XCTAssertEqual(first.options.map { $0.effectPlan.operationID }, second.options.map { $0.effectPlan.operationID })
        XCTAssertEqual(first.options.map(\.optionID), second.options.map(\.optionID))
    }

    func testIndependentEquivalentPlansEncodeAsIdenticalFullTreatmentArtifacts() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let first = try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet cinematic"), basePlans: try basePlans(for: assets), seed: 44)
        let second = try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet cinematic"), basePlans: try basePlans(for: assets), seed: 44)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        XCTAssertEqual(try encoder.encode(first.options), try encoder.encode(second.options))
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

    func testIdenticalConstructionNeverCountsAsDiversity() throws {
        let assets = [still("a", digest: "a")]
        let base = try basePlans(for: assets)[.livingStill]!
        let intent = intent("quiet")
        let one = TreatmentPlan(structureFingerprint: lock(assets).fingerprint, intent: intent, name: "one", idea: "one", changes: [], techniqueCardIDs: ["motion.still.quiet_push.v1"], effectPlan: base, editability: .finalCutNative, previewFidelity: .sharedConstruction, dimensions: [.motionLanguage])
        let two = TreatmentPlan(structureFingerprint: one.structureFingerprint, intent: intent, name: "two", idea: "two", changes: [], techniqueCardIDs: ["motion.opacity.fade.v1"], effectPlan: base, editability: .finalCutNative, previewFidelity: .sharedConstruction, dimensions: [.motionLanguage, .texture])
        XCTAssertFalse(one.differsMaterially(from: two))
    }

    func testNeverExceedsTheOptionCap() throws {
        let assets = [still("a", digest: "a")]
        let set = try generator().generate(
            lock: lock(assets), media: [.primary: assets[0]],
            intent: intent("anything"), basePlans: try basePlans(for: assets)
        )
        XCTAssertLessThanOrEqual(set.options.count, 3)
        let unboundedCaller = TreatmentOptionGenerator(catalog: try catalog(), admittedCapabilities: capabilities, maximumOptions: 120)
            .generate(lock: lock(assets), media: [.primary: assets[0]], intent: intent("anything"), basePlans: try basePlans(for: assets))
        XCTAssertLessThanOrEqual(unboundedCaller.options.count, 3)
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
            XCTAssertEqual(option.effectPlan.originalRequest, wording, "execution and export provenance must retain the director's words, not the seed effect phrase")
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
        let admission = TreatmentAdmission(lock: locked, catalog: try catalog(), admittedCapabilities: capabilities, registry: try registry())
        XCTAssertNoThrow(try admission.admit(option, currentStructure: locked, media: [.primary: assets[0]], impactEvidence: []))

        // The user reorders or retimes after planning: the option is stale.
        let drifted = EditorialStructureLock.establish(orderedMedia: assets, clipDurationFrames: [90])
        let staleAdmission = TreatmentAdmission(lock: drifted, catalog: try catalog(), admittedCapabilities: capabilities, registry: try registry())
        XCTAssertThrowsError(try staleAdmission.admit(option, currentStructure: drifted, media: [.primary: assets[0]], impactEvidence: [])) { error in
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
        let revoked = TreatmentAdmission(lock: locked, catalog: try catalog(), admittedCapabilities: [], registry: try registry())
        XCTAssertThrowsError(try revoked.admit(option, currentStructure: locked, media: [.primary: assets[0]], impactEvidence: [])) { error in
            guard case TreatmentAdmissionError.cardNotExecutable = error else {
                return XCTFail("expected a card-not-executable refusal, got \(error)")
            }
        }
    }

    func testFocalPositiveRotationIsCounterclockwiseAndAdmitsAt120Frames() throws {
        let asset = still("focal", digest: "f")
        let locked = EditorialStructureLock.establish(orderedMedia: [asset], clipDurationFrames: [120], frameRate: 30)
        let focalCard = try XCTUnwrap(catalog().card(id: "motion.focal.target_push.v1"))
        let set = TreatmentOptionGenerator(catalog: .init(cards: [focalCard]), admittedCapabilities: capabilities)
            .generate(lock: locked, media: [.primary: asset], intent: intent("focus here"), basePlans: try basePlans(for: [asset]))
        let option = try XCTUnwrap(set.options.first)
        XCTAssertEqual(option.effectPlan.parameters["rotationEndDegrees"]?.numberValue, 3)
        XCTAssertEqual(option.effectPlan.parameters["direction"], .string("counterclockwise"))
        XCTAssertNoThrow(try TreatmentAdmission(lock: locked, catalog: .init(cards: [focalCard]), admittedCapabilities: capabilities, registry: try registry(), treatmentContractValidator: try TreatmentPlanContractValidator.discover()).admit(option, currentStructure: locked, media: [.primary: asset], impactEvidence: []))
    }

    func testAdmissionRequiresTheCardEffectToMatchThePlanEffect() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        var option = try XCTUnwrap(try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet"), basePlans: try basePlans(for: assets)).options.first)
        option.effectPlan.effectID = .oldTelevision
        option.constructionSignature = TreatmentIdentity.constructionSignature(for: option.effectPlan)
        XCTAssertThrowsError(try TreatmentAdmission(lock: locked, catalog: try catalog(), admittedCapabilities: capabilities, registry: try registry()).admit(option, currentStructure: locked, media: [.primary: assets[0]], impactEvidence: [])) { error in
            guard case TreatmentAdmissionError.effectPlanRejected = error else { return XCTFail("wrong error \(error)") }
        }
    }

    func testAdmissionReturnsImmutableExecutionAndMintsOnlyOnSelection() throws {
        let assets = [still("a", digest: "a")]
        let locked = lock(assets)
        let option = try XCTUnwrap(try generator().generate(lock: locked, media: [.primary: assets[0]], intent: intent("quiet"), basePlans: try basePlans(for: assets)).options.first)
        let admitted = try TreatmentAdmission(lock: locked, catalog: try catalog(), admittedCapabilities: capabilities, registry: try registry()).admit(option, currentStructure: locked, media: [.primary: assets[0]], impactEvidence: [])
        XCTAssertNotEqual(admitted.constructionSignature, option.constructionSignature, "admission signature must bind the exact emitter channels")
        XCTAssertFalse(admitted.channels.canonicalPayload.isEmpty)
        XCTAssertEqual(admitted.structure.fingerprint, locked.fingerprint)
        XCTAssertNotEqual(admitted.selectingForExecution().operationID, option.effectPlan.operationID)
        XCTAssertEqual(admitted.cards.map(\.card.id), option.techniqueCardIDs)
        XCTAssertTrue(admitted.contract.valid)
        XCTAssertEqual(admitted.registryEffectID, option.effectPlan.effectID.rawValue)
        XCTAssertFalse(admitted.registryDigest.isEmpty)
    }

    func testEncodedTreatmentContractRejectsUnknownAndMissingNestedFields() throws {
        let assets = [still("a", digest: "a")]
        let option = try XCTUnwrap(try generator().generate(lock: lock(assets), media: [.primary: assets[0]], intent: intent("quiet"), basePlans: try basePlans(for: assets)).options.first)
        let validator = try TreatmentPlanContractValidator.discover()
        let data = try JSONEncoder().encode(option)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var effect = try XCTUnwrap(object["effectPlan"] as? [String: Any])
        effect["unexpectedNestedField"] = true
        object["effectPlan"] = effect
        XCTAssertThrowsError(try validator.validate(JSONSerialization.data(withJSONObject: object)))
        effect.removeValue(forKey: "selectionToken")
        object["effectPlan"] = effect
        XCTAssertThrowsError(try validator.validate(JSONSerialization.data(withJSONObject: object)))
    }

    func testTypedTargetAndRiskGatesRefuseWithoutCurrentEvidenceOrApproval() throws {
        let assets = [still("a", digest: "a")]
        let focal = try XCTUnwrap(try catalog().card(id: "motion.focal.target_push.v1"))
        XCTAssertEqual(focal.evaluate(in: .init(media: [.primary: assets[0]], target: Target(x: 0.6, y: 0.4, confirmed: false))).executableDecision, .refused)
        let crt = try XCTUnwrap(try catalog().card(id: "look.crt.old_television.v1"))
        XCTAssertEqual(crt.evaluate(in: .init(media: [.primary: assets[0]], target: nil)).executableDecision, .allowedAutomatically)
    }

    func testCRTAutomaticGateUsesTypedMicroFlickerWithoutAnOpacityFade() throws {
        let asset = still("crt", digest: "c")
        let plan = try XCTUnwrap(try basePlans(for: [asset])[.oldTelevision])
        XCTAssertEqual(plan.parameters["durationSeconds"]?.numberValue, 4)
        XCTAssertEqual(plan.parameters["flickerStrength"], .number(0.12))
        XCTAssertEqual(plan.parameters["renderMethod"], .string("ffmpeg-crt-v2"))
        XCTAssertEqual(plan.parameters["preserveOriginal"], .boolean(true))
        XCTAssertEqual(plan.generatedAssets, [
            GeneratedAssetDefinition(
                kind: "crt-treatment-movie",
                format: "prores-422-10bit",
                alpha: false,
                deterministic: true
            )
        ])
        let channels = try OldTelevisionStandaloneEmitter().channels(plan: plan, media: [.primary: asset])
        XCTAssertTrue(channels.opacity.isEmpty)
        XCTAssertNil(channels.saturation)
        XCTAssertNil(channels.overlay)
        XCTAssertEqual(channels.durationSeconds, 4)
        let card = try XCTUnwrap(try catalog().card(id: "look.crt.old_television.v1"))
        XCTAssertTrue(card.riskGates.allSatisfy {
            $0.level == .low && $0.decision == .allowedAutomatically &&
                $0.basis.contains("two percent") && $0.basis.contains("no full-frame opacity event")
        })
        XCTAssertTrue(card.safetyGates.allSatisfy {
            $0.basis.contains("no opacity channel") && $0.basis.contains("two-percent ceiling")
        })
    }

    func testValidatedRenderedCRTIsOfferedAfterVisualAndFinalCutAdmission() throws {
        let asset = still("duration", digest: "d")
        let locked = EditorialStructureLock.establish(orderedMedia: [asset], clipDurationFrames: [120], frameRate: 30)
        let set = try generator().generate(
            lock: locked,
            media: [.primary: asset],
            intent: intent("old television texture", intensity: .bold),
            basePlans: try basePlans(for: [asset])
        )
        let option = try XCTUnwrap(set.options.first { $0.techniqueCardIDs == ["look.crt.old_television.v1"] })
        XCTAssertEqual(option.effectPlan.effectID, .oldTelevision)
        XCTAssertEqual(option.previewFidelity, .sharedConstruction)
    }

    func testRemovingCRTDoesNotPadTheRemainingExecutableOptions() throws {
        let asset = still("safe", digest: "a")
        let cards = try catalog().cards.filter { $0.id != "look.crt.old_television.v1" }
        let set = TreatmentOptionGenerator(catalog: .init(cards: cards), admittedCapabilities: capabilities).generate(
            lock: lock([asset]), media: [.primary: asset], intent: intent("quiet cinematic", intensity: .present), basePlans: try basePlans(for: [asset])
        )
        XCTAssertFalse(set.options.isEmpty)
        XCTAssertLessThanOrEqual(set.options.count, 3)
        if set.options.count < 3 {
            XCTAssertNotNil(set.shortfallExplanation)
            XCTAssertTrue(set.shortfallExplanation?.contains("rather than 3") == true, set.shortfallExplanation ?? "")
        }
        XCTAssertTrue(set.options.allSatisfy { $0.techniqueCardIDs != ["look.crt.old_television.v1"] && (3...6).contains($0.changes.count) })
        for i in set.options.indices {
            for j in set.options.indices where j > i {
                XCTAssertTrue(set.options[i].differsMaterially(from: set.options[j]))
            }
        }
    }

    func testParameterChangesWithoutSemanticDimensionsAreNotDiversity() throws {
        let assets = [still("a", digest: "a")]
        let base = try XCTUnwrap(try basePlans(for: assets)[.livingStill])
        var changed = base
        changed.parameters["pushInScaleEnd"] = .number(1.5)
        let one = TreatmentPlan(structureFingerprint: lock(assets).fingerprint, intent: intent("quiet"), name: "one", idea: "one", changes: [], techniqueCardIDs: ["motion.still.quiet_push.v1"], effectPlan: base, editability: .finalCutNative, previewFidelity: .sharedConstruction, dimensions: [.motionLanguage])
        let two = TreatmentPlan(structureFingerprint: one.structureFingerprint, intent: one.intent, name: "two", idea: "two", changes: [], techniqueCardIDs: ["motion.still.quiet_push.v1"], effectPlan: changed, editability: .finalCutNative, previewFidelity: .sharedConstruction, dimensions: [.motionLanguage])
        XCTAssertFalse(one.differsMaterially(from: two))
    }
}
