import Foundation

public enum LivingStillProbeError: Error, LocalizedError, Equatable {
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

    public var errorDescription: String? {
        switch self {
        case .nonAbsolutePath(let url): return "An absolute file path is required: \(url.path)"
        case .pathTraversal(let url): return "Path traversal is not allowed: \(url.path)"
        case .missingFixture(let url): return "Required disposable fixture is missing or not a regular readable file: \(url.path)"
        case .symlinkFixture(let url): return "Fixture media must be a regular file, not a symlink: \(url.path)"
        case .symlinkDestination(let url): return "Copied package media must be a regular file, not a symlink: \(url.path)"
        case .invalidDTD(let url): return "The requested FCPXML DTD is missing or not readable: \(url.path)"
        case .forbiddenExportRoot(let url): return "Probe output is forbidden at this path: \(url.path)"
        case .symlinkExportRoot(let url): return "Probe output cannot use a symlink path: \(url.path)"
        case .exportRootEscape(let url): return "Probe package path escaped its approved export root: \(url.path)"
        case .existingPackage(let url): return "Refusing to overwrite an existing probe package: \(url.path)"
        case .copyVerificationFailed(let url): return "Copied media hash did not match its fixture: \(url.path)"
        case .dtdValidationFailed(let detail): return "FCPXML DTD validation failed: \(detail)"
        case .dtdValidationTimedOut: return "FCPXML DTD validation timed out"
        case .malformedGeneratedXML: return "Generated FCPXML was not valid UTF-8"
        }
    }
}

/// The timeline the first living still probe describes.
///
/// Every value is either the composition model's default or, where that
/// default is not representable on a frame boundary, the nearest value that
/// is. The one substitution is the fade: the registry's `0.35 s` is 10.5
/// frames at 30 fps, so Final Cut would snap it and a snapped keyframe cannot
/// be told apart from a rejected one. 12 frames is inside the registry's
/// 0.05–2.0 range.
public enum LivingStillProbeTimeline {
    public static let rate = NativeFCPXMLFrameRate.thirty
    public static let width = 1920
    public static let height = 1080
    public static let durationFrames = 120          // 4 s
    public static let fadeFrames = 12               // 0.4 s, not the registry's 10.5
    public static let panXFraction = 0.02
    public static let panYFraction = 0.0
    public static let scaleStart = 1.0
    public static let scaleEnd = 1.08

    /// Frames are 0…119; the last addressable frame is not frame 120.
    public static var lastFrame: Int { durationFrames - 1 }
    public static var fadeStartFrame: Int { durationFrames - fadeFrames }
    public static var duration: NativeFCPXMLTime { rate.time(frames: durationFrames) }

    /// The `Saturation` value is carried over from the capture unchanged.
    ///
    /// The composition's `colorEnrichment` default is 0.12 on a 0–0.5 scale and
    /// this param ran 0–100 in the inspector, but nothing observed connects
    /// them. Mapping one to the other would put an unverified number into the
    /// first probe, whose job is to reproduce the observed construction.
    public static let saturation = 25.0
}

/// Builds the living still admission probe package.
///
/// Structurally parallel to `FCPXMLRoundTripSpikeBuilder` and deliberately not
/// factored together with it. That builder produces the four spent dissolve
/// probes, and those packages are evidence; a shared helper would mean a change
/// made for the living still could alter what a dissolve regeneration emits.
/// The duplication is the cheaper of the two risks.
public struct LivingStillProbeBuilder: Sendable {
    public static let preferredFCPXMLVersion = "1.14"

    public let fixtureRoot: URL
    public let exportRoot: URL
    public let fcpxmlVersion: String
    public let dtdURL: URL

    public init(fixtureRoot: URL, exportRoot: URL, fcpxmlVersion: String = LivingStillProbeBuilder.preferredFCPXMLVersion, dtdURL: URL? = nil) {
        self.fixtureRoot = fixtureRoot
        self.exportRoot = exportRoot
        self.fcpxmlVersion = fcpxmlVersion
        self.dtdURL = dtdURL ?? NativeFCPXMLDTD.url(forVersion: fcpxmlVersion)
    }

    public struct Package: Equatable, Sendable {
        public let operationID: UUID
        public let packageRoot: URL
        public let fcpxmlURL: URL
        public let instructionsURL: URL
        public let evidenceURL: URL
        public let mediaSHA256: String
        public let fcpxmlVersion: String
    }

