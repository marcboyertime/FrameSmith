import XCTest
@testable import FCPCommandConsoleCore

final class CapabilityGateTests: XCTestCase {
    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func currentPlan() throws -> EffectPlan {
        let source = SourceIdentity(itemID: "clip-a", canonicalPath: "/tmp/capability-clip-a.mov", sha256: String(repeating: "a", count: 64))
        let selection = SelectionToken(selectionType: .singleClip, clipIDs: ["clip-a"], sourceIdentities: [source], revision: "r1")
        return try DeterministicPlanner(registry: registry()).plan(
            request: "Give this image a slow clockwise rotation while zooming toward the point I select.",
            selection: selection,
            target: Target.confirmed(x: 0.5, y: 0.5)
        )
    }

    func testCurrentV2PlanAllowsOnlyLocalAndInertCapabilitiesWhileManualSemanticsAreUnknown() throws {
        let plan = try currentPlan()
        let gate = CapabilityGate()
        XCTAssertTrue(gate.decision(for: plan, capability: .localOnlyPreview).allowed)
        XCTAssertTrue(gate.decision(for: plan, capability: .inertPayloadNeutralPackage).allowed)
        for effectID in EffectID.allCases {
            var workflowPlan = plan
            workflowPlan.effectID = effectID
            XCTAssertFalse(gate.decision(for: workflowPlan, capability: .fcpxmlPreview).allowed, effectID.rawValue)
            XCTAssertFalse(gate.decision(for: workflowPlan, capability: .fcpxmlExport).allowed, effectID.rawValue)
        }
        XCTAssertNoThrow(try gate.require(plan, capability: .localOnlyPreview))
        XCTAssertThrowsError(try gate.require(plan, capability: .fcpxmlExport)) { error in
            XCTAssertEqual(error as? CapabilityGateError, .missingVerifiedFinalCutSelectionEvidence(.fcpxmlExport))
        }
    }

