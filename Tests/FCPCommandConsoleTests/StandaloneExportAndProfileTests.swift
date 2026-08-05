import XCTest
@testable import FCPCommandConsoleCore

/// Covers the version-scoped contract store and the standalone export route.
///
/// The theme of every test here is that admission must stay *narrow*: scoped to
/// one Final Cut build, to media we actually admitted, and to the specific claim
/// being made. Generosity in any of those directions is the bug.
final class StandaloneExportAndProfileTests: XCTestCase {
    private let testedBuild = FinalCutVersionIdentity(shortVersion: "12.3", build: "450152")

    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static let clipPath = "/tmp/capability-clip-a.mov"
    private static let clipDigest = String(repeating: "a", count: 64)

    private func localMediaPlan() throws -> EffectPlan {
        let source = SourceIdentity(itemID: "clip-a", canonicalPath: Self.clipPath, sha256: Self.clipDigest)
        let selection = SelectionToken(
            selectionType: .singleClip,
            clipIDs: ["clip-a"],
            sourceIdentities: [source],
            revision: "r1"
        )
        var plan = try DeterministicPlanner(registry: registry()).plan(
            request: "Give this image a slow clockwise rotation while zooming toward the point I select.",
            selection: selection,
            target: Target.confirmed(x: 0.5, y: 0.5)
        )
        plan.selectionToken.origin = .localMedia
        return plan
    }

    private func admittedAsset(
        canonicalPath: String = clipPath,
        sha256: String = clipDigest
    ) -> LocalMediaAsset {
        LocalMediaAsset(
            itemID: "clip-a",
            url: URL(fileURLWithPath: canonicalPath),
            kind: .movie,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: 10,
            frameRate: 30,
            hasAudio: false,
            canonicalPath: canonicalPath,
            sha256: sha256
        )
    }

    private func admittedEvidence(
        canonicalPath: String = clipPath,
        sha256: String = clipDigest
    ) throws -> AdmittedLocalMediaEvidence {
        try XCTUnwrap(AdmittedLocalMediaEvidence(
            admittedAssets: [admittedAsset(canonicalPath: canonicalPath, sha256: sha256)]
        ))
    }

    private func admittedGate() -> CapabilityGate {
        CapabilityGate(
            manualSemanticsEvidence: FinalCutSemanticProfileStore.finalCut12_3_450152
                .evidence(forInstalled: testedBuild)
        )
    }

    // MARK: - Profile

