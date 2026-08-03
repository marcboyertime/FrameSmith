import Darwin
import Foundation

public enum FCPXMLRoundTripSpikeError: Error, LocalizedError, Equatable {
    case nonAbsolutePath(URL)
    case pathTraversal(URL)
    case missingFixture(URL)
    case symlinkFixture(URL)
    case symlinkDestination(URL)
    case invalidDTD(URL)
    case forbiddenExportRoot(URL)
    case symlinkExportRoot(URL)
    case exportRootEscape(URL)
    case existingPackage(URL)
    case copyVerificationFailed(URL)
    case dtdValidationFailed(String)
    case dtdValidationTimedOut
    case malformedGeneratedXML
    case missingMediaRecord(String)
    case duplicateMediaRecord(String)

    public var errorDescription: String? {
        switch self {
        case .nonAbsolutePath(let url): return "An absolute file path is required: \(url.path)"
        case .pathTraversal(let url): return "Path traversal is not allowed: \(url.path)"
        case .missingFixture(let url): return "Required disposable fixture is missing or not a regular readable file: \(url.path)"
        case .symlinkFixture(let url): return "Fixture media must be a regular file, not a symlink: \(url.path)"
        case .symlinkDestination(let url): return "Copied package media must be a regular file, not a symlink: \(url.path)"
        case .invalidDTD(let url): return "FCPXML 1.13 DTD is missing or not readable: \(url.path)"
        case .forbiddenExportRoot(let url): return "Round-trip package output is forbidden at this path: \(url.path)"
        case .symlinkExportRoot(let url): return "Round-trip package output cannot use a symlink path: \(url.path)"
        case .exportRootEscape(let url): return "Round-trip package path escaped its approved export root: \(url.path)"
        case .existingPackage(let url): return "Refusing to overwrite an existing round-trip package: \(url.path)"
        case .copyVerificationFailed(let url): return "Copied media hash did not match its fixture: \(url.path)"
        case .dtdValidationFailed(let detail): return "FCPXML 1.13 DTD validation failed: \(detail)"
        case .dtdValidationTimedOut: return "FCPXML 1.13 DTD validation timed out"
        case .malformedGeneratedXML: return "Generated FCPXML was not valid UTF-8"
        case .missingMediaRecord(let filename): return "Required media record is missing: \(filename)"
        case .duplicateMediaRecord(let filename): return "Duplicate media record is not allowed: \(filename)"
        }
    }
}

public enum FCPXMLRoundTripEvidenceStatus: String, Codable, Equatable, Sendable {
    case pass
    case fail
    case unknown
}

public struct FCPXMLRoundTripSpikePredecessorFailure: Codable, Equatable, Sendable {
    public let operationID: String
    public let crashIncidentID: String
    public let applicationVersion: String
    public let applicationBuild: String
    public let occurredAt: String
    public let importStage: String
    public let status: FCPXMLRoundTripEvidenceStatus

    public init(operationID: String, crashIncidentID: String, applicationVersion: String, applicationBuild: String, occurredAt: String, importStage: String, status: FCPXMLRoundTripEvidenceStatus) {
        self.operationID = operationID
        self.crashIncidentID = crashIncidentID
        self.applicationVersion = applicationVersion
        self.applicationBuild = applicationBuild
        self.occurredAt = occurredAt
        self.importStage = importStage
        self.status = status
    }
}

public struct FCPXMLRoundTripSpikeMediaRecord: Codable, Equatable, Sendable {
    public let copiedPath: URL
    public let sha256: String
    public let byteCount: Int64
    public let sourceFilename: String

    public init(copiedPath: URL, sha256: String, byteCount: Int64, sourceFilename: String) {
        self.copiedPath = copiedPath
        self.sha256 = sha256
        self.byteCount = byteCount
        self.sourceFilename = sourceFilename
    }
}

public struct FCPXMLRoundTripSpikePackage: Codable, Equatable, Sendable {
    public let operationID: UUID
    public let packageRoot: URL
    public let fcpxmlURL: URL
    public let instructionsURL: URL
    public let manifestURL: URL
    public let evidenceLedgerURL: URL
    public let mediaRecords: [FCPXMLRoundTripSpikeMediaRecord]

    public init(operationID: UUID, packageRoot: URL, fcpxmlURL: URL, instructionsURL: URL, manifestURL: URL, evidenceLedgerURL: URL, mediaRecords: [FCPXMLRoundTripSpikeMediaRecord]) {
        self.operationID = operationID
        self.packageRoot = packageRoot
        self.fcpxmlURL = fcpxmlURL
        self.instructionsURL = instructionsURL
        self.manifestURL = manifestURL
        self.evidenceLedgerURL = evidenceLedgerURL
        self.mediaRecords = mediaRecords
    }
}

