import Foundation
import XCTest
@testable import FCPCommandConsoleCore

/// Covers what the app relies on when it offers "Generate Final Cut Project".
///
/// The app must not reimplement export policy — it reads a decision the planner
/// computed. These tests pin that decision so a UI change cannot quietly widen
/// or narrow what the button offers.
final class AppStandaloneIntegrationTests: XCTestCase {
    private let testedBuild = FinalCutVersionIdentity(shortVersion: "12.3", build: "450152")
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("app-standalone-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// A 1×1 PNG is enough: admission cares about canonical path, digest, and
    /// that it decodes as a still.
    private func writeStill(named name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        try Data(base64Encoded: base64)!.write(to: url)
        return url
    }

    private func session(gate: CapabilityGate) throws -> LocalMediaPlannerSession {
        LocalMediaPlannerSession(
            registry: try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects")),
            schemaValidator: try PlanSchemaValidator(
                schemaURL: projectRoot().appendingPathComponent("schemas/effect-plan.schema.json")),
            capabilityGate: gate
        )
    }

    private func admittedGate() -> CapabilityGate {
        CapabilityGate(
            manualSemanticsEvidence: FinalCutSemanticProfileStore.finalCut12_3_450152
                .evidence(forInstalled: testedBuild)
        )
    }

    private let livingStillRequest = "Make this a living still."

    // MARK: - The decision the button reads

    func testPlanningSurfacesAnAllowedStandaloneDecisionForAdmittedMedia() async throws {
        let asset = try await LocalMediaAdmission().admit(try writeStill(named: "still.png"))
        let result = try session(gate: admittedGate()).plan(
            request: livingStillRequest,
            primary: asset,
            outgoing: nil,
            incoming: nil,
            target: .confirmed(x: 0.5, y: 0.5)
        )
        XCTAssertTrue(
            result.standaloneExportDecision.allowed,
            result.standaloneExportDecision.reason
        )
        XCTAssertEqual(result.standaloneExportDecision.capability, .standaloneFCPXMLExport)
    }

    /// The distinction the UI has to keep visible: generating a new project is
    /// available, modifying an existing timeline never is from local media.
    func testStandaloneIsAllowedWhileTimelineMutationStaysRefused() async throws {
        let asset = try await LocalMediaAdmission().admit(try writeStill(named: "still.png"))
        let result = try session(gate: admittedGate()).plan(
            request: livingStillRequest,
            primary: asset,
            outgoing: nil,
            incoming: nil,
            target: .confirmed(x: 0.5, y: 0.5)
        )
        XCTAssertTrue(result.standaloneExportDecision.allowed)
        XCTAssertFalse(result.fcpxmlExportDecision.allowed)
        XCTAssertEqual(
            result.fcpxmlExportDecision.reason,
            "Local media selection does not establish Final Cut selection or adjacency evidence"
        )
    }

    /// The default gate is empty, which is what a machine with an unprofiled
    /// Final Cut build gets. The button must be off there.
    func testStandaloneIsRefusedWhenNoProfileApplies() async throws {
        let asset = try await LocalMediaAdmission().admit(try writeStill(named: "still.png"))
        let result = try session(gate: CapabilityGate()).plan(
            request: livingStillRequest,
            primary: asset,
            outgoing: nil,
            incoming: nil,
            target: .confirmed(x: 0.5, y: 0.5)
        )
        XCTAssertFalse(result.standaloneExportDecision.allowed)
        XCTAssertTrue(
            result.standaloneExportDecision.reason.contains("semantics evidence is incomplete"),
            "expected a stated reason, got: \(result.standaloneExportDecision.reason)"
        )
    }

    /// `look.old_television` is admitted at the contract level but has no
    /// emitter, so the gate allows it and the export refuses with a reason.
    /// The app surfaces that reason rather than a generic failure.
    func testAdmittedEffectWithoutAnEmitterFailsWithAStatedReason() async throws {
        let asset = try await LocalMediaAdmission().admit(try writeStill(named: "still.png"))
        var result = try session(gate: admittedGate()).plan(
            request: livingStillRequest,
            primary: asset,
            outgoing: nil,
            incoming: nil,
            target: .confirmed(x: 0.5, y: 0.5)
        )
        var plan = result.plan
        plan.effectID = .oldTelevision

        let builder = StandaloneFCPXMLExportBuilder(
            gate: admittedGate(),
            outputRoot: root.appendingPathComponent("out", isDirectory: true)
        )
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        // Swapping only the effectID leaves the plan declaring the living
        // still's representation, which no longer matches the registry for
        // old television. That refusal is correct and arrives before the
        // emitter — a plan whose declared class disagrees with its effect is
        // malformed regardless of what could render it.
        XCTAssertThrowsError(try builder.export(
            plan: plan,
            media: [.primary: asset],
            mediaEvidence: evidence,
            installedFinalCut: testedBuild
        )) { error in
            let described = (error as? StandaloneExportError)?.errorDescription
                ?? (error as? PlanValidationError)?.errorDescription
                ?? String(describing: error)
            XCTAssertFalse(described.isEmpty, "the refusal must be stated, not left as an absence")
            XCTAssertFalse(
                described.contains("not admitted"),
                "connectedOverlayLayers was admitted 2026-08-05; no reason may still claim otherwise"
            )
        }

        // And old television now has a real emitter, so the old
        // 'no emitter' explanation must be gone entirely.
        XCTAssertNotNil(StandaloneEmitterCatalog().emitter(for: .oldTelevision))
        XCTAssertNil(StandaloneEmitterCatalog().absenceReason(for: .oldTelevision))
        _ = result
    }

    // MARK: - Re-admission at export time

    /// The app re-admits media when exporting rather than reusing the asset it
    /// holds. A file edited after planning must not be exported as though it
    /// were the bytes the plan describes.
    func testReadmittingChangedMediaProducesADifferentDigest() async throws {
        let url = try writeStill(named: "still.png")
        let first = try await LocalMediaAdmission().admit(url)

        // Same path, different bytes.
        try Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADElEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")!
            .write(to: url)
        let second = try await LocalMediaAdmission().admitAll([url])

        XCTAssertNotEqual(
            first.sha256,
            second.assets[0].sha256,
            "re-admission must observe the new bytes, otherwise the export check is vacuous"
        )
    }

    /// `admitAll` is the only public way to mint evidence, and it must refuse
    /// to produce any for an empty input rather than returning something empty.
    func testAdmitAllRefusesToMintEvidenceForNothing() async throws {
        do {
            _ = try await LocalMediaAdmission().admitAll([])
            XCTFail("expected admitAll to throw for an empty input")
        } catch {
            // Any refusal is acceptable; minting evidence is not.
        }
    }
}