    func testDissolveOnlyEvidenceDoesNotUnlockOtherWorkflows() throws {
        let gate = CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: [.assetAdmission, .crossDissolveTransition]))
        for capability in [FCPCommandConsoleCapability.fcpxmlPreview, .fcpxmlExport] {
            XCTAssertFalse(gate.decision(for: try plan(for: .naturalDissolve), capability: capability).allowed, capability.rawValue)
            XCTAssertFalse(gate.decision(for: try plan(for: .targetedRotateZoom), capability: capability).allowed, capability.rawValue)
            XCTAssertFalse(gate.decision(for: try plan(for: .livingStill), capability: capability).allowed, capability.rawValue)
            XCTAssertFalse(gate.decision(for: try plan(for: .oldTelevision), capability: capability).allowed, capability.rawValue)
        }
    }

    func testInsufficientPartialEvidenceFailsClosedForItsEffect() throws {
        let gate = CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: [.assetAdmission]))
        let plan = try verifiedFinalCutPlan()
        let evidence = try XCTUnwrap(VerifiedFinalCutSelectionEvidence(verifiedToken: plan.selectionToken))
        XCTAssertFalse(gate.decision(for: plan, capability: .fcpxmlPreview).allowed)
        XCTAssertThrowsError(try gate.require(plan, capability: .fcpxmlPreview, selectionEvidence: evidence)) { error in
            XCTAssertEqual(
                error as? CapabilityGateError,
                .missingManualFCPXMLSemanticsEvidence(
                    capability: .fcpxmlPreview,
                    effectID: .targetedRotateZoom,
                    missing: [.transformKeyframes]
                )
            )
        }
    }

    func testOnlyExactVerifiedFinalCutEvidenceAndSemanticProfileUnlocksEffect() throws {
        let plan = try verifiedFinalCutPlan()
        let evidence = try XCTUnwrap(VerifiedFinalCutSelectionEvidence(verifiedToken: plan.selectionToken))
        let gate = CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: [.assetAdmission, .transformKeyframes]))

        XCTAssertTrue(gate.decision(for: plan, capability: .fcpxmlPreview, selectionEvidence: evidence).allowed)
        XCTAssertNoThrow(try gate.require(plan, capability: .fcpxmlExport, selectionEvidence: evidence))
        XCTAssertFalse(gate.decision(for: plan, capability: .fcpxmlPreview).allowed)

        var originChanged = plan
        originChanged.selectionToken.origin = .unverifiedExternal
        var timelineChanged = plan
        timelineChanged.selectionToken.timelineID = "forged-timeline"
        var clipChanged = plan
        clipChanged.selectionToken.clipIDs = ["forged-clip"]
        var revisionChanged = plan
        revisionChanged.selectionToken.revision = "forged-revision"
        var sourceChanged = plan
        sourceChanged.selectionToken.sourceIdentities[0].sha256 = String(repeating: "b", count: 64)

        for changed in [originChanged, timelineChanged, clipChanged, revisionChanged, sourceChanged] {
            XCTAssertFalse(gate.decision(for: changed, capability: .fcpxmlPreview, selectionEvidence: evidence).allowed)
            XCTAssertThrowsError(try gate.require(changed, capability: .fcpxmlExport, selectionEvidence: evidence))
        }
    }

    func testMissingSerializedOriginDecodesAsUnverifiedButCurrentEncodingIncludesIt() throws {
        let token = try currentPlan().selectionToken
        let encoded = try JSONEncoder().encode(token)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["origin"] as? String, SelectionOrigin.unverifiedExternal.rawValue)
        object.removeValue(forKey: "origin")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try JSONDecoder().decode(SelectionToken.self, from: legacy).origin, .unverifiedExternal)
    }

    func testEachEffectHasExactRequiredSemanticContracts() {
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.requiredContracts(for: .naturalDissolve),
            [.assetAdmission, .crossDissolveTransition]
        )
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.requiredContracts(for: .targetedRotateZoom),
            [.assetAdmission, .transformKeyframes]
        )
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.requiredContracts(for: .livingStill),
            [.assetAdmission, .transformKeyframes, .opacityKeyframes, .nativeColorAdjustment]
        )
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.requiredContracts(for: .oldTelevision),
            [.assetAdmission, .opacityKeyframes, .nativeColorAdjustment, .connectedOverlayLayers]
        )
    }

    /// Contract raw values are the persisted form of manual Final Cut evidence
    /// that took four probe revisions to obtain. Renaming one silently
    /// invalidates that evidence, so the wire values are pinned here.
    ///
    /// `bare_dissolve_transition` is absent deliberately: revision 2 sent
    /// exactly that construct and Final Cut returned it disabled at offset 0
    /// against a synthesized empty-UID effect. It named something unachievable
    /// and could never have been admitted.
    func testSemanticContractWireValuesArePinnedAndTheDisprovenFormIsGone() {
        XCTAssertEqual(
            Set(FCPXMLSemanticContract.allCases.map(\.rawValue)),
            [
                "asset_admission",
                "cross_dissolve_transition",
                "transform_keyframes",
                "opacity_keyframes",
                "native_color_adjustment",
                "connected_overlay_layers"
            ]
        )
        XCTAssertFalse(FCPXMLSemanticContract.allCases.contains { $0.rawValue.contains("bare") })
    }

    /// The probes proved the semantics; they did not admit them. Admission is a
    /// separate, deliberate act, and the default profile stays empty so every
    /// FCPXML pathway fails closed until one happens.
    func testPassingProbeEvidenceDoesNotImplicitlyAdmitAnyContract() {
        XCTAssertTrue(ManualFCPXMLSemanticsEvidence.unknown.admittedContracts.isEmpty)
        XCTAssertTrue(ManualFCPXMLSemanticsEvidence().admittedContracts.isEmpty)
        XCTAssertEqual(
            ManualFCPXMLSemanticsEvidence.unknown.missingContracts(for: .naturalDissolve),
            [.assetAdmission, .crossDissolveTransition]
        )
        for effect in EffectID.allCases {
            XCTAssertEqual(
                ManualFCPXMLSemanticsEvidence.unknown.missingContracts(for: effect),
                ManualFCPXMLSemanticsEvidence.requiredContracts(for: effect),
                "an empty profile must be missing every contract \(effect.rawValue) requires"
            )
        }
    }

    func testLegacySchemaIsQuarantinedAndNeverBecomesCurrentOrCapabilityEligible() throws {
        let legacy = try XCTUnwrap("""
        {"schemaVersion":"1.0","representation":"fcp_native"}
        """.data(using: .utf8))
        let admission = try EffectPlanAdmission.decode(legacy)
        guard case .migrationRequired(let quarantine) = admission else { return XCTFail("Legacy document must be quarantined") }
        XCTAssertEqual(quarantine.legacyRepresentation, "fcp_native")
        XCTAssertEqual(quarantine.suggestedRepresentation, .fcpxmlNative)
        XCTAssertTrue(quarantine.replanningRequired)
        XCTAssertThrowsError(try JSONDecoder().decode(EffectPlan.self, from: legacy))
        XCTAssertThrowsError(try CapabilityGate().require(admission, capability: .localOnlyPreview)) { error in
            XCTAssertEqual(error as? CapabilityGateError, .migrationRequired(quarantine))
        }
    }

    func testUnknownSchemaAndCurrentSchemaWithLegacyRepresentationFailClosed() throws {
        let unknown = try XCTUnwrap("""
        {"schemaVersion":"7.0","representation":"fcpxml_native"}
        """.data(using: .utf8))
        XCTAssertThrowsError(try EffectPlanAdmission.decode(unknown)) { error in
            XCTAssertEqual(error as? EffectPlanAdmissionError, .unsupportedSchemaVersion("7.0"))
        }

        let invalidCurrent = try XCTUnwrap("""
        {"schemaVersion":"2.0","representation":"fcp_native"}
        """.data(using: .utf8))
        XCTAssertThrowsError(try EffectPlanAdmission.decode(invalidCurrent))
    }

    func testBundledRegistryAndSchemaExactlyMatchCurrentSourceResources() throws {
        let sourceRoot = projectRoot()
        let bundledRoot = sourceRoot.appendingPathComponent("Sources/FCPCommandConsolePlannerHelper/Resources")
        let relativePaths = [
            "schemas/effect-plan.schema.json",
            "registry/effects/look.old_television.json",
            "registry/effects/motion.living_still.json",
            "registry/effects/native.targeted_rotate_zoom.json",
            "registry/effects/transition.natural_dissolve.json"
        ]
        for relativePath in relativePaths {
            XCTAssertEqual(
                try Data(contentsOf: sourceRoot.appendingPathComponent(relativePath)),
                try Data(contentsOf: bundledRoot.appendingPathComponent(relativePath)),
                "Bundled resource drifted: \(relativePath)"
            )
        }
    }

    private func plan(for effectID: EffectID) throws -> EffectPlan {
        var plan = try currentPlan()
        plan.effectID = effectID
        return plan
    }

    private func verifiedFinalCutPlan() throws -> EffectPlan {
        var plan = try currentPlan()
        plan.selectionToken.origin = .finalCutTimelineClaim
        return plan
    }
}
