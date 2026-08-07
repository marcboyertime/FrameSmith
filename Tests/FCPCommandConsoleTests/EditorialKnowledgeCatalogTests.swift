import XCTest
@testable import FCPCommandConsoleCore

/// The catalog's job is to never lie about what FrameSmith can run.
///
/// These tests are mostly about refusal: a card cannot promote itself by
/// asserting a status, cannot cite a source that does not exist, and cannot be
/// offered when the Final Cut build has not admitted what it needs.
final class EditorialKnowledgeCatalogTests: XCTestCase {
    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private var cardsDirectory: URL { projectRoot().appendingPathComponent("registry/editorial-techniques") }
    private var sourcesCSV: URL { projectRoot().appendingPathComponent("docs/editorial-intelligence/sources.csv") }

    /// Everything currently admitted for Final Cut 12.3 (450152).
    private var admittedCapabilities: Set<String> {
        Set(FinalCutSemanticProfileStore.finalCut12_3_450152.admittedContracts.map(\.rawValue))
    }

    private func catalog() throws -> EditorialKnowledgeCatalog {
        try EditorialKnowledgeCatalog.load(
            from: cardsDirectory,
            knownSourceIDs: EditorialKnowledgeCatalog.sourceIDs(fromCSV: sourcesCSV)
        )
    }

    // MARK: - Loading

    func testEveryBundledCardLoadsAndValidates() throws {
        let loaded = try catalog()
        XCTAssertFalse(loaded.cards.isEmpty)
        XCTAssertEqual(Set(loaded.cards.map(\.id)).count, loaded.cards.count, "ids must be unique")
    }

    func testLoadIsDeterministic() throws {
        XCTAssertEqual(try catalog().cards.map(\.id), try catalog().cards.map(\.id))
    }

    /// The source catalog is a retrieval map. Nothing may reach the network at
    /// runtime, so loading must work purely from bundled files.
    func testLoadingRequiresNoNetwork() throws {
        let loaded = try EditorialKnowledgeCatalog.load(from: cardsDirectory)
        XCTAssertFalse(loaded.cards.isEmpty)
    }

    func testProvenanceCitesRealSources() throws {
        let known = EditorialKnowledgeCatalog.sourceIDs(fromCSV: sourcesCSV)
        XCTAssertGreaterThan(known.count, 100, "the 153-source catalog should parse")
        for card in try catalog().cards {
            XCTAssertFalse(card.provenance.isEmpty, "\(card.id) has no provenance")
            for entry in card.provenance {
                let isRepositoryEvidence = entry.sourceId.contains("/")
                XCTAssertTrue(
                    isRepositoryEvidence || known.contains(entry.sourceId),
                    "\(card.id) cites unknown source \(entry.sourceId)"
                )
                XCTAssertFalse(entry.claim.isEmpty, "\(card.id) cites \(entry.sourceId) without a specific claim")
            }
        }
    }

    /// A card that says "validated" while admitting it was never implemented is
    /// exactly the overclaim this project exists to prevent.
    func testValidatedCardsMustBeImplementedAndVisuallyVerified() throws {
        for card in try catalog().cards where card.status == .validated {
            XCTAssertTrue(card.validation.implemented, "\(card.id) claims validated without implementation")
            XCTAssertTrue(card.validation.visuallyVerified, "\(card.id) claims validated without visual review")
            XCTAssertFalse(card.validation.verifiedOn?.isEmpty ?? true, "\(card.id) must name the media it was reviewed on")
        }
    }

    func testAValidatedClaimWithoutImplementationIsRejectedAtLoad() throws {
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let liar = """
        {"id":"motion.fake.claim.v1","version":1,"name":"Fake","domain":"motion","status":"validated",
         "summary":"s","creativeJobs":["j"],"intentTags":["t"],"mediaPrerequisites":[],
         "lockedStructureEffect":"none",
         "construction":{"preferredBackends":["native_fcpxml"],"requiredCapabilities":[],"previewFidelity":"shared_construction"},
         "parameters":[],"qualityChecks":["q"],"failureModes":["f"],"editability":["final_cut_native"],
         "provenance":[{"sourceId":"APPLE-FCP-008","claim":"c"}],
         "validation":{"implemented":false,"visuallyVerified":false}}
        """
        try Data(liar.utf8).write(to: scratch.appendingPathComponent("liar.json"))
        XCTAssertThrowsError(try EditorialKnowledgeCatalog.load(from: scratch)) { error in
            guard case EditorialKnowledgeCatalogError.executableClaimWithoutImplementation = error else {
                return XCTFail("expected an executable-claim rejection, got \(error)")
            }
        }
    }