    public func build(operationID: UUID = UUID(), generatedAt: Date = Date()) throws -> Package {
        try validateAbsolutePath(fixtureRoot)
        let approvedExportRoot = try validateExportRoot(exportRoot)
        guard isRegularFile(dtdURL), FileManager.default.isReadableFile(atPath: dtdURL.path) else {
            throw LivingStillProbeError.invalidDTD(dtdURL)
        }

        let finalRoot = try outputChild(named: operationID.uuidString, of: approvedExportRoot)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: finalRoot.path) else { throw LivingStillProbeError.existingPackage(finalRoot) }
        try fileManager.createDirectory(at: approvedExportRoot, withIntermediateDirectories: true)
        _ = try validateExportRoot(approvedExportRoot)

        let stagingRoot = try outputChild(named: ".living-still-staging-\(operationID.uuidString)-\(UUID().uuidString)", of: approvedExportRoot)
        do {
            try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: false)
            let mediaRoot = stagingRoot.appendingPathComponent("Media", isDirectory: true)
            try fileManager.createDirectory(at: mediaRoot, withIntermediateDirectories: false)
            try fileManager.createDirectory(at: stagingRoot.appendingPathComponent("Returned", isDirectory: true), withIntermediateDirectories: false)

            let publishedMediaURL = finalRoot.appendingPathComponent("Media/living-still.png")
            let mediaHash = try copyFixture(named: "living-still.png", to: mediaRoot)

            let xml = makeFCPXML(mediaURL: publishedMediaURL)
            guard let xmlData = xml.data(using: .utf8) else { throw LivingStillProbeError.malformedGeneratedXML }
            let fcpxmlURL = stagingRoot.appendingPathComponent("FCPCommandConsole-LivingStill-Probe.fcpxml")
            try xmlData.write(to: fcpxmlURL, options: .atomic)
            try validateDTD(xmlURL: fcpxmlURL)

            try writeJSON(makeEvidence(operationID: operationID, generatedAt: generatedAt, mediaHash: mediaHash), to: stagingRoot.appendingPathComponent("evidence.json"))
            try Data(readme(operationID: operationID).utf8).write(to: stagingRoot.appendingPathComponent("README.md"), options: .atomic)

