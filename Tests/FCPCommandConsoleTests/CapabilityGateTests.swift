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
            XCTAssertEqual(error as? CapabilityGateError, .manualFCPXMLSemanticsUnknown(.fcpxmlExport))
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
}