public struct FCPXMLRoundTripSpikePlan: Codable, Equatable, Sendable {
    public struct Probe: Codable, Equatable, Sendable {
        public let projectName: String
        public let purpose: String
        public let assumptions: [String]
    }

    public let schemaVersion: String
    public let probeRevision: Int
    public let operationID: UUID
    public let generatedAt: Date
    public let frameRate: String
    public let probes: [Probe]
}

public struct FCPXMLRoundTripSpikeProvenance: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let probeRevision: Int
    public let operationID: UUID
    public let generatedAt: Date
    public let finalCutAutomationPerformed: Bool
    public let paidCallPerformed: Bool
    public let mediaUploadPerformed: Bool
    public let manualImportExportPending: Bool
    public let semanticAcceptance: FCPXMLRoundTripEvidenceStatus
    public let predecessorFailure: FCPXMLRoundTripSpikePredecessorFailure
}

public struct FCPXMLRoundTripSpikeEvidence: Codable, Equatable, Sendable {
    public struct Check: Codable, Equatable, Sendable {
        public let name: String
        public let status: FCPXMLRoundTripEvidenceStatus
        public let note: String
    }

    public let schemaVersion: String
    public let probeRevision: Int
    public let operationID: UUID
    public let generatedAt: Date
    public let predecessorFailure: FCPXMLRoundTripSpikePredecessorFailure
    public let checks: [Check]
}

public struct FCPXMLRoundTripSpikeManifest: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let probeRevision: Int
    public let operationID: UUID
    public let media: [FCPXMLRoundTripSpikeMediaRecord]
    public let expectedPackageEntries: [String]
}

/// Builds a self-contained, manually imported FCPXML 1.13 probe. It never
/// controls Final Cut Pro and deliberately records all native-semantic checks as
/// unknown until a person returns an exported FCPXML for inspection.
public struct FCPXMLRoundTripSpikeBuilder: Sendable {
    public static let defaultDTDURL = URL(fileURLWithPath: "/Applications/Final Cut Pro.app/Contents/Frameworks/Interchange.framework/Versions/A/Resources/FCPXMLv1_13.dtd")

    public let fixtureRoot: URL
    public let exportRoot: URL
    public let dtdURL: URL

    public init(fixtureRoot: URL, exportRoot: URL, dtdURL: URL = FCPXMLRoundTripSpikeBuilder.defaultDTDURL) {
        self.fixtureRoot = fixtureRoot
        self.exportRoot = exportRoot
        self.dtdURL = dtdURL
    }

    public func build(operationID: UUID = UUID(), generatedAt: Date = Date()) throws -> FCPXMLRoundTripSpikePackage {
        try validateAbsolutePath(fixtureRoot)
        let approvedExportRoot = try validateExportRoot(exportRoot)
        try validateReadableFile(dtdURL, invalidDTD: true)

        let finalRoot = try outputChild(named: operationID.uuidString, of: approvedExportRoot)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: finalRoot.path) else { throw FCPXMLRoundTripSpikeError.existingPackage(finalRoot) }
        try fileManager.createDirectory(at: approvedExportRoot, withIntermediateDirectories: true)
        _ = try validateExportRoot(approvedExportRoot)

        let stagingRoot = try outputChild(named: ".roundtrip-spike-staging-\(operationID.uuidString)-\(UUID().uuidString)", of: approvedExportRoot)
        do {
            try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: false)
            let mediaRoot = stagingRoot.appendingPathComponent("Media", isDirectory: true)
            try fileManager.createDirectory(at: mediaRoot, withIntermediateDirectories: false)
            try fileManager.createDirectory(at: stagingRoot.appendingPathComponent("Returned", isDirectory: true), withIntermediateDirectories: false)

