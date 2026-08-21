import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class ConnectedRenderedMovieProbeBuilderTests: XCTestCase {
    private let fileManager = FileManager.default

    private struct Fixture {
        let root: URL
        let fixtureRoot: URL
        let exportRoot: URL
        let prepared: ConnectedRenderedMoviePreparedMedia
    }

    private func temporaryFixture(
        parentKind: ConnectedRenderedMovieProbeParentKind,
        validSource: Bool = false
    ) throws -> Fixture {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("connected-rendered-movie-tests-\(UUID().uuidString)", isDirectory: true)
        let fixtureRoot = root.appendingPathComponent("fixtures", isDirectory: true)
        let exportRoot = root.appendingPathComponent("exports", isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        let rootPath = root.path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: rootPath) }

        let sourceURL = fixtureRoot.appendingPathComponent(parentKind.sourceFilename)
        if validSource {
            try makeValidSource(at: sourceURL, parentKind: parentKind)
        } else {
            try Data("unchanged-source-\(parentKind.rawValue)".utf8).write(to: sourceURL)
        }
        let movieURL = root.appendingPathComponent("connected-rendered.mov")
        try Data("verified-video-only-prores-fixture".utf8).write(to: movieURL)
        let prepared = ConnectedRenderedMoviePreparedMedia(
            url: movieURL,
            sha256: try ContentHasher.sha256File(movieURL),
            recipeDigest: String(repeating: "a", count: 64)
        )
        return Fixture(
            root: root,
            fixtureRoot: fixtureRoot,
            exportRoot: exportRoot,
            prepared: prepared
        )
    }

    private func makeValidSource(
        at url: URL,
        parentKind: ConnectedRenderedMovieProbeParentKind
    ) throws {
        let ffmpeg = OldTelevisionRenderAdapter.ffmpegURL
        try XCTSkipUnless(fileManager.isExecutableFile(atPath: ffmpeg.path), "ffmpeg is unavailable")
        let arguments: [String]
        switch parentKind {
        case .still:
            arguments = [
                "-v", "error", "-f", "lavfi",
                "-i", "color=c=gray:s=1920x1080:r=30",
                "-frames:v", "1", "-c:v", "png", "-threads", "1", "-y", url.path
            ]
        case .movie:
            arguments = [
                "-v", "error",
                "-f", "lavfi", "-i", "color=c=gray:s=1920x1080:r=30:d=8",
                "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
                "-t", "8", "-map", "0:v:0", "-map", "1:a:0",
                "-c:v", "mpeg4", "-q:v", "31", "-pix_fmt", "yuv420p",
                "-c:a", "pcm_s16le", "-shortest", "-y", url.path
            ]
        }
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments
        let standardError = Pipe()
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "ffmpeg exited \(process.terminationStatus)"
            throw NSError(
                domain: "ConnectedRenderedMovieProbeBuilderTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: detail]
            )
        }
    }

    private func builder(
        parentKind: ConnectedRenderedMovieProbeParentKind,
        fixture: Fixture
    ) -> ConnectedRenderedMovieProbeBuilder {
        ConnectedRenderedMovieProbeBuilder(
            parentKind: parentKind,
            fixtureRoot: fixture.fixtureRoot,
            exportRoot: fixture.exportRoot
        )
    }

    private func buildPackage(
        parentKind: ConnectedRenderedMovieProbeParentKind,
        operationID: UUID = UUID()
    ) throws -> (ConnectedRenderedMovieProbeBuilder.Package, Fixture) {
        try XCTSkipUnless(
            NativeFCPXMLDTD.isInstalled(version: "1.14"),
            "FCPXML 1.14 DTD not installed"
        )
        let fixture = try temporaryFixture(parentKind: parentKind, validSource: true)
        let package = try builder(parentKind: parentKind, fixture: fixture).build(
            operationID: operationID,
            generatedAt: Date(timeIntervalSince1970: 0),
            preparedMovie: fixture.prepared
        )
        return (package, fixture)
    }

    private func copyAsReturned(
        package: ConnectedRenderedMovieProbeBuilder.Package,
        transform: (String) -> String = { $0 }
    ) throws -> URL {
        let returnedBundle = package.packageRoot
            .appendingPathComponent("Returned/returned.fcpxmld", isDirectory: true)
        try fileManager.createDirectory(at: returnedBundle, withIntermediateDirectories: false)
        let returnedURL = returnedBundle.appendingPathComponent("Info.fcpxml")
        var source = try String(contentsOf: package.fcpxmlURL, encoding: .utf8)
        if package.parentKind == .movie {
            source = source.replacingOccurrences(
                of: "<format id=\"r1\" name=\"FFVideoFormat1080p30\"/>",
                with: "<format id=\"r1\" name=\"FFVideoFormat1080p30\" frameDuration=\"100/3000s\" width=\"1920\" height=\"1080\" colorSpace=\"1-1-1 (Rec. 709)\"/>"
            )
        }
        try Data(transform(source).utf8).write(to: returnedURL, options: .atomic)
        return returnedURL
    }

    // MARK: - Exact probe shape

    func testMovieParentUsesOneOpaqueVideoOnlyMovieAsConnectedVideo() throws {
        let fixture = try temporaryFixture(parentKind: .movie)
        let xml = builder(parentKind: .movie, fixture: fixture).makeFCPXML(
            sourceMediaURL: URL(fileURLWithPath: "/tmp/probe/Media/clip-a.mov"),
            renderedMediaURL: URL(fileURLWithPath: "/tmp/probe/Media/connected-rendered.mov"),
            renderedFilename: "connected-rendered.mov"
        )

        XCTAssertTrue(xml.contains("<asset id=\"r2\" name=\"clip-a.mov\" start=\"0s\" duration=\"8s\" hasVideo=\"1\" hasAudio=\"1\""), xml)
        XCTAssertTrue(xml.contains("<asset id=\"r3\" name=\"connected-rendered.mov\" start=\"0s\" duration=\"4s\" hasVideo=\"1\" format=\"r1\">"), xml)
        XCTAssertFalse(xml.contains("<asset id=\"r3\" name=\"connected-rendered.mov\" start=\"0s\" duration=\"4s\" hasVideo=\"1\" hasAudio="), xml)

        let parent = try XCTUnwrap(xml.range(of: "<asset-clip name=\"clip-a.mov\" ref=\"r2\" format=\"r1\" offset=\"0s\" start=\"0s\" duration=\"4s\" audioRole=\"dialogue\">"))
        let connected = try XCTUnwrap(xml.range(of: "<video ref=\"r3\" lane=\"1\" offset=\"0s\" name=\"connected-rendered.mov\" start=\"0s\" duration=\"4s\"/>"))
        XCTAssertTrue(parent.lowerBound < connected.lowerBound)
        XCTAssertFalse(xml.contains("<adjust-"), xml)
        XCTAssertFalse(xml.contains("<filter-"), xml)
    }

    func testStillParentPreservesStillOriginWhileConnectedMovieStartsAtZero() throws {
        let fixture = try temporaryFixture(parentKind: .still)
        let xml = builder(parentKind: .still, fixture: fixture).makeFCPXML(
            sourceMediaURL: URL(fileURLWithPath: "/tmp/probe/Media/living-still.png"),
            renderedMediaURL: URL(fileURLWithPath: "/tmp/probe/Media/connected-rendered.mov"),
            renderedFilename: "connected-rendered.mov"
        )

        XCTAssertTrue(xml.contains("<video ref=\"r2\" offset=\"0s\" name=\"living-still\" start=\"3600s\" duration=\"4s\">"), xml)
        XCTAssertTrue(xml.contains("<video ref=\"r3\" lane=\"1\" offset=\"0s\" name=\"connected-rendered.mov\" start=\"0s\" duration=\"4s\"/>"), xml)
        XCTAssertTrue(xml.contains("<asset id=\"r3\" name=\"connected-rendered.mov\" start=\"0s\" duration=\"4s\" hasVideo=\"1\" format=\"r1\">"), xml)
        XCTAssertFalse(xml.contains("<asset-clip"), xml)
        XCTAssertFalse(xml.contains("<adjust-"), xml)
    }

    // MARK: - Immutable package and pre-admission evidence

    func testBuildCreatesExactPackageAndKeepsSemanticChecksUnknown() throws {
        let (package, fixture) = try buildPackage(parentKind: .movie)
        let entries = try fileManager.contentsOfDirectory(atPath: package.packageRoot.path)
        XCTAssertEqual(
            Set(entries),
            Set(["Media", "Returned", "README.md", "evidence.json", ConnectedRenderedMovieProbeParentKind.movie.fcpxmlFilename])
        )
        XCTAssertEqual(
            try fileManager.contentsOfDirectory(atPath: package.packageRoot.appendingPathComponent("Returned").path),
            []
        )
        XCTAssertEqual(
            try ContentHasher.sha256File(fixture.fixtureRoot.appendingPathComponent("clip-a.mov")),
            package.sourceSHA256
        )
        XCTAssertEqual(try ContentHasher.sha256File(package.sourceMediaURL), package.sourceSHA256)
        XCTAssertEqual(try ContentHasher.sha256File(package.renderedMediaURL), package.renderedSHA256)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let evidence = try decoder.decode(
            ConnectedRenderedMovieProbeBuilder.Evidence.self,
            from: Data(contentsOf: package.evidenceURL)
        )
        XCTAssertEqual(evidence.semanticAcceptance, .unknown)
        XCTAssertFalse(evidence.finalCutAutomationPerformed)
        XCTAssertTrue(evidence.manualImportExportPending)
        XCTAssertEqual(evidence.rendered.codec, "prores")
        XCTAssertEqual(evidence.rendered.codecProfile, "HQ")
        XCTAssertEqual(evidence.rendered.codecTag, "apch")
        XCTAssertTrue(evidence.rendered.videoOnly)
        let semanticChecks = evidence.checks.filter { $0.name == "connected movie element" || $0.name == "parent context" || $0.name == "import admission" || $0.name == "editability" || $0.name == "returned FCPXML round trip" }
        XCTAssertEqual(semanticChecks.count, 5)
        XCTAssertTrue(semanticChecks.allSatisfy { $0.status == .unknown })
    }

    func testRefusesToOverwriteAnExistingProbePackage() throws {
        let operationID = UUID()
        let (package, fixture) = try buildPackage(parentKind: .still, operationID: operationID)
        XCTAssertThrowsError(
            try builder(parentKind: .still, fixture: fixture).build(
                operationID: operationID,
                generatedAt: Date(timeIntervalSince1970: 0),
                preparedMovie: fixture.prepared
            )
        ) { error in
            XCTAssertEqual(error as? ConnectedRenderedMovieProbeError, .existingPackage(package.packageRoot))
        }
    }

    func testRefusesSpentEvidenceAndLibraryRoots() throws {
        let fixture = try temporaryFixture(parentKind: .still)
        let forbidden: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/FCPCommandConsole/exports/ground-truth/new-probe"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/FCPCommandConsole/exports/living-still-probes/new-probe"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/FCPCommandConsole/Test.fcpbundle/probes"),
            URL(fileURLWithPath: "/Applications/Final Cut Pro.app/probes")
        ]
        for root in forbidden {
            let candidate = ConnectedRenderedMovieProbeBuilder(
                parentKind: .still,
                fixtureRoot: fixture.fixtureRoot,
                exportRoot: root
            )
            XCTAssertThrowsError(try candidate.validateExportRoot(root), "should reject \(root.path)")
        }
    }

    func testBuildRejectsAFileThatDoesNotMatchThePinnedSourceFixtureContract() throws {
        try XCTSkipUnless(
            NativeFCPXMLDTD.isInstalled(version: "1.14"),
            "FCPXML 1.14 DTD not installed"
        )
        let fixture = try temporaryFixture(parentKind: .movie)
        XCTAssertThrowsError(
            try builder(parentKind: .movie, fixture: fixture).build(
                operationID: UUID(),
                generatedAt: Date(timeIntervalSince1970: 0),
                preparedMovie: fixture.prepared
            )
        ) { error in
            guard case .invalidSourceFixture = error as? ConnectedRenderedMovieProbeError else {
                return XCTFail("expected invalidSourceFixture, got \(error)")
            }
        }
        XCTAssertFalse(fileManager.fileExists(atPath: fixture.exportRoot.path))
    }

    // MARK: - Read-only returned-export verification

    /// Copying the generated source simulates a structurally unchanged returned
    /// document. This unit test proves verifier behavior, not Final Cut admission.
    func testVerifierPassesAnUnchangedReturnedDocumentForBothParentKinds() throws {
        for parentKind in ConnectedRenderedMovieProbeParentKind.allCases {
            let (package, _) = try buildPackage(parentKind: parentKind)
            let returnedURL = try copyAsReturned(package: package)
            let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
                packageRoot: package.packageRoot,
                returnedXMLURL: returnedURL
            )
            XCTAssertEqual(report.status, .pass, "\(parentKind): \(report.checks)")
            XCTAssertTrue(report.checks.allSatisfy { $0.status == .pass })
            XCTAssertEqual(report.parentKind, parentKind)
        }
    }

    func testVerifierRejectsLaneDriftEvenThoughReturnedDocumentRemainsDTDValid() throws {
        let (package, _) = try buildPackage(parentKind: .movie)
        let returnedURL = try copyAsReturned(package: package) { source in
            source.replacingOccurrences(of: "lane=\"1\"", with: "lane=\"2\"")
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.status, .fail)
        XCTAssertEqual(
            report.checks.first { $0.name == "returned DTD validity" }?.status,
            .pass
        )
        XCTAssertEqual(
            report.checks.first { $0.name == "connected rendered movie" }?.status,
            .fail
        )
    }

    func testVerifierRejectsADisabledConnectedMovieEvenThoughDTDValid() throws {
        let (package, _) = try buildPackage(parentKind: .still)
        let returnedURL = try copyAsReturned(package: package) { source in
            source.replacingOccurrences(of: "lane=\"1\"", with: "lane=\"1\" enabled=\"0\"")
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.checks.first { $0.name == "returned DTD validity" }?.status, .pass)
        XCTAssertEqual(report.checks.first { $0.name == "connected rendered movie" }?.status, .fail)
        XCTAssertEqual(report.status, .fail)
    }

    func testVerifierRejectsMutedOrRemappedMovieAudioEvenThoughDTDValid() throws {
        let (package, _) = try buildPackage(parentKind: .movie)
        let returnedURL = try copyAsReturned(package: package) { source in
            source
                .replacingOccurrences(
                    of: "audioRole=\"dialogue\">",
                    with: "audioRole=\"dialogue\" srcEnable=\"video\">"
                )
                .replacingOccurrences(
                    of: "</asset-clip>",
                    with: "<audio-channel-source srcCh=\"1, 2\" active=\"0\"/>\n          </asset-clip>"
                )
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.checks.first { $0.name == "returned DTD validity" }?.status, .pass)
        XCTAssertEqual(report.checks.first { $0.name == "unchanged spine" }?.status, .fail)
        XCTAssertEqual(report.status, .fail)
    }

    func testVerifierRejectsAnExtraSpineTransitionEvenThoughDTDValid() throws {
        let (package, _) = try buildPackage(parentKind: .still)
        let returnedURL = try copyAsReturned(package: package) { source in
            source.replacingOccurrences(
                of: "<spine>",
                with: "<spine>\n          <transition name=\"Cross Dissolve\" offset=\"0s\" duration=\"1s\"/>"
            )
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.checks.first { $0.name == "returned DTD validity" }?.status, .pass)
        XCTAssertEqual(report.checks.first { $0.name == "sequence geometry" }?.status, .fail)
        XCTAssertEqual(report.status, .fail)
    }

    func testVerifierRejectsAnExtraContainedChildWhoseLaneIsOmitted() throws {
        let (package, _) = try buildPackage(parentKind: .still)
        let returnedURL = try copyAsReturned(package: package) { source in
            source.replacingOccurrences(
                of: "</video>\n        </spine>",
                with: "<video ref=\"r3\" offset=\"0s\" name=\"unexpected-duplicate\" start=\"0s\" duration=\"1s\"/>\n          </video>\n        </spine>"
            )
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.checks.first { $0.name == "returned DTD validity" }?.status, .pass)
        XCTAssertEqual(report.checks.first { $0.name == "connected rendered movie" }?.status, .fail)
        XCTAssertEqual(report.status, .fail)
    }

    func testVerifierRejectsReturnedFormatGeometryDriftEvenThoughDTDValid() throws {
        let (package, _) = try buildPackage(parentKind: .still)
        let returnedURL = try copyAsReturned(package: package) { source in
            source.replacingOccurrences(
                of: "frameDuration=\"100/3000s\" width=\"1920\" height=\"1080\"",
                with: "frameDuration=\"1/25s\" width=\"1280\" height=\"720\""
            )
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.checks.first { $0.name == "returned DTD validity" }?.status, .pass)
        XCTAssertEqual(report.checks.first { $0.name == "sequence geometry" }?.status, .fail)
        XCTAssertEqual(report.status, .fail)
    }

    func testVerifierRejectsReturnedRootVersionDriftIndependentlyOfDTDValidation() throws {
        let (package, _) = try buildPackage(parentKind: .still)
        let returnedURL = try copyAsReturned(package: package) { source in
            source.replacingOccurrences(of: "<fcpxml version=\"1.14\">", with: "<fcpxml version=\"1.13\">")
        }
        let report = try ConnectedRenderedMovieRoundTripVerifier().verify(
            packageRoot: package.packageRoot,
            returnedXMLURL: returnedURL
        )
        XCTAssertEqual(report.checks.first { $0.name == "returned DTD validity" }?.status, .fail)
        XCTAssertEqual(report.checks.first { $0.name == "returned FCPXML version" }?.status, .fail)
        XCTAssertEqual(report.status, .fail)
    }

    func testVerifierBindsRequestedVersionToPackageEvidence() throws {
        let (package, _) = try buildPackage(parentKind: .still)
        let returnedURL = try copyAsReturned(package: package)
        XCTAssertThrowsError(
            try ConnectedRenderedMovieRoundTripVerifier(
                fcpxmlVersion: "1.13",
                dtdURL: NativeFCPXMLDTD.url(forVersion: "1.14")
            ).verify(
                packageRoot: package.packageRoot,
                returnedXMLURL: returnedURL
            )
        ) { error in
            guard case .invalidEvidence = error as? ConnectedRenderedMovieProbeError else {
                return XCTFail("expected invalidEvidence, got \(error)")
            }
        }
    }

    func testVerifierRequiresReturnedXMLToStayInsidePackageReturnedDirectory() throws {
        let (package, fixture) = try buildPackage(parentKind: .still)
        let outside = fixture.root.appendingPathComponent("outside.fcpxml")
        try fileManager.copyItem(at: package.fcpxmlURL, to: outside)
        XCTAssertThrowsError(
            try ConnectedRenderedMovieRoundTripVerifier().verify(
                packageRoot: package.packageRoot,
                returnedXMLURL: outside
            )
        ) { error in
            guard case .returnedFileOutsidePackage = error as? ConnectedRenderedMovieProbeError else {
                return XCTFail("expected returnedFileOutsidePackage, got \(error)")
            }
        }
    }
}