            guard !fileManager.fileExists(atPath: finalRoot.path) else { throw LivingStillProbeError.existingPackage(finalRoot) }
            try fileManager.moveItem(at: stagingRoot, to: finalRoot)
            return Package(
                operationID: operationID,
                packageRoot: finalRoot,
                fcpxmlURL: finalRoot.appendingPathComponent("FCPCommandConsole-LivingStill-Probe.fcpxml"),
                instructionsURL: finalRoot.appendingPathComponent("README.md"),
                evidenceURL: finalRoot.appendingPathComponent("evidence.json"),
                mediaSHA256: mediaHash,
                fcpxmlVersion: fcpxmlVersion
            )
        } catch {
            try? fileManager.removeItem(at: stagingRoot)
            throw error
        }
    }

    // MARK: - Emission

    public func makeFCPXML(mediaURL: URL) -> String {
        let timeline = LivingStillProbeTimeline.self
        let resources = NativeFCPXMLStillResources(
            sequenceFormatID: "r1",
            assetID: "r2",
            stillFormatID: "r3",
            name: "living-still",
            mediaURL: mediaURL,
            width: timeline.width,
            height: timeline.height,
            frameRate: timeline.rate
        )

        let transform = NativeFCPXMLTransformChannel.pushInAndPan(
            startFrame: 0,
            endFrame: timeline.lastFrame,
            rate: timeline.rate,
            panXFraction: timeline.panXFraction,
            panYFraction: timeline.panYFraction,
            scaleStart: timeline.scaleStart,
            scaleEnd: timeline.scaleEnd,
            width: timeline.width,
            height: timeline.height
        )
        let opacity = NativeFCPXMLOpacityChannel.fade(
            fadeStartFrame: timeline.fadeStartFrame,
            endFrame: timeline.lastFrame,
            rate: timeline.rate
        )
        let colorFilter = NativeFCPXMLColorAdjustments.filterNode(ref: "r4", saturation: timeline.saturation)

        // %intrinsic-params-video; then %video_filter_item;.
        var videoChildren: [NativeFCPXMLNode] = []
        if let node = transform.node { videoChildren.append(node) }
        if let node = opacity.node { videoChildren.append(node) }
        videoChildren.append(colorFilter)

        let video = resources.videoNode(offset: .zero, duration: timeline.duration, children: videoChildren)
        let document = NativeFCPXMLDocument(
            version: fcpxmlVersion,
            resources: resources.resourceNodes + [NativeFCPXMLColorAdjustments.effectNode(id: "r4")],
            eventName: "FCPCommandConsole Living Still Admission Probe",
            projectName: "FCPCommandConsole Living Still Admission Probe",
            sequenceFormatID: "r1",
            sequenceDuration: timeline.duration,
            spineChildren: [video]
        )
        return document.xmlString
    }

    // MARK: - Rails

    private func validateAbsolutePath(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw LivingStillProbeError.nonAbsolutePath(url) }
        guard !url.pathComponents.contains("..") else { throw LivingStillProbeError.pathTraversal(url) }
    }

    func validateExportRoot(_ rawRoot: URL) throws -> URL {
        try validateAbsolutePath(rawRoot)
        let standardized = rawRoot.standardizedFileURL
        let canonical = standardized.resolvingSymlinksInPath().standardizedFileURL
        try rejectForbiddenExportRoot(standardized)
        try rejectForbiddenExportRoot(canonical)
        if isSymbolicLink(standardized) { throw LivingStillProbeError.symlinkExportRoot(standardized) }
        guard approvedExportRoots().contains(where: { isStrictDescendant(canonical, of: $0) }) else {
            throw LivingStillProbeError.forbiddenExportRoot(canonical)
        }
        return canonical
    }

    private func rejectForbiddenExportRoot(_ root: URL) throws {
        let path = root.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let explicitlyForbidden = ["/", home, "\(home)/Movies"]
        guard !explicitlyForbidden.contains(path) else { throw LivingStillProbeError.forbiddenExportRoot(root) }
        let components = root.pathComponents
        guard !components.contains(where: { $0.lowercased().hasSuffix(".fcpbundle") }) else {
            throw LivingStillProbeError.forbiddenExportRoot(root)
        }
        guard !components.contains(where: { $0.caseInsensitiveCompare("Final Cut Pro.app") == .orderedSame }) else {
            throw LivingStillProbeError.forbiddenExportRoot(root)
        }
        // The captured ground truth is immutable evidence; nothing may be
        // written beneath it.
        guard !components.contains("ground-truth") else {
            throw LivingStillProbeError.forbiddenExportRoot(root)
        }
    }

    private func outputChild(named name: String, of root: URL) throws -> URL {
        let child = root.appendingPathComponent(name, isDirectory: true).standardizedFileURL
        guard child.deletingLastPathComponent().path == root.standardizedFileURL.path else {
            throw LivingStillProbeError.exportRootEscape(child)
        }
        return child
    }

    private func copyFixture(named filename: String, to mediaRoot: URL) throws -> String {
        let source = fixtureRoot.appendingPathComponent(filename)
        guard !isSymbolicLink(source) else { throw LivingStillProbeError.symlinkFixture(source) }
        guard isRegularFile(source), FileManager.default.isReadableFile(atPath: source.path) else {
            throw LivingStillProbeError.missingFixture(source)
        }
        let destination = mediaRoot.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: source, to: destination)
        guard !isSymbolicLink(destination) else { throw LivingStillProbeError.symlinkDestination(destination) }
        let sourceHash = try ContentHasher.sha256File(source)
        let copiedHash = try ContentHasher.sha256File(destination)
        guard sourceHash == copiedHash else { throw LivingStillProbeError.copyVerificationFailed(destination) }
        return copiedHash
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
        let roots = [productExports, URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true), URL(fileURLWithPath: "/tmp", isDirectory: true)]
            .map { $0.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL }
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
        while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        guard !process.isRunning else {
            process.terminate()
            throw LivingStillProbeError.dtdValidationTimedOut
        }
        guard process.terminationStatus == 0 else {
            let detail = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "xmllint exited \(process.terminationStatus)"
            throw LivingStillProbeError.dtdValidationFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    // MARK: - Ledger

    public struct Evidence: Codable, Equatable, Sendable {
        public struct Check: Codable, Equatable, Sendable {
            public let name: String
            public let status: FCPXMLRoundTripEvidenceStatus
            public let note: String
        }
        public let schemaVersion: String
        public let probe: String
        public let operationID: UUID
        public let generatedAt: Date
        public let fcpxmlVersion: String
        public let mediaSHA256: String
        public let groundTruthSource: String
        public let finalCutAutomationPerformed: Bool
        public let paidCallPerformed: Bool
        public let mediaUploadPerformed: Bool
        public let manualImportExportPending: Bool
        public let semanticAcceptance: FCPXMLRoundTripEvidenceStatus
        public let checks: [Check]
    }

    private func makeEvidence(operationID: UUID, generatedAt: Date, mediaHash: String) -> Evidence {
        Evidence(
            schemaVersion: "1.0",
            probe: "living-still-admission-revision-1",
            operationID: operationID,
            generatedAt: generatedAt,
            fcpxmlVersion: fcpxmlVersion,
            mediaSHA256: mediaHash,
            groundTruthSource: "exports/ground-truth/living-still-ground-truth.fcpxmld captured 2026-08-04",
            finalCutAutomationPerformed: false,
            paidCallPerformed: false,
            mediaUploadPerformed: false,
            manualImportExportPending: true,
            semanticAcceptance: .unknown,
            checks: [
                .init(name: "DTD syntax validation", status: .pass, note: "xmllint --nonet validated this generated source against the installed FCPXML \(fcpxmlVersion) DTD before publication. DTD validity is not Final Cut acceptance: dissolve revisions 1 and 3 were both valid and both were rewritten."),
                .init(name: "ground truth encoding", status: .pass, note: "position nested X/Y sub-params, scale paired-value param, adjust-blend amount on a 0-1 scale, keyframe times absolute from a 3600s source start in a 720000 timescale, and the Color Adjustments uid all come from Final Cut's own export rather than inference."),
                .init(name: "still asset admission", status: .unknown, note: "No still image has ever been imported from a generated file. A still uses <video>, not the <asset-clip> path that crashed dissolve revision 1, so this is untested rather than inherited."),
                .init(name: "transform keyframe admission", status: .unknown, note: "Requires manual import and returned FCPXML inspection. position must return as nested X/Y sub-params with X reaching 3.55556, and scale as a paired value reaching 1.08 1.08."),
                .init(name: "opacity keyframe admission", status: .unknown, note: "Requires the returned file. adjust-blend amount must hold 1 at frame 108 and reach 0 at frame 119."),
                .init(name: "color adjustments admission", status: .unknown, note: "Requires the returned file. The effect must come back with uid FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0, no enabled=\"0\", and Saturation 25. Whether the three opaque payloads are required or merely tolerated is not settled by this probe, which carries them."),
                .init(name: "returned FCPXML round trip", status: .unknown, note: "Requires a manually exported FCPXML in Returned/.")
            ]
        )
    }

    private func readme(operationID: UUID) -> String {
        """
        # FCPCommandConsole Living Still Admission Probe (Revision 1)

        Operation: \(operationID.uuidString)

        This is a syntax-validated probe, not an accepted Final Cut result. It did not automate Final Cut Pro, call a paid service, or upload media.

        Unlike the dissolve probes, this construction was not arrived at by trial. Every structure in it was read out of Final Cut's own export, captured on 2026-08-04 and analysed in `docs/LIVING_STILL_GROUND_TRUTH.md`. Three details in particular would each have produced a file that imports cleanly and behaves wrongly:

        - `position` splits into nested `X`/`Y` sub-params while `scale` uses one param with paired values;
        - `position` is percent of frame height, so the 2% pan is `3.55556`, not the inspector's `38.4` px;
        - keyframe times are absolute from a `3600s` source start, in a 720000 timescale.

        FCPXML version \(fcpxmlVersion), matching the version this Final Cut build exported.

        1. Launch Final Cut only through `Scripts/launch-isolated-fcpcommandconsole --launch`. Never the stock app.
        2. Import `FCPCommandConsole-LivingStill-Probe.fcpxml` into the disposable **FCPCommandConsole Test** library only.
        3. Confirm one project appears with a single four-second still and no error or crash.
        4. If Final Cut reports an error or crashes, stop immediately and report it. Do not retry or alter this immutable package.
        5. Export the project as FCPXML into this package's empty `Returned/` folder. Do not replace the generated source FCPXML.
        6. Return the exported FCPXML to the primary session.

        Do not edit the clip in this pass. Editability is a separate question from admission and needs its own probe.
        """
    }
}