            let mediaRecords = try copyFixtures(to: mediaRoot, publishedMediaRoot: finalRoot.appendingPathComponent("Media", isDirectory: true))
            let plan = makePlan(operationID: operationID, generatedAt: generatedAt)
            let provenance = FCPXMLRoundTripSpikeProvenance(
                schemaVersion: "1.1",
                probeRevision: 2,
                operationID: operationID,
                generatedAt: generatedAt,
                finalCutAutomationPerformed: false,
                paidCallPerformed: false,
                mediaUploadPerformed: false,
                manualImportExportPending: true,
                semanticAcceptance: .unknown,
                predecessorFailure: predecessorFailure()
            )
            let evidence = makeEvidence(operationID: operationID, generatedAt: generatedAt)
            let manifest = FCPXMLRoundTripSpikeManifest(
                schemaVersion: "1.1",
                probeRevision: 2,
                operationID: operationID,
                media: mediaRecords,
                expectedPackageEntries: ["Media/clip-a.mov", "Media/clip-b.mov", "FCPCommandConsole-RoundTrip-Spike.fcpxml", "plan.json", "provenance.json", "manifest.json", "evidence.json", "README.md", "Returned/"]
            )
            try writeJSON(plan, to: stagingRoot.appendingPathComponent("plan.json"))
            try writeJSON(provenance, to: stagingRoot.appendingPathComponent("provenance.json"))
            try writeJSON(manifest, to: stagingRoot.appendingPathComponent("manifest.json"))
            try writeJSON(evidence, to: stagingRoot.appendingPathComponent("evidence.json"))
            try Data(readme(operationID: operationID).utf8).write(to: stagingRoot.appendingPathComponent("README.md"), options: .atomic)

            let fcpxmlURL = stagingRoot.appendingPathComponent("FCPCommandConsole-RoundTrip-Spike.fcpxml")
            let xml = try makeFCPXML(mediaRecords: mediaRecords)
            guard let xmlData = xml.data(using: .utf8) else { throw FCPXMLRoundTripSpikeError.malformedGeneratedXML }
            try xmlData.write(to: fcpxmlURL, options: .atomic)
            try validateDTD(xmlURL: fcpxmlURL)