    func testDuplicateIDsAreRejected() throws {
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let source = cardsDirectory.appendingPathComponent("motion.opacity.fade.v1.json")
        try FileManager.default.copyItem(at: source, to: scratch.appendingPathComponent("a.json"))
        try FileManager.default.copyItem(at: source, to: scratch.appendingPathComponent("b.json"))
        XCTAssertThrowsError(try EditorialKnowledgeCatalog.load(from: scratch)) { error in
            guard case EditorialKnowledgeCatalogError.duplicateID = error else {
                return XCTFail("expected a duplicate-id rejection, got \(error)")
            }
        }
    }

    func testInventedProvenanceIsRejected() throws {
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let fabricated = """
        {"id":"motion.fake.source.v1","version":1,"name":"Fake","domain":"motion","status":"reference_only",
         "summary":"s","creativeJobs":["j"],"intentTags":["t"],"mediaPrerequisites":[],
         "lockedStructureEffect":"none",
         "construction":{"preferredBackends":["none"],"requiredCapabilities":[],"previewFidelity":"none"},
         "parameters":[],"qualityChecks":["q"],"failureModes":["f"],"editability":["none"],
         "provenance":[{"sourceId":"TOTALLY-MADE-UP-042","claim":"c"}],
         "validation":{"implemented":false,"visuallyVerified":false}}
        """
        try Data(fabricated.utf8).write(to: scratch.appendingPathComponent("fake.json"))
        XCTAssertThrowsError(try EditorialKnowledgeCatalog.load(from: scratch, knownSourceIDs: ["APPLE-FCP-008"])) { error in
            guard case EditorialKnowledgeCatalogError.unknownSource = error else {
                return XCTFail("expected an unknown-source rejection, got \(error)")
            }
        }
    }

    // MARK: - Executability

    func testReferenceOnlyAndUnsupportedCardsCanNeverBecomeExecutable() throws {
        // Even with every capability in the world admitted.
        let everything = Set(FCPXMLSemanticContract.allCases.map(\.rawValue) + ["audio_analysis", "typography", "flash_analysis", "compositing", "focal_analysis", "audio_processing"])
        for card in try catalog().cards where card.status != .validated {
            XCTAssertFalse(
                card.isExecutable(admittedCapabilities: everything),
                "\(card.id) is \(card.status.rawValue) but reported executable"
            )
            XCTAssertNotNil(card.unavailabilityReason(admittedCapabilities: everything))
        }
    }

    func testValidatedCardsAreExecutableUnderTheCurrentProfile() throws {
        let executable = try catalog().cards.filter { $0.isExecutable(admittedCapabilities: admittedCapabilities) }
        XCTAssertFalse(executable.isEmpty, "the current Final Cut profile should support at least one card")
        for card in executable {
            XCTAssertEqual(card.status, .validated)
            XCTAssertEqual(card.lockedStructureEffect, .none)
        }
    }

    /// The capability gate is re-checked at retrieval, so a Final Cut update
    /// that revokes a contract removes options rather than offering broken ones.
    func testRevokedCapabilitiesSilentlyRemoveOptions() throws {
        let loaded = try catalog()
        let withProfile = loaded.retrieve(.init(admittedCapabilities: admittedCapabilities, limit: 20))
        let withNothing = loaded.retrieve(.init(admittedCapabilities: [], limit: 20))
        XCTAssertFalse(withProfile.isEmpty)
        XCTAssertTrue(withNothing.isEmpty, "no card should be executable with an empty semantics profile")
    }

    /// A treatment that would touch the user's edit is never offered, even if
    /// everything else about it passes.
    func testStructureTouchingCardsAreNeverOffered() throws {
        for card in try catalog().cards {
            if card.lockedStructureEffect != .none {
                XCTAssertFalse(card.isExecutable(admittedCapabilities: admittedCapabilities))
            }
        }
    }

