import Darwin
import XCTest
@testable import FCPCommandConsoleCore

final class FCPXMLRoundTripSpikeTests: XCTestCase {
    private var root: URL!
    private var fixtureRoot: URL!
    private var exportRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("fcpcc-roundtrip-\(UUID().uuidString)", isDirectory: true)
        fixtureRoot = root.appendingPathComponent("fixtures & source", isDirectory: true)
        exportRoot = root.appendingPathComponent("exports & review", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try Data("fixture-a".utf8).write(to: fixtureRoot.appendingPathComponent("clip-a.mov"))
        try Data("fixture-b".utf8).write(to: fixtureRoot.appendingPathComponent("clip-b.mov"))
        try Data("fixture-still".utf8).write(to: fixtureRoot.appendingPathComponent("living-still.png"))
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
        root = nil
        fixtureRoot = nil
        exportRoot = nil
        try super.tearDownWithError()
    }

    private func dtdURL() throws -> URL {
        let dtd = FCPXMLRoundTripSpikeBuilder.defaultDTDURL
        guard FileManager.default.isReadableFile(atPath: dtd.path) else { throw XCTSkip("Installed FCPXML 1.13 DTD is unavailable") }
        return dtd
    }

    private func builder(dtd: URL? = nil) throws -> FCPXMLRoundTripSpikeBuilder {
        let selectedDTD = try dtd ?? dtdURL()
        return FCPXMLRoundTripSpikeBuilder(fixtureRoot: fixtureRoot, exportRoot: exportRoot, dtdURL: selectedDTD)
    }