            guard !fileManager.fileExists(atPath: finalRoot.path) else { throw FCPXMLRoundTripSpikeError.existingPackage(finalRoot) }
            try fileManager.moveItem(at: stagingRoot, to: finalRoot)
            return FCPXMLRoundTripSpikePackage(
                operationID: operationID,
                packageRoot: finalRoot,
                fcpxmlURL: finalRoot.appendingPathComponent("FCPCommandConsole-RoundTrip-Spike.fcpxml"),
                instructionsURL: finalRoot.appendingPathComponent("README.md"),
                manifestURL: finalRoot.appendingPathComponent("manifest.json"),
                evidenceLedgerURL: finalRoot.appendingPathComponent("evidence.json"),
                mediaRecords: mediaRecords
            )
        } catch {
            try? fileManager.removeItem(at: stagingRoot)
            throw error
        }
    }

    private func validateAbsolutePath(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw FCPXMLRoundTripSpikeError.nonAbsolutePath(url) }
        guard !url.pathComponents.contains("..") else { throw FCPXMLRoundTripSpikeError.pathTraversal(url) }
    }

    func validateExportRoot(_ rawRoot: URL) throws -> URL {
        try validateAbsolutePath(rawRoot)
        let standardized = rawRoot.standardizedFileURL
        let canonical = standardized.resolvingSymlinksInPath().standardizedFileURL
        try rejectForbiddenExportRoot(standardized)
        try rejectForbiddenExportRoot(canonical)
        if isSymbolicLink(standardized) {
            throw FCPXMLRoundTripSpikeError.symlinkExportRoot(standardized)
        }
        guard approvedExportRoots().contains(where: { isStrictDescendant(canonical, of: $0) }) else {
            throw FCPXMLRoundTripSpikeError.forbiddenExportRoot(canonical)
        }
        return canonical
    }

    private func rejectForbiddenExportRoot(_ root: URL) throws {
        let path = root.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let explicitlyForbidden = ["/", "/Users/marcboyer", "/Users/marcboyer/Movies", home, "\(home)/Movies"]
        guard !explicitlyForbidden.contains(path) else { throw FCPXMLRoundTripSpikeError.forbiddenExportRoot(root) }
        let components = root.pathComponents
        guard !components.contains(where: { $0.lowercased().hasSuffix(".fcpbundle") }) else {
            throw FCPXMLRoundTripSpikeError.forbiddenExportRoot(root)
        }
        guard !components.contains(where: { $0.caseInsensitiveCompare("Final Cut Pro.app") == .orderedSame }) else {
            throw FCPXMLRoundTripSpikeError.forbiddenExportRoot(root)
        }
    }

    private func outputChild(named name: String, of root: URL) throws -> URL {
        let child = root.appendingPathComponent(name, isDirectory: true).standardizedFileURL
        guard child.deletingLastPathComponent().path == root.standardizedFileURL.path else {
            throw FCPXMLRoundTripSpikeError.exportRootEscape(child)
        }
        return child
    }

    private func validateReadableFile(_ url: URL, invalidDTD: Bool = false) throws {
        guard isRegularFile(url), FileManager.default.isReadableFile(atPath: url.path) else {
            throw invalidDTD ? FCPXMLRoundTripSpikeError.invalidDTD(url) : FCPXMLRoundTripSpikeError.missingFixture(url)
        }
    }

    private func copyFixtures(to mediaRoot: URL, publishedMediaRoot: URL) throws -> [FCPXMLRoundTripSpikeMediaRecord] {
        let filenames = ["clip-a.mov", "clip-b.mov"]
        return try filenames.map { filename in
            let source = fixtureRoot.appendingPathComponent(filename)
            guard !isSymbolicLink(source) else { throw FCPXMLRoundTripSpikeError.symlinkFixture(source) }
            try validateReadableFile(source)
            let destination = mediaRoot.appendingPathComponent(filename)
            try FileManager.default.copyItem(at: source, to: destination)
            guard !isSymbolicLink(destination) else { throw FCPXMLRoundTripSpikeError.symlinkDestination(destination) }
            try validateReadableFile(destination)
            let sourceHash = try ContentHasher.sha256File(source)
            let copiedHash = try ContentHasher.sha256File(destination)
            guard sourceHash == copiedHash else { throw FCPXMLRoundTripSpikeError.copyVerificationFailed(destination) }
            let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? 0
            return FCPXMLRoundTripSpikeMediaRecord(copiedPath: publishedMediaRoot.appendingPathComponent(filename), sha256: copiedHash, byteCount: size, sourceFilename: filename)
        }
    }

    private func makePlan(operationID: UUID, generatedAt: Date) -> FCPXMLRoundTripSpikePlan {
        FCPXMLRoundTripSpikePlan(
            schemaVersion: "1.1", probeRevision: 2, operationID: operationID, generatedAt: generatedAt, frameRate: "30 fps admission probe",
            probes: [
                .init(projectName: "FCPCommandConsole Dissolve Admission Probe", purpose: "Minimal two-asset admission probe with browser clips and a bare 1-second transition.", assumptions: ["Asset admission and native transition semantics are unverified pending manual import and returned FCPXML."])
            ]
        )
    }

    private func makeEvidence(operationID: UUID, generatedAt: Date) -> FCPXMLRoundTripSpikeEvidence {
        FCPXMLRoundTripSpikeEvidence(
            schemaVersion: "1.1", probeRevision: 2, operationID: operationID, generatedAt: generatedAt, predecessorFailure: predecessorFailure(),
            checks: [
                .init(name: "DTD syntax validation", status: .pass, note: "xmllint --nonet validated this generated source against the installed FCPXML 1.13 DTD before publication."),
                .init(name: "predecessor import", status: .fail, note: "Operation A78B1B9D-60D7-4CD8-960B-FA9104C301E7 aborted during asset-clip import; incident 42DFFCF1-9E45-41DA-992F-ADB212422B07."),
                .init(name: "asset admission", status: .unknown, note: "Requires manual import into the disposable Final Cut library."),
                .init(name: "bare transition native semantics", status: .unknown, note: "Requires manual import and returned FCPXML inspection."),
                .init(name: "transition timing and handles", status: .unknown, note: "Requires manual import and returned FCPXML inspection."),
                .init(name: "returned FCPXML round trip", status: .unknown, note: "Requires a manually exported FCPXML in Returned/.")
            ]
        )
    }

    private func predecessorFailure() -> FCPXMLRoundTripSpikePredecessorFailure {
        FCPXMLRoundTripSpikePredecessorFailure(
            operationID: "A78B1B9D-60D7-4CD8-960B-FA9104C301E7",
            crashIncidentID: "42DFFCF1-9E45-41DA-992F-ADB212422B07",
            applicationVersion: "12.3",
            applicationBuild: "450152",
            occurredAt: "2026-08-03T08:24:55-04:00",
            importStage: "FFXMLImporter AssetClipImport addAssetClip:toObject:parentFormatID:",
            status: .fail
        )
    }

    func makeFCPXML(mediaRecords: [FCPXMLRoundTripSpikeMediaRecord]) throws -> String {
        var byName: [String: FCPXMLRoundTripSpikeMediaRecord] = [:]
        for record in mediaRecords {
            guard byName[record.sourceFilename] == nil else {
                throw FCPXMLRoundTripSpikeError.duplicateMediaRecord(record.sourceFilename)
            }
            byName[record.sourceFilename] = record
        }
        let clipAURL = xmlAttribute(fileURLString(try requiredMediaRecord(named: "clip-a.mov", in: byName).copiedPath))
        let clipBURL = xmlAttribute(fileURLString(try requiredMediaRecord(named: "clip-b.mov", in: byName).copiedPath))
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <fcpxml version="1.13">
          <resources>
            <format id="r1" name="FFVideoFormat1080p30"/>
            <asset id="r2" name="clip-a.mov" start="0s" duration="8s" hasVideo="1" hasAudio="1" format="r1" audioSources="1" audioChannels="2" audioRate="48000"><media-rep kind="original-media" src="\(clipAURL)"/></asset>
            <asset id="r3" name="clip-b.mov" start="0s" duration="8s" hasVideo="1" hasAudio="1" format="r1" audioSources="1" audioChannels="2" audioRate="48000"><media-rep kind="original-media" src="\(clipBURL)"/></asset>
          </resources>
          <event name="FCPCommandConsole Dissolve Admission Probe">
            <asset-clip name="clip-a.mov Browser Clip" ref="r2" format="r1" start="0s" duration="8s" audioRole="dialogue"/>
            <asset-clip name="clip-b.mov Browser Clip" ref="r3" format="r1" start="0s" duration="8s" audioRole="dialogue"/>
            <project name="FCPCommandConsole Dissolve Admission Probe"><sequence format="r1"><spine>
              <asset-clip name="clip-a.mov" ref="r2" format="r1" start="0s" duration="8s" audioRole="dialogue"/>
              <transition name="Bare 1-second transition hypothesis" duration="1s"/>
              <asset-clip name="clip-b.mov" ref="r3" format="r1" start="0s" duration="8s" audioRole="dialogue"/>
            </spine></sequence></project>
          </event>
        </fcpxml>
        """
    }

    private func requiredMediaRecord(named filename: String, in records: [String: FCPXMLRoundTripSpikeMediaRecord]) throws -> FCPXMLRoundTripSpikeMediaRecord {
        guard let record = records[filename] else { throw FCPXMLRoundTripSpikeError.missingMediaRecord(filename) }
        return record
    }

    private func fileURLString(_ url: URL) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        let path = url.standardizedFileURL.path
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return url.standardizedFileURL.absoluteString
        }
        return "file://\(encodedPath)"
    }

    private func xmlAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        var metadata = stat()
        return url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFLNK
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        var metadata = stat()
        return url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFREG
        }
    }

    private func approvedExportRoots() -> [URL] {
        let fileManager = FileManager.default
        let productExports = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/FCPCommandConsole/exports", isDirectory: true)
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let slashTemporaryDirectory = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let roots = [productExports, temporaryDirectory, slashTemporaryDirectory].map {
            $0.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
        }
        return Array(Set(roots))
    }

    private func isStrictDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path.hasSuffix("/") ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        return candidatePath.hasPrefix(rootPath)
    }

    private func validateDTD(xmlURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xmllint")
        process.arguments = ["--nonet", "--noout", "--dtdvalid", dtdURL.standardizedFileURL.absoluteString, xmlURL.standardizedFileURL.absoluteString]
        let standardError = Pipe()
        process.standardError = standardError
        try process.run()
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard !process.isRunning else {
            process.terminate()
            throw FCPXMLRoundTripSpikeError.dtdValidationTimedOut
        }
        guard process.terminationStatus == 0 else {
            let detail = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "xmllint exited \(process.terminationStatus)"
            throw FCPXMLRoundTripSpikeError.dtdValidationFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func readme(operationID: UUID) -> String {
        """
        # FCPCommandConsole Dissolve Admission Probe (Revision 2)

        Operation: \(operationID.uuidString)

        This is a syntax-validated, reduced admission probe—not an accepted Final Cut result. It did not automate Final Cut Pro, call a paid service, or upload media. Revision 1 failed during import before semantics were observed; its exact incident metadata is recorded in `provenance.json` and `evidence.json`.

        1. In Final Cut Pro, manually import `FCPCommandConsole-RoundTrip-Spike.fcpxml` into the disposable **FCPCommandConsole Test** library only. Do not import into any production library.
        2. Verify that one project and two browser clips appear without Final Cut reporting an error or crashing. Then inspect whether the bare one-second transition appears.
        3. If Final Cut reports an error or crashes, stop immediately and report it. Do not retry the prior package or alter this immutable package.
        4. If import succeeds, export the event or project as FCPXML into this package's empty `Returned/` folder. Do not replace the generated source FCPXML.
        5. Return the exported FCPXML to the primary session. Do not apply color, inspect transforms, or test opacity in this revision.
        """
    }
}