    // MARK: - Retrieval

    func testRetrievalIsBoundedAndDeterministic() throws {
        let loaded = try catalog()
        let query = EditorialKnowledgeCatalog.Query(
            domains: [.motion],
            intentTags: ["quiet"],
            admittedCapabilities: admittedCapabilities,
            limit: 2
        )
        let first = loaded.retrieve(query)
        XCTAssertLessThanOrEqual(first.count, 2, "the planner must not ingest the whole atlas")
        XCTAssertEqual(first.map(\.id), loaded.retrieve(query).map(\.id))
    }

    func testRetrievalRespectsDomainAndIntent() throws {
        let loaded = try catalog()
        let motion = loaded.retrieve(.init(domains: [.motion], admittedCapabilities: admittedCapabilities, limit: 20))
        XCTAssertTrue(motion.allSatisfy { $0.domain == .motion })

        let quiet = loaded.retrieve(.init(intentTags: ["quiet"], admittedCapabilities: admittedCapabilities, limit: 20))
        XCTAssertTrue(quiet.allSatisfy { $0.intentTags.contains("quiet") })
        XCTAssertFalse(quiet.isEmpty)
    }

    /// The UI needs to explain a short option list rather than pad it.
    func testUnavailableCardsCarryAnActionableReason() throws {
        let unavailable = try catalog().unavailable(for: .init(admittedCapabilities: admittedCapabilities))
        XCTAssertFalse(unavailable.isEmpty)
        for (card, reason) in unavailable {
            XCTAssertFalse(reason.isEmpty)
            XCTAssertTrue(reason.contains(card.name), "the reason should name the technique: \(reason)")
        }
    }

    /// Both travelled the full path on 2026-08-07: `unsupported` → emitter
    /// built → `experimental` → generated package imported and returned intact
    /// → `validated`.
    ///
    /// The intermediate stop mattered. An emitter existing is not evidence that
    /// Final Cut accepts what it emits — every silently-wrong construction this
    /// project has caught was DTD-valid — so neither was offerable until a
    /// document *it produced* came back from a real import.
    func testDissolveAndOldTelevisionAreValidatedByRoundTripEvidence() throws {
        let loaded = try catalog()
        for id in ["transition.dissolve.short_natural.v1", "look.crt.old_television.v1"] {
            let card = try XCTUnwrap(loaded.card(id: id))
            XCTAssertEqual(card.status, .validated, id)
            XCTAssertTrue(card.validation.implemented, id)
            XCTAssertTrue(card.validation.visuallyVerified, id)
            XCTAssertFalse(card.validation.finalCutEvidence?.isEmpty ?? true, "\(id) must cite returned artifacts")
            XCTAssertTrue(
                card.isExecutable(admittedCapabilities: admittedCapabilities),
                "\(id) should now be offerable under the current profile"
            )
        }
    }

    /// The old television emitter was admitted for its **base treatment only**.
    /// Its connected overlay was not exercised by that pass, and the card has
    /// to keep saying so rather than letting the promotion imply full coverage.
    func testOldTelevisionRecordsThatItsOverlayWasNotExercised() throws {
        let card = try XCTUnwrap(catalog().card(id: "look.crt.old_television.v1"))
        let notes = card.validation.notes ?? ""
        XCTAssertTrue(notes.contains("overlay was NOT exercised"), "the untested overlay must stay visible: \(notes)")
    }

    /// Colour is admitted as a construction but has no measured mapping, so the
    /// card must not present itself as a steerable control.
    func testColourCardIsHonestAboutItsMissingMapping() throws {
        let card = try XCTUnwrap(catalog().card(id: "look.color.restrained_native.v1"))
        XCTAssertEqual(card.status, .referenceOnly)
        XCTAssertEqual(card.construction.previewFidelity, .indicative)
        XCTAssertFalse(card.conflicts?.isEmpty ?? true, "the admitted-construction / unmeasured-mapping conflict should be preserved")
        XCTAssertTrue(card.parameters.allSatisfy { $0.liveness != .live })
    }
}
