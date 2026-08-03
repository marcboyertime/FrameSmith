import Darwin
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import FCPCommandConsoleCore

final class LocalMediaTests: XCTestCase {
    private var root: URL!
    private var still: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("fcpcc-local-media-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        still = root.appendingPathComponent("source.png")
        try writePNG(to: still)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
        root = nil
        still = nil
        try super.tearDownWithError()
    }

    func testAdmissionReadsRealStillMetadataHashesBytesAndPreservesSource() async throws {
        let before = try Data(contentsOf: still)
        let admitted = try await LocalMediaAdmission().admit(still)
        XCTAssertEqual(admitted.kind, .still)
        XCTAssertEqual(admitted.dimensions, LocalMediaDimensions(width: 3, height: 2))
        XCTAssertNil(admitted.durationSeconds)
        XCTAssertNil(admitted.frameRate)
        XCTAssertFalse(admitted.hasAudio)
        XCTAssertEqual(admitted.canonicalPath, still.path)
        XCTAssertEqual(admitted.sha256, ContentHasher.sha256(before))
        XCTAssertEqual(try Data(contentsOf: still), before)
        XCTAssertEqual(admitted.sourceIdentity.canonicalPath, still.path)
    }

    func testAdmissionRejectsSymlinkDirectoryFIFOUnsupportedAndFinalCutLibraryPaths() async throws {
        let directory = root.appendingPathComponent("directory", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        await assertAdmission(directory, equals: .notRegularFile(directory))

        let link = root.appendingPathComponent("source-link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: still)
        await assertAdmission(link, equals: .symlink(link))

        let fifo = root.appendingPathComponent("source.fifo")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        await assertAdmission(fifo, equals: .notRegularFile(fifo))

        let unsupported = root.appendingPathComponent("source.txt")
        try Data("not media".utf8).write(to: unsupported)
        await assertAdmission(unsupported, equals: .unsupportedMedia(unsupported))

        let library = root.appendingPathComponent("test.fcpbundle", isDirectory: true)
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        let libraryImage = library.appendingPathComponent("source.png")
        try writePNG(to: libraryImage)
        await assertAdmission(libraryImage, equals: .forbiddenFinalCutPath(libraryImage))
    }

    func testExplicitRolesProduceLocalOnlyTokensAndEnforceCounts() async throws {
        let first = try await LocalMediaAdmission().admit(still)
        let secondURL = root.appendingPathComponent("second.png")
        try writePNG(to: secondURL)
        let second = try await LocalMediaAdmission().admit(secondURL)

        let single = try LocalMediaSelection(effectID: .targetedRotateZoom, primary: first, outgoing: nil, incoming: nil)
        XCTAssertEqual(single.slots.map(\.role), [.primary])
        XCTAssertEqual(single.token.selectionType, .singleClip)
        XCTAssertEqual(single.token.timelineID, LocalMediaSelection.timelineID)
        XCTAssertFalse(single.token.isSpine)
        XCTAssertFalse(single.token.adjacent)

        let dissolve = try LocalMediaSelection(effectID: .naturalDissolve, primary: nil, outgoing: first, incoming: second)
        XCTAssertEqual(dissolve.slots.map(\.role), [.outgoing, .incoming])
        XCTAssertEqual(dissolve.token.clipIDs, [first.itemID, second.itemID])
        XCTAssertEqual(dissolve.token.selectionType, .twoAdjacentClips)
        XCTAssertThrowsError(try LocalMediaSelection(effectID: .naturalDissolve, primary: nil, outgoing: first, incoming: nil)) { error in
            XCTAssertEqual(error as? LocalMediaSelectionError, .missingRole(.incoming))
        }
        XCTAssertThrowsError(try LocalMediaSelection(effectID: .oldTelevision, primary: first, outgoing: second, incoming: nil)) { error in
            XCTAssertEqual(error as? LocalMediaSelectionError, .unexpectedRole(.outgoing))
        }
        XCTAssertThrowsError(try LocalMediaSelection(effectID: .naturalDissolve, primary: nil, outgoing: first, incoming: first))
    }

    func testLocalPlanningUsesV2AndCapabilityGateKeepsFCPXMLClosed() async throws {
        let admitted = try await LocalMediaAdmission().admit(still)
        let secondURL = root.appendingPathComponent("dissolve.png")
        try writePNG(to: secondURL)
        let second = try await LocalMediaAdmission().admit(secondURL)
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let registry = try EffectRegistry.load(from: project.appendingPathComponent("registry/effects"))
        let schema = try PlanSchemaValidator(schemaURL: project.appendingPathComponent("schemas/effect-plan.schema.json"))
        let session = LocalMediaPlannerSession(registry: registry, schemaValidator: schema)
        let result = try session.plan(
            request: "Give this image a slow clockwise rotation while zooming toward the point I select.",
            primary: admitted,
            outgoing: nil,
            incoming: nil,
            target: .confirmed(x: 0.4, y: 0.6)
        )
        XCTAssertEqual(result.plan.schemaVersion, "2.0")
        XCTAssertEqual(result.plan.selectionToken.timelineID, LocalMediaSelection.timelineID)
        XCTAssertEqual(result.plan.selectionToken.origin, .localMedia)
        XCTAssertTrue(result.localPreviewDecision.allowed)
        XCTAssertFalse(result.fcpxmlExportDecision.allowed)
        XCTAssertEqual(result.fcpxmlExportDecision.reason, "Local media selection does not establish Final Cut selection or adjacency evidence")
        XCTAssertThrowsError(try CapabilityGate(manualSemanticsEvidence: .init(admittedContracts: Set(FCPXMLSemanticContract.allCases))).require(result.plan, capability: .fcpxmlExport)) { error in
            XCTAssertEqual(error as? CapabilityGateError, .localMediaSelectionIsNotFinalCutEvidence(.fcpxmlExport))
        }
        let dissolve = try session.plan(
            request: "Make this clip dissolve naturally into the next clip.",
            primary: nil,
            outgoing: admitted,
            incoming: second,
            target: nil
        )
        XCTAssertEqual(dissolve.plan.effectID, .naturalDissolve)
        XCTAssertFalse(dissolve.fcpxmlExportDecision.allowed)
    }

    func testAspectFitPointMappingRejectsLetterboxAndRoundTrips() throws {
        let media = MediaSize(width: 1920, height: 1080)
        let container = MediaSize(width: 1000, height: 1000)
        let rect = try AspectFitPointMapper.displayedRect(media: media, in: container)
        XCTAssertEqual(rect.origin.y, 218.75, accuracy: 0.000_001)
        XCTAssertEqual(rect.size.width, 1000, accuracy: 0.000_001)
        XCTAssertEqual(rect.size.height, 562.5, accuracy: 0.000_001)
        XCTAssertThrowsError(try AspectFitPointMapper.target(for: MediaPoint(x: 500, y: 100), media: media, in: container)) { error in
            XCTAssertEqual(error as? AspectFitPointMappingError, .outsideDisplayedMedia)
        }
        let target = try AspectFitPointMapper.target(for: MediaPoint(x: 250, y: 500), media: media, in: container)
        XCTAssertEqual(target.x, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(target.y, 0.5, accuracy: 0.000_001)
        let roundTrip = try AspectFitPointMapper.viewPoint(for: target, media: media, in: container)
        XCTAssertEqual(roundTrip.x, 250, accuracy: 0.000_001)
        XCTAssertEqual(roundTrip.y, 500, accuracy: 0.000_001)
        XCTAssertThrowsError(try AspectFitPointMapper.target(for: MediaPoint(x: .nan, y: 0), media: media, in: container)) { error in
            XCTAssertEqual(error as? AspectFitPointMappingError, .nonFiniteCoordinates)
        }
    }

    func testAdmissionGenerationMakesOlderAndCancelledWorkStaleDeterministically() {
        var generation = LocalMediaOperationGeneration()
        let first = generation.begin(.primary)
        let newer = generation.begin(.primary)
        XCTAssertFalse(generation.isCurrent(first, for: .primary))
        XCTAssertTrue(generation.isCurrent(newer, for: .primary))
        generation.cancel(.primary)
        XCTAssertFalse(generation.isCurrent(newer, for: .primary))
        let outgoing = generation.begin(.outgoing)
        XCTAssertTrue(generation.isCurrent(outgoing, for: .outgoing))
        generation.cancelAll()
        XCTAssertFalse(generation.isCurrent(outgoing, for: .outgoing))
    }

    private func assertAdmission(_ url: URL, equals expected: LocalMediaAdmissionError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await LocalMediaAdmission().admit(url)
            XCTFail("Expected admission failure", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? LocalMediaAdmissionError, expected, file: file, line: line)
        }
    }

    private func writePNG(to url: URL) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(CGContext(data: nil, width: 3, height: 2, bitsPerComponent: 8, bytesPerRow: 12, space: colorSpace, bitmapInfo: bitmapInfo))
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
