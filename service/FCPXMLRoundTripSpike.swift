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
    public let operationID: UUID
    public let generatedAt: Date
    public let frameRate: String
    public let probes: [Probe]
}

public struct FCPXMLRoundTripSpikeProvenance: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let operationID: UUID
    public let generatedAt: Date
    public let finalCutAutomationPerformed: Bool
    public let paidCallPerformed: Bool
    public let mediaUploadPerformed: Bool
    public let manualImportExportPending: Bool
    public let semanticAcceptance: FCPXMLRoundTripEvidenceStatus
}

public struct FCPXMLRoundTripSpikeEvidence: Codable, Equatable, Sendable {
    public struct Check: Codable, Equatable, Sendable {
        public let name: String
        public let status: FCPXMLRoundTripEvidenceStatus
        public let note: String
    }

    public let schemaVersion: String
    public let operationID: UUID
    public let generatedAt: Date
    public let checks: [Check]
}

public struct FCPXMLRoundTripSpikeManifest: Codable, Equatable, Sendable {
    public let schemaVersion: String
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
                schemaVersion: "1.0",
                operationID: operationID,
                generatedAt: generatedAt,
                finalCutAutomationPerformed: false,
                paidCallPerformed: false,
                mediaUploadPerformed: false,
                manualImportExportPending: true,
                semanticAcceptance: .unknown
            )
            let evidence = makeEvidence(operationID: operationID, generatedAt: generatedAt)
            let manifest = FCPXMLRoundTripSpikeManifest(
                schemaVersion: "1.0",
                operationID: operationID,
                media: mediaRecords,
                expectedPackageEntries: ["Media/clip-a.mov", "Media/clip-b.mov", "Media/living-still.png", "FCPCommandConsole-RoundTrip-Spike.fcpxml", "plan.json", "provenance.json", "manifest.json", "evidence.json", "README.md", "Returned/"]
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
        let filenames = ["clip-a.mov", "clip-b.mov", "living-still.png"]
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
            schemaVersion: "1.0", operationID: operationID, generatedAt: generatedAt, frameRate: "30 fps (1/30s rational timing)",
            probes: [
                .init(projectName: "Probe 1 — Bare 1-Second Transition", purpose: "Two copied movie clips with a bare 1-second transition.", assumptions: ["A bare transition is a DTD-valid but unverified syntax probe.", "Final Cut's native transition interpretation is unverified pending returned FCPXML."]),
                .init(projectName: "Probe 2 — Targeted Transform Hypothesis", purpose: "Copied clip-a with explicit position, scale, and rotation keyframe attempts.", assumptions: ["Transform parameter names, keys, and units are hypotheses.", "Target metadata uses normalized-frame coordinates and is unverified pending returned FCPXML."]),
                .init(projectName: "Probe 3 — Living Still Opacity Hypothesis", purpose: "Four-second copied still with transform and opacity/fade keyframe attempts.", assumptions: ["Transform and opacity parameter names, keys, and units are hypotheses.", "Native monochrome/desaturation and modest contrast must be added manually after import; its semantic result is unverified."])
            ]
        )
    }

    private func makeEvidence(operationID: UUID, generatedAt: Date) -> FCPXMLRoundTripSpikeEvidence {
        FCPXMLRoundTripSpikeEvidence(
            schemaVersion: "1.0", operationID: operationID, generatedAt: generatedAt,
            checks: [
                .init(name: "DTD validation", status: .unknown, note: "Package generation performs this syntax check; this ledger starts unknown until reviewed."),
                .init(name: "bare transition native semantics", status: .unknown, note: "Requires manual import and returned FCPXML inspection."),
                .init(name: "targeted transform native semantics", status: .unknown, note: "Parameter names, keys, and units are hypotheses pending returned FCPXML."),
                .init(name: "living still transform and opacity native semantics", status: .unknown, note: "Parameter names, keys, and units are hypotheses pending returned FCPXML."),
                .init(name: "manual monochrome and contrast", status: .unknown, note: "Must be applied natively by the user to the designated living-still probe clip.")
            ]
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
        let stillURL = xmlAttribute(fileURLString(try requiredMediaRecord(named: "living-still.png", in: byName).copiedPath))
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <fcpxml version="1.13">
          <resources>
            <format id="r1" name="FFVideoFormat1080p30" frameDuration="1/30s" width="1920" height="1080" colorSpace="1-1-1 (Rec. 709)"/>
            <asset id="r2" name="clip-a.mov" start="0s" duration="240/30s" hasVideo="1" format="r1" hasAudio="1" audioSources="1" audioChannels="2" audioRate="48k"><media-rep kind="original-media" src="\(clipAURL)"/></asset>
            <asset id="r3" name="clip-b.mov" start="0s" duration="240/30s" hasVideo="1" format="r1" hasAudio="1" audioSources="1" audioChannels="2" audioRate="48k"><media-rep kind="original-media" src="\(clipBURL)"/></asset>
            <asset id="r4" name="living-still.png" start="0s" duration="120/30s" hasVideo="1" format="r1"><media-rep kind="original-media" src="\(stillURL)"/></asset>
          </resources>
          <event name="FCPCommandConsole Round-Trip Spike — Manual Import Only">
            <project name="Probe 1 — Bare 1-Second Transition"><sequence format="r1" duration="450/30s" tcStart="0s" tcFormat="NDF"><spine>
              <asset-clip name="clip-a.mov — transition source A" ref="r2" offset="0s" duration="240/30s" start="0s"/>
              <transition name="Bare 1-second transition hypothesis" offset="210/30s" duration="30/30s"/>
              <asset-clip name="clip-b.mov — transition source B" ref="r3" offset="210/30s" duration="240/30s" start="0s"/>
            </spine></sequence></project>
            <project name="Probe 2 — Targeted Transform Hypothesis"><sequence format="r1" duration="120/30s" tcStart="0s" tcFormat="NDF"><spine>
              <asset-clip name="clip-a.mov — normalized target 0.68, 0.34 (hypothesis)" ref="r2" offset="0s" duration="120/30s" start="0s">
                <adjust-transform position="0 0" scale="1 1" rotation="0"><param name="Position" key="position" value="0 0"><keyframeAnimation><keyframe time="0s" value="0 0" interp="linear"/><keyframe time="120/30s" value="-48 36" interp="easeIn"/></keyframeAnimation></param><param name="Scale" key="scale" value="1 1"><keyframeAnimation><keyframe time="0s" value="1 1" interp="linear"/><keyframe time="120/30s" value="1.3 1.3" interp="easeIn"/></keyframeAnimation></param><param name="Rotation" key="rotation" value="0"><keyframeAnimation><keyframe time="0s" value="0" interp="linear"/><keyframe time="120/30s" value="12" interp="easeIn"/></keyframeAnimation></param></adjust-transform>
              </asset-clip>
            </spine></sequence></project>
            <project name="Probe 3 — Living Still Opacity Hypothesis"><sequence format="r1" duration="120/30s" tcStart="0s" tcFormat="NDF"><spine>
              <asset-clip name="DESIGNATED: apply native monochrome/desaturation plus modest contrast manually" ref="r4" offset="0s" duration="120/30s" start="0s">
                <adjust-transform position="0 0" scale="1 1" rotation="0"><param name="Position" key="position" value="0 0"><keyframeAnimation><keyframe time="0s" value="0 0" interp="linear"/><keyframe time="120/30s" value="24 0" interp="easeIn"/></keyframeAnimation></param><param name="Scale" key="scale" value="1 1"><keyframeAnimation><keyframe time="0s" value="1 1" interp="linear"/><keyframe time="120/30s" value="1.08 1.08" interp="easeIn"/></keyframeAnimation></param></adjust-transform>
                <adjust-blend amount="1"><param name="Opacity" key="opacity" value="1"><keyframeAnimation><keyframe time="0s" value="1" interp="linear"/><keyframe time="108/30s" value="1" interp="linear"/><keyframe time="120/30s" value="0" interp="easeOut"/></keyframeAnimation></param></adjust-blend>
              </asset-clip>
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
        # FCPCommandConsole FCPXML Round-Trip Spike

        Operation: \(operationID.uuidString)

        This package is a syntax-validated manual probe, not an accepted Final Cut result. It did not automate Final Cut Pro, call a paid service, or upload media. All native semantic evidence begins as `unknown` in `evidence.json`.

        1. In Final Cut Pro, manually import `FCPCommandConsole-RoundTrip-Spike.fcpxml` into the disposable **FCPCommandConsole Test** library only. Do not import into any production library.
        2. Inspect the three named projects: the bare one-second transition, the targeted transform keyframe attempts, and the living-still transform/opacity attempt.
        3. In **Probe 3 — Living Still Opacity Hypothesis**, select the clip named **DESIGNATED: apply native monochrome/desaturation plus modest contrast manually**. Apply Final Cut's native monochrome or desaturation adjustment and modest contrast manually. This package deliberately does not contain an effect UID.
        4. Export the imported event or relevant projects as FCPXML into this package's empty `Returned/` folder. Do not replace the generated source FCPXML.
        5. Return the exported FCPXML to the primary session for semantic inspection. A DTD-valid source file does not prove Final Cut accepted the names, keys, units, transition, transform, opacity, or color changes as intended.
        """
    }
}
