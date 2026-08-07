import Foundation
import XCTest
@testable import FCPCommandConsoleCore

/// Covers the route that turns a `standaloneFCPXMLExport` authorization into an
/// actual package.
///
/// The recurring theme is that the route must never be *more* permissive than
/// the gate, and must never quietly substitute a plausible value for one the
/// user did not give.
final class StandaloneExportRouteTests: XCTestCase {
    private let testedBuild = FinalCutVersionIdentity(shortVersion: "12.3", build: "450152")
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("framesmith-standalone-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let scratch { try? FileManager.default.removeItem(at: scratch) }
    }

    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// A real still on disk, so digests and copies are exercised rather than faked.
    private func makeAsset() throws -> LocalMediaAsset {
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let url = scratch.appendingPathComponent("still.png")
        try Data(repeating: 0x42, count: 512).write(to: url)
        return LocalMediaAsset(
            itemID: "still",
            url: url,
            kind: .still,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: nil,
            frameRate: nil,
            hasAudio: false,
            canonicalPath: url.path,
            sha256: try ContentHasher.sha256File(url)
        )
    }

    private func makePlan(_ effectID: EffectID, asset: LocalMediaAsset) throws -> EffectPlan {
        let selection = SelectionToken(
            selectionType: .singleClip,
            clipIDs: ["still"],
            sourceIdentities: [asset.sourceIdentity],
            revision: "r1"
        )
        var plan = try DeterministicPlanner(registry: registry()).plan(
            request: "Give this image a slow clockwise rotation while zooming toward the point I select.",
            selection: selection,
            target: Target.confirmed(x: 0.7, y: 0.35)
        )
        plan.effectID = effectID
        let definition = try registry().definition(for: effectID)
        plan.parameters = Dictionary(uniqueKeysWithValues: definition.parameters.compactMap { parameter in parameter.defaultValue.map { (parameter.name, $0) } })
        plan.representation = definition.representation
        plan.editableProperties = definition.editableProperties
        plan.generatedAssets = definition.generatedAssets
        plan.previewStrategy = definition.preview
        plan.verification = definition.verification
        plan.fallback = definition.fallback
        plan.selectionToken.origin = .localMedia
        return plan
    }

    private func admittedGate() -> CapabilityGate {
        CapabilityGate(manualSemanticsEvidence: FinalCutSemanticProfileStore.finalCut12_3_450152.evidence(forInstalled: testedBuild))
    }

    private func builder(gate: CapabilityGate? = nil) -> StandaloneFCPXMLExportBuilder {
        StandaloneFCPXMLExportBuilder(
            gate: gate ?? admittedGate(),
            outputRoot: scratch.appendingPathComponent("out", isDirectory: true)
        )
    }

    // MARK: - The route honours the gate

