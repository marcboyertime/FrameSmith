import Foundation
import XCTest
@testable import FCPCommandConsoleCore

private final class SpyRenderedEmitter: StandaloneRenderedEffectEmitter, @unchecked Sendable {
    let effectID: EffectID = .livingStill
    private let lock = NSLock()
    private var prepareCount = 0
    var observedPrepareCount: Int {
        lock.lock(); defer { lock.unlock() }
        return prepareCount
    }

    func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels {
        try LivingStillStandaloneEmitter().channels(plan: plan, media: media)
    }

    func prepareRenderedAsset(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        outputRoot: URL
    ) throws -> RenderedEffectAsset {
        lock.lock(); prepareCount += 1; lock.unlock()
        throw StandaloneExportError.admittedArtifactMismatch("spy preparation must not run")
    }

    func emitPreparedDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        preparedAsset: RenderedEffectAsset,
        publishedPreparedURL: URL,
        version: String
    ) throws -> String {
        throw StandaloneExportError.admittedArtifactMismatch("spy emission must not run")
    }

    func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String {
        throw StandaloneExportError.admittedArtifactMismatch("direct rendered emission is forbidden")
    }
}

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
        // Keep the source fixture complete and decodable. Renderer integration
        // is covered separately; this route suite injects a sealed prepared
        // asset so it stays hermetic and never downloads a model in CI.
        let png = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        ))
        try png.write(to: url)
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

    private func renderedConstruction(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> StandaloneExportConstruction {
        let primary = try XCTUnwrap(media[.primary])
        let renderRoot = scratch.appendingPathComponent("renders", isDirectory: true)
        try FileManager.default.createDirectory(at: renderRoot, withIntermediateDirectories: true)
        let movie = renderRoot.appendingPathComponent("prepared-test.mov")
        try Data("sealed prepared movie bytes for export-route tests".utf8).write(to: movie)
        let duration = try XCTUnwrap(plan.parameters["durationSeconds"]?.numberValue)
        let fps = Int(try XCTUnwrap(plan.parameters["fps"]?.numberValue))
        let asset = RenderedEffectAsset(
            url: movie,
            sha256: try ContentHasher.sha256File(movie),
            constructionDigest: try RenderedConstructionIdentity.digest(plan: plan, media: media),
            rendererRecipeDigest: String(repeating: "e", count: 64),
            sourceSHA256: primary.sha256,
            width: 1920,
            height: 1080,
            fps: fps,
            frameCount: Int((duration * Double(fps)).rounded()),
            durationSeconds: duration,
            videoFormat: .proRes422HQ10Bit,
            videoOnly: true,
            provenance: ["renderer": "hermetic-export-route-fixture"]
        )
        return .rendered(asset)
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
            construction: try renderedConstruction(plan: plan, media: [.primary: asset]),
            installedFinalCut: testedBuild
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.fcpxmlURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.provenanceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.instructionsURL.path))
        XCTAssertEqual(package.mediaSHA256["still.png"], asset.sha256)
        let generatedEntries = package.mediaSHA256.filter { $0.key.hasPrefix("Generated/") }
        XCTAssertEqual(generatedEntries.count, 1, "Living Still must publish exactly one rendered treatment movie")
        XCTAssertEqual(package.renderedAssetSHA256, generatedEntries.first?.value)

        let xml = try String(contentsOf: package.fcpxmlURL, encoding: .utf8)
        let generatedName = try XCTUnwrap(generatedEntries.first?.key.split(separator: "/").last.map(String.init))
        XCTAssertTrue(xml.contains(#"<video ref="r3" lane="1" offset="0s" name="\#(generatedName)" start="0s" duration="4s"/>"#))
        XCTAssertTrue(xml.contains("Media/Generated/\(generatedName)"))
        XCTAssertFalse(xml.contains("<adjust-transform"), "v2 motion is rendered into the connected movie")
        XCTAssertFalse(xml.contains("<adjust-blend"), "the admitted v2 layer is opaque, not faded")
        XCTAssertFalse(xml.contains("Color Adjustments"), "v2 must not fall back to the retired native approximation")
    }

    func testRenderedExportWithoutPreparedArtifactNeverInvokesRendererOrCreatesOutput() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))
        let spy = SpyRenderedEmitter()
        let outputRoot = scratch.appendingPathComponent("missing-prepared-output", isDirectory: true)
        let subject = StandaloneFCPXMLExportBuilder(
            gate: admittedGate(),
            outputRoot: outputRoot,
            emitters: [spy],
            registry: try registry()
        )

        XCTAssertThrowsError(try subject.export(
            plan: plan,
            media: [.primary: asset],
            mediaEvidence: evidence,
            construction: .native,
            installedFinalCut: testedBuild
        )) { error in
            guard case .admittedArtifactMismatch(let detail) = error as? StandaloneExportError else {
                return XCTFail("expected missing prepared artifact refusal, got \(error)")
            }
            XCTAssertTrue(detail.contains("export never renders"), detail)
        }
        XCTAssertEqual(spy.observedPrepareCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputRoot.path))
    }

    /// The route must not be reachable when the gate would refuse. An empty
    /// semantics profile is the case that matters: it is the default.
    func testExportIsRefusedWhenNoProfileApplies() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.livingStill, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        XCTAssertThrowsError(try builder(gate: CapabilityGate()).export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: .native, installedFinalCut: testedBuild
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
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: .native, installedFinalCut: testedBuild
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
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: .native, installedFinalCut: testedBuild
        ))
    }

    // MARK: - Gaps are stated, not papered over

    /// Both effects gained production emitters on 2026-08-07, so this no longer
    /// tests a missing emitter — it tests that an effect which cannot run *for
    /// its own reasons* still explains itself.
    ///
    /// A dissolve given one clip cannot be built at all, and neither can one
    /// whose clips lack handle. The refusal has to name the cause rather than
    /// failing blank, because the user's next move differs completely between
    /// "add a second clip" and "shorten the transition".
    func testEffectsThatCannotRunStillExplainThemselves() throws {
        let asset = try makeAsset()
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        // A dissolve with only a primary clip: no incoming media to dissolve to.
        let dissolvePlan = try makePlan(.naturalDissolve, asset: asset)
        XCTAssertThrowsError(try builder().export(
            plan: dissolvePlan, media: [.primary: asset], mediaEvidence: evidence, construction: .native, installedFinalCut: testedBuild
        )) { error in
            let described = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            XCTAssertFalse(described.isEmpty, "a one-clip dissolve must explain itself")
            XCTAssertFalse(
                described.lowercased().contains("no standalone emitter"),
                "the dissolve has an emitter now; the refusal should be about the missing clip, got: \(described)"
            )
        }

        // Every effect now has a registered emitter; a catalog missing one still
        // reports an actionable reason rather than an empty string.
        for effect in EffectID.allCases {
            XCTAssertNotNil(StandaloneEmitterCatalog().emitter(for: effect), "\(effect.rawValue) should have a production emitter")
            XCTAssertFalse(
                StandaloneEmitterCatalog(emitters: []).absenceReason(for: effect)?.isEmpty ?? true,
                "\(effect.rawValue) must state why an empty catalog cannot serve it"
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
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: .native, installedFinalCut: testedBuild
        )) { error in
            XCTAssertEqual(error as? StandaloneExportError, .unconfirmedTarget)
        }
    }

    func testTargetedRotateZoomExportsWithAConfirmedTarget() throws {
        let asset = try makeAsset()
        let plan = try makePlan(.targetedRotateZoom, asset: asset)
        let evidence = try XCTUnwrap(AdmittedLocalMediaEvidence(admittedAssets: [asset]))

        let package = try builder().export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: .native, installedFinalCut: testedBuild
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
            plan: plan, media: [.primary: asset], mediaEvidence: evidence,
            construction: try renderedConstruction(plan: plan, media: [.primary: asset]),
            installedFinalCut: testedBuild
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
        let construction = try renderedConstruction(plan: plan, media: [.primary: asset])
        _ = try subject.export(plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: construction, installedFinalCut: testedBuild)
        XCTAssertThrowsError(try subject.export(
            plan: plan, media: [.primary: asset], mediaEvidence: evidence, construction: construction, installedFinalCut: testedBuild
        )) { error in
            guard case .existingPackage = error as? StandaloneExportError else {
                return XCTFail("expected an overwrite refusal, got \(error)")
            }
        }
    }
}
