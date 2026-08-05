import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class LivingStillProbeBuilderTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("living-still-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeFixtureRoot() throws -> URL {
        let root = try temporaryRoot().appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // A tiny stand-in: the builder hashes and copies bytes, it never decodes them.
        try Data(repeating: 0x89, count: 512).write(to: root.appendingPathComponent("living-still.png"))
        return root
    }

    private func builder(fixtureRoot: URL, exportRoot: URL) -> LivingStillProbeBuilder {
        LivingStillProbeBuilder(fixtureRoot: fixtureRoot, exportRoot: exportRoot)
    }

    // MARK: - Emission

    func testGeneratedDocumentUsesTheCapturedConstruction() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let xml = builder(fixtureRoot: fixtures, exportRoot: exports)
            .makeFCPXML(mediaURL: URL(fileURLWithPath: "/tmp/probe/Media/living-still.png"))

        XCTAssertTrue(xml.contains("<fcpxml version=\"1.14\">"), xml)

        // A still is <video>, not the <asset-clip> path that crashed dissolve revision 1.
        XCTAssertTrue(xml.contains("<video ref=\"r2\""), xml)
        XCTAssertFalse(xml.contains("<asset-clip"), "a still must not be emitted as an asset-clip")

        // Rate-undefined second format, and an asset with no intrinsic duration.
        XCTAssertTrue(xml.contains("name=\"FFVideoFormatRateUndefined\""), xml)
        XCTAssertTrue(xml.contains("<asset id=\"r2\" name=\"living-still\" start=\"0s\" duration=\"0s\""), xml)
        XCTAssertTrue(xml.contains("frameDuration=\"100/3000s\""), xml)

        // The one-hour source origin, on the element and in every keyframe.
        XCTAssertTrue(xml.contains("start=\"3600s\" duration=\"4s\""), xml)
        XCTAssertTrue(xml.contains("<keyframe time=\"3600s\" value=\"1 1\"/>"), xml)

        // The asymmetric transform shapes.
        XCTAssertTrue(xml.contains("<param name=\"X\" key=\"1\">"), xml)
        XCTAssertTrue(xml.contains("<param name=\"Y\" key=\"2\">"), xml)
        XCTAssertTrue(xml.contains("value=\"3.55556\""), xml)
        XCTAssertTrue(xml.contains("value=\"1.08 1.08\""), xml)

        XCTAssertTrue(xml.contains("uid=\"FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0\""), xml)
    }

    /// `%intrinsic-params-video;` then `%video_filter_item;`.
    func testChannelOrderIsTransformThenBlendThenFilter() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let xml = builder(fixtureRoot: fixtures, exportRoot: exports)
            .makeFCPXML(mediaURL: URL(fileURLWithPath: "/tmp/probe/Media/living-still.png"))
        let transform = try XCTUnwrap(xml.range(of: "<adjust-transform>"))
        let blend = try XCTUnwrap(xml.range(of: "<adjust-blend>"))
        let filter = try XCTUnwrap(xml.range(of: "<filter-video"))
        XCTAssertTrue(transform.lowerBound < blend.lowerBound)
        XCTAssertTrue(blend.lowerBound < filter.lowerBound)
    }

    /// The capture's `<library location=…>` wrapper is an export artefact. A
    /// probe naming a library on disk would be directing the import at it.
    func testNoLibraryElementIsEmitted() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let xml = builder(fixtureRoot: fixtures, exportRoot: exports)
            .makeFCPXML(mediaURL: URL(fileURLWithPath: "/tmp/probe/Media/living-still.png"))
        XCTAssertFalse(xml.contains("<library"), xml)
        XCTAssertFalse(xml.contains("fcpbundle"), xml)
        XCTAssertTrue(xml.contains("<event name=\"FCPCommandConsole Living Still Admission Probe\">"), xml)
    }

    // MARK: - Package

    func testBuildProducesAValidatedPackageWithHashVerifiedMedia() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let package = try builder(fixtureRoot: fixtures, exportRoot: exports).build()

        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: package.fcpxmlURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: package.instructionsURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: package.evidenceURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: package.packageRoot.appendingPathComponent("Media/living-still.png").path))
        XCTAssertTrue(fileManager.fileExists(atPath: package.packageRoot.appendingPathComponent("Returned").path))

        let expected = try ContentHasher.sha256File(fixtures.appendingPathComponent("living-still.png"))
        XCTAssertEqual(package.mediaSHA256, expected)
        XCTAssertEqual(package.fcpxmlVersion, "1.14")
    }

    func testEvidenceAdmitsNothing() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let package = try builder(fixtureRoot: fixtures, exportRoot: exports).build()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let evidence = try decoder.decode(
            LivingStillProbeBuilder.Evidence.self,
            from: Data(contentsOf: package.evidenceURL)
        )
        XCTAssertEqual(evidence.semanticAcceptance, .unknown)
        XCTAssertTrue(evidence.manualImportExportPending)
        XCTAssertFalse(evidence.finalCutAutomationPerformed)
        XCTAssertFalse(evidence.paidCallPerformed)
        XCTAssertFalse(evidence.mediaUploadPerformed)

        // Only checks that need no Final Cut may pass. Everything about
        // admission stays unknown until a person returns an export.
        let admissionChecks = evidence.checks.filter { $0.name.contains("admission") || $0.name.contains("round trip") }
        XCTAssertFalse(admissionChecks.isEmpty)
        for check in admissionChecks {
            XCTAssertEqual(check.status, .unknown, "\(check.name) must not be pre-admitted")
        }
    }

    func testRefusesToOverwriteAnExistingPackage() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let operation = UUID()
        _ = try builder(fixtureRoot: fixtures, exportRoot: exports).build(operationID: operation)
        XCTAssertThrowsError(try builder(fixtureRoot: fixtures, exportRoot: exports).build(operationID: operation)) { error in
            XCTAssertEqual(error as? LivingStillProbeError, .existingPackage(exports.appendingPathComponent(operation.uuidString).resolvingSymlinksInPath().standardizedFileURL))
        }
    }

    func testStagingIsRemovedWhenGenerationFails() throws {
        let exports = try temporaryRoot()
        let emptyFixtures = try temporaryRoot()
        XCTAssertThrowsError(try builder(fixtureRoot: emptyFixtures, exportRoot: exports).build())
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: exports.resolvingSymlinksInPath().path)
            .filter { $0.hasPrefix(".living-still-staging-") }
        XCTAssertTrue(leftovers.isEmpty, "staging directory leaked: \(leftovers)")
    }

    // MARK: - Evidence boundary

    /// The captured export is immutable evidence.
    func testRefusesToWriteBeneathTheGroundTruthDirectory() throws {
        let fixtures = try makeFixtureRoot()
        let exports = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/FCPCommandConsole/exports/ground-truth", isDirectory: true)
        XCTAssertThrowsError(try builder(fixtureRoot: fixtures, exportRoot: exports).build()) { error in
            guard case .forbiddenExportRoot = error as? LivingStillProbeError else {
                return XCTFail("expected forbiddenExportRoot, got \(error)")
            }
        }
    }

    func testRefusesLibraryBundlesAndUnapprovedRoots() throws {
        let fixtures = try makeFixtureRoot()
        let cases: [URL] = [
            URL(fileURLWithPath: "/"),
            FileManager.default.homeDirectoryForCurrentUser,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/FCPCommandConsole/Test.fcpbundle/exports"),
            URL(fileURLWithPath: "/Applications/Final Cut Pro.app/exports"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        ]
        for root in cases {
            XCTAssertThrowsError(try builder(fixtureRoot: fixtures, exportRoot: root).build(), "should refuse \(root.path)")
        }
    }

    func testRefusesRelativeAndTraversingPaths() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        XCTAssertThrowsError(try LivingStillProbeBuilder(fixtureRoot: URL(fileURLWithPath: "relative/path"), exportRoot: exports).build())
        XCTAssertThrowsError(try builder(fixtureRoot: fixtures, exportRoot: exports.appendingPathComponent("../escaped")).build())
    }

    func testMissingDTDIsReportedRatherThanSilentlySkipped() throws {
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let absent = LivingStillProbeBuilder(
            fixtureRoot: fixtures,
            exportRoot: exports,
            fcpxmlVersion: "1.14",
            dtdURL: URL(fileURLWithPath: "/nonexistent/FCPXMLv1_14.dtd")
        )
        XCTAssertThrowsError(try absent.build()) { error in
            guard case .invalidDTD = error as? LivingStillProbeError else {
                return XCTFail("expected invalidDTD, got \(error)")
            }
        }
    }

    // MARK: - DTD

    /// Skips rather than fails where Final Cut is not installed, so the suite
    /// stays runnable off this machine. DTD validity is not acceptance.
    func testGeneratedDocumentValidatesAgainstTheInstalled114DTD() throws {
        try XCTSkipUnless(NativeFCPXMLDTD.isInstalled(version: "1.14"), "FCPXML 1.14 DTD not installed")
        let fixtures = try makeFixtureRoot()
        let exports = try temporaryRoot()
        let package = try builder(fixtureRoot: fixtures, exportRoot: exports).build()
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.fcpxmlURL.path))
    }
}