    func testExportSucceedsForAnAdmittedEffectWithAdmittedMedia() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        let package = try builder().export(
            plan: plan,
            media: [.primary: asset],
            mediaEvidence: evidence,
            installedFinalCut: testedBuild
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.fcpxmlURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.provenanceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.instructionsURL.path))
        XCTAssertEqual(package.mediaSHA256["still.png"], asset.sha256)

        let xml = try String(contentsOf: package.fcpxmlURL, encoding: .utf8)
        XCTAssertTrue(xml.contains("<adjust-transform"))
        XCTAssertTrue(xml.contains("<adjust-blend"))
        XCTAssertTrue(xml.contains("Color Adjustments"))
    }

    /// The route must not be reachable when the gate would refuse. An empty
    /// semantics profile is the case that matters: it is the default.
    func testExportIsRefusedWhenNoProfileApplies() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        XCTAssertThrowsError(try builder(gate: CapabilityGate()).export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        )) { error in
            guard case .capabilityRefused = error as? StandaloneExportError else {
                return XCTFail("expected a capability refusal, got \(error)")
            }
        }
    }

    func testExportIsRefusedForATimelineSelection() throws {
        let asset = try makeAsset()
        var plan = try makePlan(.livingStill, asset: asset)
        plan.selectionToken.origin = .finalCutTimelineClaim
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        XCTAssertThrowsError(try builder().export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        ))
    }

    func testExportIsRefusedWhenMediaWasNotAdmitted() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        var other = asset
        other = LocalMediaAsset(
            itemID: other.itemID, url: other.url, kind: other.kind, dimensions: other.dimensions,
            durationSeconds: nil, frameRate: nil, hasAudio: false,
            canonicalPath: "/tmp/never-admitted.png", sha256: other.sha256
        )
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [other]))

        XCTAssertThrowsError(try builder().export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        ))
    }

    // MARK: - Gaps are stated, not papered over

    /// `look.old_television` has an admitted-contract gap; `transition.natural_dissolve`
    /// has an emitter gap. Both must fail with a reason a reader can act on.
    func testEffectsWithoutAnEmitterFailWithAStatedReason() throws {
        let asset = try makeAsset()
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        for effect in [EffectID.naturalDissolve, .oldTelevision] {
            let plan = try makePlan(effect, asset: asset)
            XCTAssertThrowsError(try builder().export(
                plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
            ), effect.rawValue) { error in
                let described = (error as? StandaloneExportError)?.errorDescription ?? ""
                XCTAssertFalse(described.isEmpty, "\(effect.rawValue) must explain itself")
            }
            XCTAssertFalse(
                StandaloneFCPXMLExportBuilder.missingEmitterReason(for: effect).isEmpty,
                "\(effect.rawValue) must state why it has no emitter"
            )
        }
    }

    /// Substituting the frame centre for a point the user did not confirm would
    /// produce a plausible result that ignores the request.
    ///
    /// `DeterministicPlanner` already refuses to build such a plan at all, so
    /// this exercises the route's own guard by unconfirming the point
    /// afterwards. That is defence in depth rather than duplication: the
    /// emitter is reachable from any caller holding a plan, not only from the
    /// planner that made one.
    func testUnconfirmedTargetIsRefusedRatherThanDefaultedToCentre() throws {
        let asset = try makeAsset()
        var plan = try makePlan(.targetedRotateZoom, asset: asset)
        plan.normalizedPoint = Target(x: 0.7, y: 0.35, confirmed: false)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        XCTAssertThrowsError(try builder().export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        )) { error in
            XCTAssertEqual(error as? StandaloneExportError, .unconfirmedTarget)
        }
    }

    func testTargetedRotateZoomExportsWithAConfirmedTarget() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.targetedRotateZoom, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        let package = try builder().export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        )
        let xml = try String(contentsOf: package.fcpxmlURL, encoding: .utf8)
        XCTAssertTrue(xml.contains(#"<param name="rotation">"#))
        // A still keeps the one-hour origin even here.
        XCTAssertTrue(xml.contains("3600s"))
    }

    // MARK: - The claim boundary

    /// The package must say what it did, and must not imply it edited anything.
    func testProvenanceAndReadmeStateTheNonMutationClaim() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))
        let package = try builder().export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        )

        let readme = try String(contentsOf: package.instructionsURL, encoding: .utf8)
        XCTAssertTrue(readme.contains("did not modify one"))
        XCTAssertTrue(readme.contains("new project"))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let provenance = try decoder.decode(
            StandaloneFCPXMLExportBuilder.Provenance.self,
            from: Data(contentsOf: package.provenanceURL)
        )
        XCTAssertEqual(provenance.claim, StandaloneFCPXMLExportBuilder.claimStatement)
        XCTAssertEqual(provenance.admittedAgainstFinalCut, testedBuild.description)
        XCTAssertEqual(provenance.effectID, EffectID.livingStill.rawValue)
        XCTAssertEqual(provenance.mediaSHA256["still.png"], asset.sha256)
    }

    // MARK: - Rails

    func testExportRefusesToWriteIntoEvidenceOrLibraryPaths() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let forbidden = [
            home.appendingPathComponent("Movies/FCPCommandConsole/exports/ground-truth"),
            home.appendingPathComponent("Movies/FCPCommandConsole/exports/roundtrip-spikes"),
            home.appendingPathComponent("Movies/FCPCommandConsole/exports/living-still-probes"),
            home.appendingPathComponent("Movies/FCPCommandConsole/exports/native-effect-probes"),
            home.appendingPathComponent("Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle"),
            home.appendingPathComponent("Movies")
        ]
        for root in forbidden {
            let candidate = StandaloneFCPXMLExportBuilder(gate: admittedGate(), outputRoot: root)
            XCTAssertThrowsError(try candidate.validateOutputRoot(root), root.lastPathComponent)
        }
    }

    func testExportRefusesToOverwriteAnExistingPackage() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))
        let subject = builder()
        _ = try subject.export(plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild)
        XCTAssertThrowsError(try subject.export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, installedFinalCut: testedBuild
        )) { error in
            guard case .existingPackage = error as? StandaloneExportError else {
                return XCTFail("expected an overwrite refusal, got \(error)")
            }
        }
    }
}