    func testBuildCreatesSelfContainedDTDValidThreeProbePackage() throws {
        let operationID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let package = try builder().build(operationID: operationID, generatedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(package.packageRoot, exportRoot.appendingPathComponent(operationID.uuidString))
        XCTAssertEqual(package.mediaRecords.map(\.sourceFilename), ["clip-a.mov", "clip-b.mov", "living-still.png"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.packageRoot.appendingPathComponent("Returned").path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: package.packageRoot, includingPropertiesForKeys: nil).map(\.lastPathComponent).sorted(), ["FCPCommandConsole-RoundTrip-Spike.fcpxml", "Media", "README.md", "Returned", "evidence.json", "manifest.json", "plan.json", "provenance.json"])

        for record in package.mediaRecords {
            let copied = try ContentHasher.sha256File(record.copiedPath)
            let source = try ContentHasher.sha256File(fixtureRoot.appendingPathComponent(record.sourceFilename))
            XCTAssertEqual(copied, source)
            XCTAssertEqual(record.sha256, source)
            XCTAssertGreaterThan(record.byteCount, 0)
        }

        let xml = try String(contentsOf: package.fcpxmlURL, encoding: .utf8)
        XCTAssertTrue(xml.contains("<fcpxml version=\"1.13\">"))
        XCTAssertEqual(xml.components(separatedBy: "<project ").count - 1, 3)
        XCTAssertTrue(xml.contains("<transition name=\"Bare 1-second transition hypothesis\" offset=\"210/30s\" duration=\"30/30s\"/>"))
        XCTAssertTrue(xml.contains("<adjust-transform"))
        XCTAssertTrue(xml.contains("key=\"position\""))
        XCTAssertTrue(xml.contains("key=\"scale\""))
        XCTAssertTrue(xml.contains("key=\"rotation\""))
        XCTAssertTrue(xml.contains("key=\"opacity\""))
        XCTAssertTrue(xml.contains("duration=\"120/30s\""))
        XCTAssertFalse(xml.contains(fixtureRoot.path))
        XCTAssertFalse(xml.contains("fixtures & source"))
        XCTAssertTrue(xml.contains("file:///"))
        XCTAssertTrue(xml.contains("%26"))
        try validateDTD(package.fcpxmlURL, dtd: try dtdURL())
    }

    func testTypedEvidenceAndProvenanceStartUnknownAndRecordNoAutomationOrPaidUpload() throws {
        let package = try builder().build(operationID: UUID())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let evidence = try decoder.decode(FCPXMLRoundTripSpikeEvidence.self, from: Data(contentsOf: package.evidenceLedgerURL))
        let provenance = try decoder.decode(FCPXMLRoundTripSpikeProvenance.self, from: Data(contentsOf: package.packageRoot.appendingPathComponent("provenance.json")))
        let plan = try decoder.decode(FCPXMLRoundTripSpikePlan.self, from: Data(contentsOf: package.packageRoot.appendingPathComponent("plan.json")))

        XCTAssertFalse(evidence.checks.isEmpty)
        XCTAssertTrue(evidence.checks.allSatisfy { $0.status == .unknown })
        XCTAssertEqual(provenance.semanticAcceptance, .unknown)
        XCTAssertFalse(provenance.finalCutAutomationPerformed)
        XCTAssertFalse(provenance.paidCallPerformed)
        XCTAssertFalse(provenance.mediaUploadPerformed)
        XCTAssertTrue(provenance.manualImportExportPending)
        XCTAssertEqual(plan.probes.count, 3)
        XCTAssertTrue(plan.probes.flatMap(\.assumptions).allSatisfy { $0.localizedCaseInsensitiveContains("unverified") || $0.localizedCaseInsensitiveContains("hypotheses") || $0.localizedCaseInsensitiveContains("hypothesis") })
    }

    func testExistingTargetRefusesOverwriteAndFailedDTDPublishCleansExactStagingDirectory() throws {
        let operationID = UUID()
        let validBuilder = try builder()
        _ = try validBuilder.build(operationID: operationID)
        XCTAssertThrowsError(try validBuilder.build(operationID: operationID)) { error in
            XCTAssertEqual(error as? FCPXMLRoundTripSpikeError, .existingPackage(self.exportRoot.appendingPathComponent(operationID.uuidString)))
        }

        let invalidDTD = root.appendingPathComponent("invalid.dtd")
        try Data("not a DTD".utf8).write(to: invalidDTD)
        let failedOperation = UUID()
        XCTAssertThrowsError(try FCPXMLRoundTripSpikeBuilder(fixtureRoot: fixtureRoot, exportRoot: exportRoot, dtdURL: invalidDTD).build(operationID: failedOperation))
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportRoot.appendingPathComponent(failedOperation.uuidString).path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: exportRoot, includingPropertiesForKeys: nil).map(\.lastPathComponent)) ?? []
        XCTAssertFalse(leftovers.contains { $0.hasPrefix(".roundtrip-spike-staging-\(failedOperation.uuidString)") })
    }

    func testSymlinkFixtureIsRejectedAndLeavesNoPackageOrStagingDirectory() throws {
        let source = fixtureRoot.appendingPathComponent("clip-a.mov")
        let target = root.appendingPathComponent("actual-clip-a.mov")
        try Data("fixture-a".utf8).write(to: target)
        try FileManager.default.removeItem(at: source)
        try FileManager.default.createSymbolicLink(at: source, withDestinationURL: target)
        let operationID = UUID()

        XCTAssertThrowsError(try builder().build(operationID: operationID)) { error in
            XCTAssertEqual(error as? FCPXMLRoundTripSpikeError, .symlinkFixture(source))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportRoot.appendingPathComponent(operationID.uuidString).path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: exportRoot, includingPropertiesForKeys: nil).map(\.lastPathComponent)) ?? []
        XCTAssertFalse(leftovers.contains { $0.hasPrefix(".roundtrip-spike-staging-\(operationID.uuidString)") })
    }

    func testNonRegularFixtureIsRejectedBeforeHashingAndLeavesNoPackageOrStagingDirectory() throws {
        let source = fixtureRoot.appendingPathComponent("clip-a.mov")
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(mkfifo(source.path, S_IRUSR | S_IWUSR), 0)
        let operationID = UUID()

        XCTAssertThrowsError(try builder().build(operationID: operationID)) { error in
            XCTAssertEqual(error as? FCPXMLRoundTripSpikeError, .missingFixture(source))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportRoot.appendingPathComponent(operationID.uuidString).path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: exportRoot, includingPropertiesForKeys: nil).map(\.lastPathComponent)) ?? []
        XCTAssertFalse(leftovers.contains { $0.hasPrefix(".roundtrip-spike-staging-\(operationID.uuidString)") })
    }

    func testSymlinkAndForbiddenExportRootsAreRejectedBeforeWriting() throws {
        let symlinkTarget = root.appendingPathComponent("symlink-target", isDirectory: true)
        let symlinkRoot = root.appendingPathComponent("symlink-output", isDirectory: true)
        try FileManager.default.createDirectory(at: symlinkTarget, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkRoot, withDestinationURL: symlinkTarget)
        XCTAssertThrowsError(try FCPXMLRoundTripSpikeBuilder(fixtureRoot: fixtureRoot, exportRoot: symlinkRoot, dtdURL: try dtdURL()).build()) { error in
            XCTAssertEqual(error as? FCPXMLRoundTripSpikeError, .symlinkExportRoot(symlinkRoot))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: symlinkTarget, includingPropertiesForKeys: nil), [])

        let forbiddenRoots = [
            URL(fileURLWithPath: "/", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser,
            URL(fileURLWithPath: "/Applications/FCPCommandConsole-output", isDirectory: true),
            URL(fileURLWithPath: "/Library/FCPCommandConsole-output", isDirectory: true),
            URL(fileURLWithPath: "/System/FCPCommandConsole-output", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/FCPCommandConsole-output", isDirectory: true),
            root.appendingPathComponent("Disposable.fcpbundle/exports", isDirectory: true),
            root.appendingPathComponent("Final Cut Pro.app/exports", isDirectory: true)
        ]
        for forbiddenRoot in forbiddenRoots {
            XCTAssertThrowsError(try FCPXMLRoundTripSpikeBuilder(fixtureRoot: fixtureRoot, exportRoot: forbiddenRoot, dtdURL: try dtdURL()).build()) { error in
                guard case FCPXMLRoundTripSpikeError.forbiddenExportRoot = error else {
                    return XCTFail("Expected forbidden export root, got \(error)")
                }
            }
        }
    }

    func testTemporaryOutputAndMalformedMediaRecordsAreHandledSafely() throws {
        let package = try builder().build(operationID: UUID())
        XCTAssertTrue(package.packageRoot.path.hasPrefix(NSTemporaryDirectory()))

        let spikeBuilder = try builder()
        XCTAssertThrowsError(try spikeBuilder.makeFCPXML(mediaRecords: [])) { error in
            XCTAssertEqual(error as? FCPXMLRoundTripSpikeError, .missingMediaRecord("clip-a.mov"))
        }
        let duplicate = FCPXMLRoundTripSpikeMediaRecord(copiedPath: root.appendingPathComponent("a.mov"), sha256: "hash", byteCount: 1, sourceFilename: "clip-a.mov")
        XCTAssertThrowsError(try spikeBuilder.makeFCPXML(mediaRecords: [duplicate, duplicate])) { error in
            XCTAssertEqual(error as? FCPXMLRoundTripSpikeError, .duplicateMediaRecord("clip-a.mov"))
        }
    }

    func testOnlyProductExportsAndTemporaryDescendantsAreAdmitted() throws {
        let spikeBuilder = try builder()
        let defaultRuntime = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/FCPCommandConsole/exports/roundtrip-spikes", isDirectory: true)
        let temporaryChild = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("fcpcc-roundtrip-admission-\(UUID().uuidString)", isDirectory: true)
        let tmpChild = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("fcpcc-roundtrip-admission-\(UUID().uuidString)", isDirectory: true)

        XCTAssertNoThrow(try spikeBuilder.validateExportRoot(defaultRuntime))
        XCTAssertNoThrow(try spikeBuilder.validateExportRoot(temporaryChild))
        XCTAssertNoThrow(try spikeBuilder.validateExportRoot(tmpChild))
        XCTAssertThrowsError(try spikeBuilder.validateExportRoot(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)))
    }

    func testCLIRejectsRelativeDuplicateMissingAndUnknownArguments() throws {
        let executable = projectRoot().appendingPathComponent(".build/debug/fcpcommandconsole-roundtrip-spike")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw XCTSkip("round-trip CLI was not built") }
        for arguments in [
            ["--fixture-root", "relative"],
            ["--export-root", "/tmp/../roundtrip"],
            ["--export-root", "/tmp/a", "--export-root", "/tmp/b"],
            ["--operation-id"],
            ["--unknown"]
        ] {
            XCTAssertNotEqual(try run(executable, arguments).status, 0, "Expected failure for \(arguments)")
        }
        XCTAssertEqual(try run(executable, ["--help"]).status, 0)
    }

    private func validateDTD(_ xml: URL, dtd: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xmllint")
        process.arguments = ["--nonet", "--noout", "--dtdvalid", dtd.absoluteString, xml.absoluteString]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func run(_ executable: URL, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
    }
}