    /// Pins the admitted set. Adding a contract here must be a deliberate edit
    /// that fails this test first, not a side effect of another change.
    func testProfileAdmitsExactlyTheFiveContractsWithRecordedEvidence() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        XCTAssertEqual(profile.finalCut, testedBuild)
        XCTAssertEqual(profile.admittedContracts, [
            .assetAdmission,
            .crossDissolveTransition,
            .transformKeyframes,
            .opacityKeyframes,
            .nativeColorAdjustment
        ])
        XCTAssertFalse(
            profile.admittedContracts.contains(.connectedOverlayLayers),
            "No probe has ever exercised a connected layer"
        )
    }

    func testEveryAdmittedContractCitesADocumentADigestAndItsLimitations() {
        for record in FinalCutSemanticProfileStore.finalCut12_3_450152.records {
            XCTAssertTrue(
                record.evidenceDocument.hasPrefix("docs/") && record.evidenceDocument.hasSuffix(".md"),
                "\(record.contract.rawValue) must cite a worksheet"
            )
            XCTAssertEqual(record.returnedArtifactSHA256.count, 64, record.contract.rawValue)
            XCTAssertTrue(
                record.returnedArtifactSHA256.allSatisfy(\.isHexDigit),
                "\(record.contract.rawValue) digest must be hex"
            )
            XCTAssertFalse(record.admittedOn.isEmpty, record.contract.rawValue)
            XCTAssertFalse(
                record.limitations.isEmpty,
                "\(record.contract.rawValue) must state what its pass did not establish"
            )
        }
    }

    /// The worksheets a profile cites have to exist, or the audit trail is a
    /// dead link and the admission is unreviewable.
    func testCitedEvidenceDocumentsExistOnDisk() {
        let root = projectRoot()
        for record in FinalCutSemanticProfileStore.finalCut12_3_450152.records {
            let url = root.appendingPathComponent(record.evidenceDocument)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "Missing evidence document \(record.evidenceDocument) for \(record.contract.rawValue)"
            )
        }
    }

    func testProfileFailsClosedOnAnyVersionDrift() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        let drifted = [
            FinalCutVersionIdentity(shortVersion: "12.4", build: "450152"),
            FinalCutVersionIdentity(shortVersion: "12.3", build: "450153"),
            FinalCutVersionIdentity(shortVersion: "11.1", build: "1")
        ]
        for identity in drifted {
            XCTAssertEqual(
                profile.evidence(forInstalled: identity),
                .unknown,
                "\(identity.description) must revoke every admission"
            )
        }
        XCTAssertEqual(
            profile.evidence(forInstalled: testedBuild).admittedContracts,
            profile.admittedContracts
        )
    }

    func testStoreReturnsUnknownForAnUntestedBuild() {
        XCTAssertNil(FinalCutSemanticProfileStore.profile(for: FinalCutVersionIdentity(shortVersion: "13.0", build: "9")))
        XCTAssertEqual(
            FinalCutSemanticProfileStore.evidence(forInstalled: FinalCutVersionIdentity(shortVersion: "13.0", build: "9")),
            .unknown
        )
    }

    func testOldTelevisionRemainsBlockedByTheMissingOverlayContract() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        XCTAssertEqual(profile.missingContracts(for: .oldTelevision), [.connectedOverlayLayers])
        for admitted in [EffectID.naturalDissolve, .livingStill, .targetedRotateZoom] {
            XCTAssertTrue(
                profile.missingContracts(for: admitted).isEmpty,
                "\(admitted.rawValue) should have every contract admitted"
            )
        }
    }

    // MARK: - Standalone export

    func testStandaloneExportIsBlockedWithoutAdmittedMediaEvidence() throws {
        let plan = try localMediaPlan()
        let gate = admittedGate()
        XCTAssertFalse(gate.decision(for: plan, capability: .standaloneFCPXMLExport).allowed)
        XCTAssertThrowsError(try gate.require(plan, capability: .standaloneFCPXMLExport)) { error in
            XCTAssertEqual(error as? CapabilityGateError, .standaloneExportMediaNotAdmitted)
        }
    }

    func testStandaloneExportSucceedsForAnAdmittedContractWithAdmittedMedia() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        let gate = admittedGate()
        let decision = gate.decision(
            for: plan,
            capability: .standaloneFCPXMLExport,
            mediaEvidence: try admittedEvidence()
        )
        XCTAssertTrue(decision.allowed, decision.reason)
        XCTAssertNoThrow(try gate.require(
            plan,
            capability: .standaloneFCPXMLExport,
            mediaEvidence: try admittedEvidence()
        ))
    }

    func testStandaloneExportStillHonoursEffectScopedContracts() throws {
        var plan = try localMediaPlan()
        plan.effectID = .oldTelevision
        let gate = admittedGate()
        let evidence = try admittedEvidence()
        XCTAssertFalse(gate.decision(for: plan, capability: .standaloneFCPXMLExport, mediaEvidence: evidence).allowed)
        XCTAssertThrowsError(try gate.require(plan, capability: .standaloneFCPXMLExport, mediaEvidence: evidence)) { error in
            XCTAssertEqual(
                error as? CapabilityGateError,
                .missingManualFCPXMLSemanticsEvidence(
                    capability: .standaloneFCPXMLExport,
                    effectID: .oldTelevision,
                    missing: [.connectedOverlayLayers]
                )
            )
        }
    }

    /// An empty profile must block standalone export exactly as it blocks every
    /// other FCPXML route. The new capability is not a bypass.
    func testStandaloneExportIsBlockedWhenNoProfileApplies() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        let gate = CapabilityGate()
        let decision = gate.decision(
            for: plan,
            capability: .standaloneFCPXMLExport,
            mediaEvidence: try admittedEvidence()
        )
        XCTAssertFalse(decision.allowed, "An unknown-semantics gate must refuse standalone export")
    }

    func testUnadmittedMediaIsRefusedOnEitherPathOrDigest() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        let gate = admittedGate()

        let wrongDigest = try admittedEvidence(sha256: String(repeating: "b", count: 64))
        XCTAssertFalse(
            gate.decision(for: plan, capability: .standaloneFCPXMLExport, mediaEvidence: wrongDigest).allowed,
            "A file swapped after admission must not pass"
        )

        let wrongPath = try admittedEvidence(canonicalPath: "/tmp/some-other-clip.mov")
        XCTAssertFalse(
            gate.decision(for: plan, capability: .standaloneFCPXMLExport, mediaEvidence: wrongPath).allowed,
            "An identical file at an unvetted path must not pass"
        )
    }

    func testPlanWithAnUnadmittedExtraSourceIsRefused() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        plan.selectionToken.sourceIdentities.append(
            SourceIdentity(itemID: "clip-b", canonicalPath: "/tmp/never-admitted.mov", sha256: String(repeating: "c", count: 64))
        )
        let gate = admittedGate()
        XCTAssertFalse(
            gate.decision(for: plan, capability: .standaloneFCPXMLExport, mediaEvidence: try admittedEvidence()).allowed,
            "Every source must be admitted, not just the first"
        )
    }

    func testEmptyAdmissionCannotMintEvidence() {
        XCTAssertNil(AdmittedLocalMediaEvidence(admittedAssets: []))
        XCTAssertNil(AdmittedLocalMediaEvidence(admittedAssets: [
            admittedAsset(canonicalPath: "", sha256: Self.clipDigest)
        ]))
        XCTAssertNil(AdmittedLocalMediaEvidence(admittedAssets: [
            admittedAsset(sha256: "")
        ]))
    }

    // MARK: - No privilege leaks between the two routes

    func testStandaloneExportRefusesATimelineSelection() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        plan.selectionToken.origin = .finalCutTimelineClaim
        let gate = admittedGate()
        XCTAssertThrowsError(try gate.require(
            plan,
            capability: .standaloneFCPXMLExport,
            mediaEvidence: try admittedEvidence()
        )) { error in
            XCTAssertEqual(error as? CapabilityGateError, .standaloneExportRejectsTimelineSelection)
        }
    }

    func testUnverifiedExternalOriginCannotUseStandaloneExport() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        plan.selectionToken.origin = .unverifiedExternal
        let gate = admittedGate()
        XCTAssertThrowsError(try gate.require(
            plan,
            capability: .standaloneFCPXMLExport,
            mediaEvidence: try admittedEvidence()
        )) { error in
            XCTAssertEqual(
                error as? CapabilityGateError,
                .standaloneExportRequiresLocalMediaOrigin(.unverifiedExternal)
            )
        }
    }

    /// The inverse leak: admitted local media must never authorize modifying an
    /// existing timeline, no matter how complete the semantics profile is.
    func testAdmittedMediaCannotAuthorizeTimelineMutation() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        let gate = admittedGate()
        let evidence = try admittedEvidence()
        for capability in [FCPCommandConsoleCapability.fcpxmlExport, .fcpxmlPreview] {
            XCTAssertFalse(
                gate.decision(for: plan, capability: capability, mediaEvidence: evidence).allowed,
                capability.rawValue
            )
            XCTAssertThrowsError(try gate.require(plan, capability: capability, mediaEvidence: evidence)) { error in
                XCTAssertEqual(
                    error as? CapabilityGateError,
                    .missingVerifiedFinalCutSelectionEvidence(capability),
                    capability.rawValue
                )
            }
        }
    }

    /// A Final Cut selection is the wrong shape of proof for a claim that names
    /// no timeline, so it must not satisfy standalone export either.
    func testFinalCutSelectionEvidenceCannotAuthorizeStandaloneExport() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        plan.selectionToken.origin = .finalCutTimelineClaim
        let selectionEvidence = try XCTUnwrap(VerifiedFinalCutSelectionEvidence(verifiedToken: plan.selectionToken))
        let gate = admittedGate()
        XCTAssertFalse(
            gate.decision(for: plan, capability: .standaloneFCPXMLExport, selectionEvidence: selectionEvidence).allowed
        )
        XCTAssertThrowsError(try gate.require(
            plan,
            capability: .standaloneFCPXMLExport,
            selectionEvidence: selectionEvidence
        )) { error in
            XCTAssertEqual(error as? CapabilityGateError, .standaloneExportRejectsTimelineSelection)
        }
    }

    func testSchemaGateStillAppliesToStandaloneExport() throws {
        var plan = try localMediaPlan()
        plan.effectID = .naturalDissolve
        plan.schemaVersion = "1.0"
        let gate = admittedGate()
        XCTAssertThrowsError(try gate.require(
            plan,
            capability: .standaloneFCPXMLExport,
            mediaEvidence: try admittedEvidence()
        )) { error in
            XCTAssertEqual(error as? CapabilityGateError, .invalidCurrentPlanSchema("1.0"))
        }
    }

    // MARK: - Installed build

    /// Reads the real application when present. Skips rather than fails on a
    /// machine without Final Cut, but asserts the profile agrees when it is
    /// there — that is the check that catches an update invalidating admission.
    func testInstalledFinalCutMatchesTheProfiledBuild() throws {
        guard let installed = InstalledFinalCutVersionReader().read() else {
            throw XCTSkip("Final Cut Pro is not installed at the default path")
        }
        XCTAssertEqual(
            installed,
            testedBuild,
            "Final Cut is \(installed.description) but the profile was established against \(testedBuild.description); re-run the manual passes before trusting admission"
        )
    }

    func testMissingApplicationReadsAsNoVersion() {
        let reader = InstalledFinalCutVersionReader(
            applicationURL: URL(fileURLWithPath: "/Applications/Definitely Not Installed.app")
        )
        XCTAssertNil(reader.read())
    }
}
