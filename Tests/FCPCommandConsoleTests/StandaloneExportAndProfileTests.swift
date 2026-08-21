import CoreAudio
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

    private struct RenderedScopeFixture {
        let root: URL
        let plan: EffectPlan
        let parent: LocalMediaAsset
        let media: [LocalMediaRole: LocalMediaAsset]
        let evidence: AdmittedLocalMediaEvidence
        let renderedURL: URL
    }

    private func renderedScopeFixture() throws -> RenderedScopeFixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "framesmith-rendered-admission-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let parentURL = root.appendingPathComponent("recorded-parent.mov")
        try Data("exact admitted parent fixture".utf8).write(to: parentURL)
        let parent = LocalMediaAsset(
            itemID: "recorded-parent",
            url: parentURL,
            kind: .movie,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: 8,
            frameRate: 30,
            hasAudio: true,
            stillOrientation: nil,
            moviePreferredTransform: .identity,
            videoTrackCount: 1,
            videoScanMode: .progressive,
            videoCadence: .init(
                classification: .constant,
                decodedFrameCount: 240,
                minimumFrameDurationSeconds: 1.0 / 30.0,
                maximumFrameDurationSeconds: 1.0 / 30.0
            ),
            audioStreams: [.observedUntaggedTwoChannel48k],
            canonicalPath: parentURL.path,
            sha256: try ContentHasher.sha256File(parentURL)
        )
        let selection = SelectionToken(
            selectionType: .singleClip,
            origin: .localMedia,
            clipIDs: [parent.itemID],
            sourceIdentities: [parent.sourceIdentity],
            revision: "rendered-scope"
        )
        let plan = try DeterministicPlanner(registry: registry()).plan(
            request: "Make this old television.",
            selection: selection
        )
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [parent]))
        let renderedURL = root.appendingPathComponent("prepared-hq.mov")
        try Data("sealed prepared HQ movie".utf8).write(to: renderedURL)
        return RenderedScopeFixture(
            root: root,
            plan: plan,
            parent: parent,
            media: [.primary: parent],
            evidence: evidence,
            renderedURL: renderedURL
        )
    }

    private func preparedAsset(
        for fixture: RenderedScopeFixture,
        plan: EffectPlan? = nil,
        videoFormat: RenderedMovieVideoFormat = .proRes422HQ10Bit,
        width: Int = 1920,
        height: Int = 1080,
        fps: Int = 30,
        frameCount: Int = 120,
        durationSeconds: Double = 4,
        videoOnly: Bool = true
    ) throws -> RenderedEffectAsset {
        let scopedPlan = plan ?? fixture.plan
        return RenderedEffectAsset(
            url: fixture.renderedURL,
            sha256: try ContentHasher.sha256File(fixture.renderedURL),
            constructionDigest: try RenderedConstructionIdentity.digest(
                plan: scopedPlan,
                media: fixture.media
            ),
            rendererRecipeDigest: String(repeating: "r", count: 64),
            sourceSHA256: fixture.parent.sha256,
            width: width,
            height: height,
            fps: fps,
            frameCount: frameCount,
            durationSeconds: durationSeconds,
            videoFormat: videoFormat,
            videoOnly: videoOnly,
            provenance: ["renderer": OldTelevisionRenderAdapter.rendererVersion]
        )
    }

    private func scopeBuilder(
        _ fixture: RenderedScopeFixture,
        fcpxmlVersion: String = "1.14"
    ) -> StandaloneFCPXMLExportBuilder {
        StandaloneFCPXMLExportBuilder(
            gate: admittedGate(),
            outputRoot: fixture.root.appendingPathComponent("exports", isDirectory: true),
            renderCacheRoot: fixture.root.appendingPathComponent("renders", isDirectory: true),
            fcpxmlVersion: fcpxmlVersion,
            registry: try? registry()
        )
    }

    private func movieParent(
        basedOn base: LocalMediaAsset,
        preferredTransform: LocalMediaAffineTransform = .identity,
        scanMode: LocalMediaVideoScanMode = .progressive,
        cadence: LocalMediaVideoCadence = .init(
            classification: .constant,
            decodedFrameCount: 240,
            minimumFrameDurationSeconds: 1.0 / 30.0,
            maximumFrameDurationSeconds: 1.0 / 30.0
        ),
        audioStreams: [LocalMediaAudioStream] = [.observedUntaggedTwoChannel48k]
    ) -> LocalMediaAsset {
        LocalMediaAsset(
            itemID: base.itemID,
            url: base.url,
            kind: .movie,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: 8,
            frameRate: 30,
            hasAudio: !audioStreams.isEmpty,
            stillOrientation: nil,
            moviePreferredTransform: preferredTransform,
            videoTrackCount: 1,
            videoScanMode: scanMode,
            videoCadence: cadence,
            audioStreams: audioStreams,
            canonicalPath: base.canonicalPath,
            sha256: base.sha256
        )
    }

    private func stillParent(
        basedOn base: LocalMediaAsset,
        orientation: LocalMediaStillOrientation = .up
    ) -> LocalMediaAsset {
        LocalMediaAsset(
            itemID: base.itemID,
            url: base.url,
            kind: .still,
            dimensions: LocalMediaDimensions(width: 1920, height: 1080),
            durationSeconds: nil,
            frameRate: nil,
            hasAudio: false,
            stillOrientation: orientation,
            moviePreferredTransform: nil,
            videoTrackCount: nil,
            videoScanMode: nil,
            videoCadence: nil,
            audioStreams: nil,
            canonicalPath: base.canonicalPath,
            sha256: base.sha256
        )
    }

    // MARK: - Profile

    /// Pins the admitted set. Adding a contract here must be a deliberate edit
    /// that fails this test first, not a side effect of another change.
    ///
    /// It did exactly that on 2026-08-05 for `connectedOverlayLayers`, then on
    /// 2026-08-08 for the separately probed connected rendered-movie contract:
    /// each new observation failed this pin until its evidence record landed.
    func testProfileAdmitsExactlyTheSevenContractsWithRecordedEvidence() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        XCTAssertEqual(profile.finalCut, testedBuild)
        XCTAssertEqual(profile.admittedContracts, Set(FCPXMLSemanticContract.allCases))
        XCTAssertEqual(profile.records.count, 7, "the build-scoped profile must not gain duplicate or implicit records")
    }

    /// The rendered-movie pass is deliberately narrower than the earlier
    /// connected-still contract. Pin both returned contexts and the exclusions
    /// that prevent a successful four-second probe becoming a general movie
    /// compositing claim.
    func testConnectedRenderedMovieAdmissionIsBoundedToItsTwoReturnedContexts() throws {
        let record = try XCTUnwrap(
            FinalCutSemanticProfileStore.finalCut12_3_450152.record(for: .connectedRenderedMovieLayer)
        )
        XCTAssertEqual(record.evidenceDocument, "docs/CONNECTED_RENDERED_MOVIE_ADMISSION_PASS.md")
        XCTAssertEqual(
            record.returnedArtifactSHA256,
            "87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7"
        )
        XCTAssertEqual(record.admittedOn, "2026-08-08")

        let limitations = record.limitations.joined(separator: "\n")
        let requiredBounds = [
            "26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de",
            "movie <asset-clip>",
            "still <video>",
            "video-only Apple ProRes 422 HQ",
            "1920x1080 at 30 fps",
            "lane=1",
            "offset=0s",
            "duration=4s",
            "source-audio metadata",
            "Other codecs",
            "Other lanes",
            "blend modes are unobserved",
            "Editability is NOT established",
            "do not generalize to retiming"
        ]
        for bound in requiredBounds {
            XCTAssertTrue(limitations.contains(bound), "connected rendered-movie admission must retain bound: \(bound)")
        }
    }

    /// Admission and editability are separate claims, so every contract must
    /// state which of the two it has — never leave it unsaid.
    ///
    /// This started life asserting that editability was unproven everywhere,
    /// and failed on 2026-08-05 when the rotate/zoom and old television
    /// editability passes landed. That is the assertion working: the claim
    /// changed, so the pin had to be re-examined against evidence rather than
    /// drifting quietly.
    func testEveryContractStatesItsEditabilityPosition() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        for contract in FCPXMLSemanticContract.allCases {
            let limitations = profile.record(for: contract)?.limitations ?? []
            let confirmed = limitations.contains { $0.lowercased().contains("editability confirmed") }
            let denied = limitations.contains { $0.contains("Editability is NOT established") }
            XCTAssertTrue(
                confirmed || denied,
                "\(contract.rawValue) must record editability as confirmed or explicitly not established"
            )
            XCTAssertFalse(
                confirmed && denied,
                "\(contract.rawValue) cannot claim editability both ways"
            )
        }
    }

    /// Editability that *is* claimed must cite the artifact that established
    /// it, so the claim stays auditable rather than becoming folklore.
    func testConfirmedEditabilityCitesAReturnedDigest() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        for record in profile.records {
            for limitation in record.limitations where limitation.lowercased().contains("editability confirmed") {
                let hexRun = limitation.split(whereSeparator: { !$0.isHexDigit }).contains { $0.count == 64 }
                XCTAssertTrue(
                    hexRun,
                    "\(record.contract.rawValue) claims editability without citing a 64-character returned digest"
                )
            }
        }
    }

    /// The one contract with no editability evidence at all. Admission proved
    /// Final Cut instantiates the Color Adjustments construction; nothing has
    /// ever edited one of its parameters.
    func testColorAdjustmentEditabilityRemainsUnproven() {
        let record = FinalCutSemanticProfileStore.finalCut12_3_450152.record(for: .nativeColorAdjustment)
        XCTAssertFalse(
            record?.limitations.contains { $0.lowercased().contains("editability confirmed") } ?? true,
            "no pass has edited a Color Adjustments parameter"
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

    func testEveryPhase1EffectNowHasItsContractsAdmitted() {
        let profile = FinalCutSemanticProfileStore.finalCut12_3_450152
        for effect in EffectID.allCases {
            XCTAssertTrue(
                profile.missingContracts(for: effect).isEmpty,
                "\(effect.rawValue) still has unadmitted contracts"
            )
        }
    }

    // MARK: - Standalone export

    func testRenderedBuilderRefusesWrongFCPXMLVersionOrFinalCutBuild() throws {
        let fixture = try renderedScopeFixture()
        let prepared = try preparedAsset(for: fixture)

        XCTAssertThrowsError(try scopeBuilder(fixture, fcpxmlVersion: "1.13").export(
            plan: fixture.plan,
            media: fixture.media,
            mediaEvidence: fixture.evidence,
            preparedRenderedAsset: prepared,
            installedFinalCut: testedBuild
        )) { error in
            guard case .capabilityRefused(let reason) = error as? StandaloneExportError else {
                return XCTFail("expected FCPXML scope refusal, got \(error)")
            }
            XCTAssertTrue(reason.contains("1.14"), reason)
        }

        XCTAssertThrowsError(try scopeBuilder(fixture).export(
            plan: fixture.plan,
            media: fixture.media,
            mediaEvidence: fixture.evidence,
            preparedRenderedAsset: prepared,
            installedFinalCut: FinalCutVersionIdentity(shortVersion: "12.3", build: "450153")
        )) { error in
            guard case .capabilityRefused(let reason) = error as? StandaloneExportError else {
                return XCTFail("expected Final Cut build scope refusal, got \(error)")
            }
            XCTAssertTrue(reason.contains("450152"), reason)
        }
    }

    func testRenderedScopeDoesNotChangeTheNativeBuilderPath() throws {
        let fixture = try renderedScopeFixture()
        let selection = SelectionToken(
            selectionType: .singleClip,
            origin: .localMedia,
            clipIDs: [fixture.parent.itemID],
            sourceIdentities: [fixture.parent.sourceIdentity],
            revision: "native-scope-control"
        )
        let nativePlan = try DeterministicPlanner(registry: registry()).plan(
            request: "Give this a slow clockwise rotation while zooming toward the point I select.",
            selection: selection,
            target: .confirmed(x: 0.5, y: 0.5)
        )
        let package = try scopeBuilder(fixture).export(
            plan: nativePlan,
            media: fixture.media,
            mediaEvidence: fixture.evidence,
            installedFinalCut: FinalCutVersionIdentity(shortVersion: "99.0", build: "unprofiled")
        )
        XCTAssertNil(package.renderedAssetSHA256)
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.fcpxmlURL.path))
    }

    func testRenderedBuilderRefusesWrongCodecGeometryFrameRateFrameCountDurationOrAudio() throws {
        let fixture = try renderedScopeFixture()
        let cases: [(String, RenderedEffectAsset)] = try [
            ("codec profile/fourCC", preparedAsset(for: fixture, videoFormat: .proRes422Standard10Bit)),
            ("pixel format", preparedAsset(for: fixture, videoFormat: .unsupported(
                codec: "prores", codecProfile: "HQ", codecFourCC: "apch", pixelFormat: "yuv420p"
            ))),
            ("geometry", preparedAsset(for: fixture, width: 1280)),
            ("frame rate", preparedAsset(for: fixture, fps: 24)),
            ("frame count", preparedAsset(for: fixture, frameCount: 119)),
            ("duration", preparedAsset(for: fixture, durationSeconds: 5)),
            ("audio", preparedAsset(for: fixture, videoOnly: false))
        ]

        for (dimension, prepared) in cases {
            XCTAssertThrowsError(try scopeBuilder(fixture).export(
                plan: fixture.plan,
                media: fixture.media,
                mediaEvidence: fixture.evidence,
                preparedRenderedAsset: prepared,
                installedFinalCut: testedBuild
            ), dimension) { error in
                guard case .admittedArtifactMismatch = error as? StandaloneExportError else {
                    return XCTFail("\(dimension) should fail as an admitted artifact mismatch, got \(error)")
                }
            }
        }
    }

    func testPublicRenderedAdmissionDecisionMatchesExactParentAndPreparedAssetScope() throws {
        let fixture = try renderedScopeFixture()
        let prepared = try preparedAsset(for: fixture)
        let provenance = RenderedEffectAssetProvenance(asset: prepared)
        XCTAssertEqual(provenance.codec, "prores")
        XCTAssertEqual(provenance.codecProfile, "HQ")
        XCTAssertEqual(provenance.codecFourCC, "apch")
        XCTAssertEqual(provenance.pixelFormat, "yuv422p10le")
        XCTAssertTrue(ConnectedRenderedMovieExportAdmission.decision(
            plan: fixture.plan,
            media: fixture.media,
            preparedAsset: prepared,
            installedFinalCut: testedBuild
        ).allowed)

        let invalidMovieParents = [
            LocalMediaAsset(
                itemID: fixture.parent.itemID, url: fixture.parent.url, kind: .movie,
                dimensions: LocalMediaDimensions(width: 1280, height: 720),
                durationSeconds: 8, frameRate: 30, hasAudio: true,
                canonicalPath: fixture.parent.canonicalPath, sha256: fixture.parent.sha256
            ),
            LocalMediaAsset(
                itemID: fixture.parent.itemID, url: fixture.parent.url, kind: .movie,
                dimensions: fixture.parent.dimensions,
                durationSeconds: 7.9, frameRate: 30, hasAudio: true,
                canonicalPath: fixture.parent.canonicalPath, sha256: fixture.parent.sha256
            ),
            LocalMediaAsset(
                itemID: fixture.parent.itemID, url: fixture.parent.url, kind: .movie,
                dimensions: fixture.parent.dimensions,
                durationSeconds: 8, frameRate: 29.97, hasAudio: true,
                canonicalPath: fixture.parent.canonicalPath, sha256: fixture.parent.sha256
            ),
            LocalMediaAsset(
                itemID: fixture.parent.itemID, url: fixture.parent.url, kind: .movie,
                dimensions: fixture.parent.dimensions,
                durationSeconds: 8, frameRate: 30, hasAudio: false,
                canonicalPath: fixture.parent.canonicalPath, sha256: fixture.parent.sha256
            )
        ]
        for parent in invalidMovieParents {
            XCTAssertFalse(ConnectedRenderedMovieExportAdmission.decision(
                plan: fixture.plan,
                media: [.primary: parent],
                preparedAsset: prepared,
                installedFinalCut: testedBuild
            ).allowed, "unobserved parent \(parent) must fail closed")
        }
    }

    func testRenderedContextRefusesRotatedStillTransformInterlaceVFRCadenceAndAudioLayoutDrift() throws {
        let fixture = try renderedScopeFixture()
        let prepared = try preparedAsset(for: fixture)

        let rotatedStill = stillParent(basedOn: fixture.parent, orientation: .right)
        let livingSelection = SelectionToken(
            selectionType: .singleClip,
            origin: .localMedia,
            clipIDs: [rotatedStill.itemID],
            sourceIdentities: [rotatedStill.sourceIdentity],
            revision: "rotated-still"
        )
        let livingPlan = try DeterministicPlanner(registry: registry()).plan(
            request: "Make this a living still.",
            selection: livingSelection
        )
        XCTAssertFalse(ConnectedRenderedMovieExportAdmission.decision(
            plan: livingPlan,
            media: [.primary: rotatedStill],
            preparedAsset: prepared,
            installedFinalCut: testedBuild
        ).allowed, "Living Still must reject a 1920x1080 raw still whose orientation decodes as 1080x1920")

        let rotatedMovie = movieParent(
            basedOn: fixture.parent,
            preferredTransform: .init(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        )
        let interlaced = movieParent(basedOn: fixture.parent, scanMode: .interlaced)
        let variableRate = movieParent(
            basedOn: fixture.parent,
            cadence: .init(
                classification: .variable,
                decodedFrameCount: 240,
                minimumFrameDurationSeconds: 1.0 / 30.0,
                maximumFrameDurationSeconds: 1.0 / 24.0
            )
        )
        let taggedStereo = movieParent(
            basedOn: fixture.parent,
            audioStreams: [.stereo48k]
        )
        let mono = movieParent(
            basedOn: fixture.parent,
            audioStreams: [.init(
                sampleRate: 48_000,
                channelCount: 1,
                channelLayout: .mono,
                channelLayoutTag: UInt32(kAudioChannelLayoutTag_Mono)
            )]
        )
        let wrongRate = movieParent(
            basedOn: fixture.parent,
            audioStreams: [.init(
                sampleRate: 44_100,
                channelCount: 2,
                channelLayout: .unknown,
                channelLayoutTag: nil
            )]
        )
        let wrongRawLayoutTag = movieParent(
            basedOn: fixture.parent,
            audioStreams: [.init(
                sampleRate: 48_000,
                channelCount: 2,
                channelLayout: .unknown,
                channelLayoutTag: 0xFFFF_FFFE
            )]
        )

        for (dimension, parent) in [
            ("preferred transform", rotatedMovie),
            ("interlaced scan", interlaced),
            ("variable cadence", variableRate),
            ("tagged stereo instead of the observed nil tag", taggedStereo),
            ("mono layout", mono),
            ("audio sample rate", wrongRate),
            ("raw audio layout tag", wrongRawLayoutTag)
        ] {
            XCTAssertFalse(ConnectedRenderedMovieExportAdmission.decision(
                plan: fixture.plan,
                media: [.primary: parent],
                preparedAsset: prepared,
                installedFinalCut: testedBuild
            ).allowed, "unobserved \(dimension) must fail closed")
        }

        XCTAssertNotEqual(
            try RenderedConstructionIdentity.digest(plan: fixture.plan, media: fixture.media),
            try RenderedConstructionIdentity.digest(
                plan: fixture.plan,
                media: [.primary: interlaced]
            ),
            "render identity must bind the media context as well as path and hash"
        )
    }

    func testOpaqueEvidenceRejectsForgedTypedContextAtTheBuilderBoundary() throws {
        let fixture = try renderedScopeFixture()
        let prepared = try preparedAsset(for: fixture)

        // The evidence was minted for an interlaced observation. A public
        // constructor can reproduce its item/path/hash while claiming the exact
        // progressive context, but that claim was never admitted.
        let actuallyAdmitted = movieParent(
            basedOn: fixture.parent,
            scanMode: .interlaced
        )
        let evidence = try XCTUnwrap(
            AdmittedLocalMediaEvidence(admittedAssets: [actuallyAdmitted])
        )
        let forgedExactContext = fixture.parent

        XCTAssertTrue(evidence.covers(media: [.primary: actuallyAdmitted]))
        XCTAssertFalse(evidence.covers(media: [.primary: forgedExactContext]))
        XCTAssertNil(
            AdmittedLocalMediaEvidence(
                admittedAssets: [actuallyAdmitted, forgedExactContext]
            ),
            "one opaque token must not bind conflicting contexts to the same source identity"
        )

        XCTAssertThrowsError(try scopeBuilder(fixture).export(
            plan: fixture.plan,
            media: [.primary: forgedExactContext],
            mediaEvidence: evidence,
            preparedRenderedAsset: prepared,
            installedFinalCut: testedBuild
        )) { error in
            guard case .capabilityRefused(let reason) = error as? StandaloneExportError else {
                return XCTFail("expected exact-context evidence refusal, got \(error)")
            }
            XCTAssertTrue(reason.contains("exact typed context"), reason)
        }
    }

    func testRenderedContextRefusesUnobservedPlanTimingResolutionOpacityAndParentMultiplicity() throws {
        let fixture = try renderedScopeFixture()
        var wrongDuration = fixture.plan
        wrongDuration.parameters["durationSeconds"] = .number(5)
        var wrongFrameRate = fixture.plan
        wrongFrameRate.parameters["fps"] = .integer(24)
        var wrongResolution = fixture.plan
        wrongResolution.parameters["outputLongEdge"] = .integer(1280)
        var wrongPreservation = fixture.plan
        wrongPreservation.parameters["preserveOriginal"] = .boolean(false)
        var alphaCapable = fixture.plan
        alphaCapable.generatedAssets[0].alpha = true

        for (dimension, plan) in [
            ("duration", wrongDuration),
            ("frame rate", wrongFrameRate),
            ("resolution", wrongResolution),
            ("preservation", wrongPreservation),
            ("alpha", alphaCapable)
        ] {
            XCTAssertThrowsError(try ConnectedRenderedMovieAdmissionScope.validateContext(
                plan: plan,
                media: fixture.media,
                installedFinalCut: testedBuild,
                fcpxmlVersion: "1.14"
            ), dimension)
        }

        XCTAssertThrowsError(try ConnectedRenderedMovieAdmissionScope.validateContext(
            plan: fixture.plan,
            media: [.primary: fixture.parent, .incoming: fixture.parent],
            installedFinalCut: testedBuild,
            fcpxmlVersion: "1.14"
        ), "only the single recorded parent is admitted")
    }

    func testOldTelevisionAcceptsBothRecordedParentContextsButLivingStillRemainsStillOnly() throws {
        let fixture = try renderedScopeFixture()
        let prepared = try preparedAsset(for: fixture)
        let still = stillParent(basedOn: fixture.parent)
        var stillPlan = fixture.plan
        stillPlan.selectionToken.sourceIdentities = [still.sourceIdentity]
        let stillMedia: [LocalMediaRole: LocalMediaAsset] = [.primary: still]
        let stillPrepared = RenderedEffectAsset(
            url: fixture.renderedURL,
            sha256: try ContentHasher.sha256File(fixture.renderedURL),
            constructionDigest: try RenderedConstructionIdentity.digest(plan: stillPlan, media: stillMedia),
            rendererRecipeDigest: String(repeating: "r", count: 64),
            sourceSHA256: still.sha256,
            width: 1920,
            height: 1080,
            fps: 30,
            frameCount: 120,
            durationSeconds: 4,
            videoFormat: .proRes422HQ10Bit,
            videoOnly: true
        )
        XCTAssertTrue(ConnectedRenderedMovieExportAdmission.decision(
            plan: stillPlan,
            media: stillMedia,
            preparedAsset: stillPrepared,
            installedFinalCut: testedBuild
        ).allowed)

        var livingPlan = stillPlan
        livingPlan.effectID = .livingStill
        let livingDefinition = try registry().definition(for: .livingStill)
        livingPlan.parameters = Dictionary(uniqueKeysWithValues: livingDefinition.parameters.compactMap {
            parameter in parameter.defaultValue.map { (parameter.name, $0) }
        })
        livingPlan.representation = livingDefinition.representation
        livingPlan.editableProperties = livingDefinition.editableProperties
        livingPlan.generatedAssets = livingDefinition.generatedAssets
        livingPlan.previewStrategy = livingDefinition.preview
        livingPlan.verification = livingDefinition.verification
        livingPlan.fallback = livingDefinition.fallback
        let livingPrepared = RenderedEffectAsset(
            url: fixture.renderedURL,
            sha256: try ContentHasher.sha256File(fixture.renderedURL),
            constructionDigest: try RenderedConstructionIdentity.digest(plan: livingPlan, media: stillMedia),
            rendererRecipeDigest: String(repeating: "r", count: 64),
            sourceSHA256: still.sha256,
            width: 1920,
            height: 1080,
            fps: 30,
            frameCount: 120,
            durationSeconds: 4,
            videoFormat: .proRes422HQ10Bit,
            videoOnly: true
        )
        XCTAssertTrue(ConnectedRenderedMovieExportAdmission.decision(
            plan: livingPlan,
            media: stillMedia,
            preparedAsset: livingPrepared,
            installedFinalCut: testedBuild
        ).allowed)
        XCTAssertFalse(ConnectedRenderedMovieExportAdmission.decision(
            plan: livingPlan,
            media: fixture.media,
            preparedAsset: prepared,
            installedFinalCut: testedBuild
        ).allowed, "Living Still must not inherit Old Television's admitted movie parent")
    }

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

    /// Contract scoping must still bite when a contract is genuinely absent.
    /// With the 12.3 profile now complete, the case that exercises this is a
    /// profile missing one contract rather than an effect missing one.
    func testStandaloneExportStillHonoursEffectScopedContracts() throws {
        var plan = try localMediaPlan()
        plan.effectID = .oldTelevision
        let partial = CapabilityGate(manualSemanticsEvidence: ManualFCPXMLSemanticsEvidence(
            admittedContracts: Set(FCPXMLSemanticContract.allCases).subtracting([.connectedRenderedMovieLayer])
        ))
        let evidence = try admittedEvidence()
        XCTAssertFalse(partial.decision(for: plan, capability: .standaloneFCPXMLExport, mediaEvidence: evidence).allowed)
        XCTAssertThrowsError(try partial.require(plan, capability: .standaloneFCPXMLExport, mediaEvidence: evidence)) { error in
            XCTAssertEqual(
                error as? CapabilityGateError,
                .missingManualFCPXMLSemanticsEvidence(
                    capability: .standaloneFCPXMLExport,
                    effectID: .oldTelevision,
                    missing: [.connectedRenderedMovieLayer]
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
