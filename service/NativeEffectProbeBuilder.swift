import Foundation

public enum NativeEffectProbeError: Error, LocalizedError, Equatable {
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
    case invalidRecipe(String)

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
        case .invalidRecipe(let detail): return "Could not build the targeted transform recipe: \(detail)"
        }
    }
}

/// Which of the two remaining Phase 1 effects a package probes.
public enum NativeEffectProbeKind: String, CaseIterable, Sendable {
    case targetedRotateZoom = "targeted-rotate-zoom"
    case oldTelevision = "old-television"

    public var effectID: EffectID {
        switch self {
        case .targetedRotateZoom: return .targetedRotateZoom
        case .oldTelevision: return .oldTelevision
        }
    }

    public var eventName: String {
        switch self {
        case .targetedRotateZoom: return "FCPCommandConsole Targeted Rotate Zoom Probe"
        case .oldTelevision: return "FCPCommandConsole Old Television Probe"
        }
    }

    public var fcpxmlFilename: String {
        switch self {
        case .targetedRotateZoom: return "FCPCommandConsole-TargetedRotateZoom-Probe.fcpxml"
        case .oldTelevision: return "FCPCommandConsole-OldTelevision-Probe.fcpxml"
        }
    }

    /// Fixtures the package copies. The spine movie is always first.
    public var fixtures: [String] {
        switch self {
        case .targetedRotateZoom: return ["clip-a.mov"]
        case .oldTelevision: return ["clip-a.mov", "living-still.png"]
        }
    }
}

/// The timeline both probes describe.
public enum NativeEffectProbeTimeline {
    public static let rate = NativeFCPXMLFrameRate.thirty
    public static let width = 1920
    public static let height = 1080
    public static let durationFrames = 120                  // 4 s
    public static let sourceDurationFrames = 240            // clip-a.mov is 8 s

    public static var duration: NativeFCPXMLTime { rate.time(frames: durationFrames) }
    public static var sourceDuration: NativeFCPXMLTime { rate.time(frames: sourceDurationFrames) }
    public static var lastFrame: Int { durationFrames - 1 }

    // Targeted rotate/zoom: a point off-centre so a sign error in either axis
    // is visible, and a rotation small enough to stay legible.
    public static let targetPoint = Point2D(x: 0.7, y: 0.35)
    public static let scaleStart = 1.0
    public static let scaleEnd = 1.5
    public static let rotationStartDegrees = 0.0
    public static let rotationEndDegrees = 12.0

    // Old television: flicker on the base image, a connected overlay above it.
    public static let flickerFloor = 0.82
    public static let overlayOpacity = 0.5
    public static let overlayStartFrame = 30                // 1 s into the parent
    public static let overlayDurationFrames = 60            // 2 s
    /// Carried over unchanged from the capture, exactly as the living still
    /// probe does: no observed mapping connects a composition's desaturation
    /// to this param's 0–100 range, and inventing one would put an unverified
    /// number into a probe whose job is to reproduce observed constructions.
    public static let saturation = 25.0
}

/// Builds the targeted rotate/zoom and old television admission probes.
///
/// Deliberately **not** factored together with `FCPXMLRoundTripSpikeBuilder` or
/// `LivingStillProbeBuilder`, for the reason recorded on the latter: those
/// builders regenerate packages that are spent evidence, and a shared helper
/// would let a change made here alter what one of them emits. These two probes
/// share rails with each other because they are generated together and neither
/// is evidence yet.
public struct NativeEffectProbeBuilder: Sendable {
    public static let preferredFCPXMLVersion = "1.14"

    public let kind: NativeEffectProbeKind
    public let fixtureRoot: URL
    public let exportRoot: URL
    public let fcpxmlVersion: String
    public let dtdURL: URL

    public init(
        kind: NativeEffectProbeKind,
        fixtureRoot: URL,
        exportRoot: URL,
        fcpxmlVersion: String = NativeEffectProbeBuilder.preferredFCPXMLVersion,
        dtdURL: URL? = nil
    ) {
        self.kind = kind
        self.fixtureRoot = fixtureRoot
        self.exportRoot = exportRoot
        self.fcpxmlVersion = fcpxmlVersion
        self.dtdURL = dtdURL ?? NativeFCPXMLDTD.url(forVersion: fcpxmlVersion)
    }

    public struct Package: Equatable, Sendable {
        public let kind: NativeEffectProbeKind
        public let operationID: UUID
        public let packageRoot: URL
        public let fcpxmlURL: URL
        public let instructionsURL: URL
        public let evidenceURL: URL
        public let mediaSHA256: [String: String]
        public let fcpxmlVersion: String
    }

    public func build(operationID: UUID = UUID(), generatedAt: Date = Date()) throws -> Package {
        try validateAbsolutePath(fixtureRoot)
        let approvedExportRoot = try validateExportRoot(exportRoot)
        guard isRegularFile(dtdURL), FileManager.default.isReadableFile(atPath: dtdURL.path) else {
            throw NativeEffectProbeError.invalidDTD(dtdURL)
        }

        let finalRoot = try outputChild(named: operationID.uuidString, of: approvedExportRoot)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: finalRoot.path) else { throw NativeEffectProbeError.existingPackage(finalRoot) }
        try fileManager.createDirectory(at: approvedExportRoot, withIntermediateDirectories: true)
        _ = try validateExportRoot(approvedExportRoot)

        let stagingRoot = try outputChild(named: ".native-effect-staging-\(operationID.uuidString)-\(UUID().uuidString)", of: approvedExportRoot)
        do {
            try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: false)
            let mediaRoot = stagingRoot.appendingPathComponent("Media", isDirectory: true)
            try fileManager.createDirectory(at: mediaRoot, withIntermediateDirectories: false)
            try fileManager.createDirectory(at: stagingRoot.appendingPathComponent("Returned", isDirectory: true), withIntermediateDirectories: false)

            var hashes: [String: String] = [:]
            for fixture in kind.fixtures {
                hashes[fixture] = try copyFixture(named: fixture, to: mediaRoot)
            }

            let publishedMedia = Dictionary(uniqueKeysWithValues: kind.fixtures.map {
                ($0, finalRoot.appendingPathComponent("Media/\($0)"))
            })
            let xml = try makeFCPXML(media: publishedMedia)
            guard let xmlData = xml.data(using: .utf8) else { throw NativeEffectProbeError.malformedGeneratedXML }
            let fcpxmlURL = stagingRoot.appendingPathComponent(kind.fcpxmlFilename)
            try xmlData.write(to: fcpxmlURL, options: .atomic)
            try validateDTD(xmlURL: fcpxmlURL)

            try writeJSON(makeEvidence(operationID: operationID, generatedAt: generatedAt, mediaHashes: hashes), to: stagingRoot.appendingPathComponent("evidence.json"))
            try Data(readme(operationID: operationID).utf8).write(to: stagingRoot.appendingPathComponent("README.md"), options: .atomic)

            guard !fileManager.fileExists(atPath: finalRoot.path) else { throw NativeEffectProbeError.existingPackage(finalRoot) }
            try fileManager.moveItem(at: stagingRoot, to: finalRoot)
            return Package(
                kind: kind,
                operationID: operationID,
                packageRoot: finalRoot,
                fcpxmlURL: finalRoot.appendingPathComponent(kind.fcpxmlFilename),
                instructionsURL: finalRoot.appendingPathComponent("README.md"),
                evidenceURL: finalRoot.appendingPathComponent("evidence.json"),
                mediaSHA256: hashes,
                fcpxmlVersion: fcpxmlVersion
            )
        } catch {
            try? fileManager.removeItem(at: stagingRoot)
            throw error
        }
    }

    // MARK: - Emission

    public func makeFCPXML(media: [String: URL]) throws -> String {
        switch kind {
        case .targetedRotateZoom: return try makeTargetedRotateZoomXML(media: media)
        case .oldTelevision: return makeOldTelevisionXML(media: media)
        }
    }

    /// Rotation, scale, and a compensating position track.
    ///
    /// Targeting is done by position compensation rather than by moving the
    /// anchor, because animated position is observed and an animated anchor is
    /// not. See `docs/ROTATION_GROUND_TRUTH.md`.
    private func makeTargetedRotateZoomXML(media: [String: URL]) throws -> String {
        let timeline = NativeEffectProbeTimeline.self
        let clip = NativeFCPXMLMovieResources(
            formatID: "r1",
            assetID: "r2",
            name: "clip-a.mov",
            mediaURL: media["clip-a.mov"]!,
            sourceDuration: timeline.sourceDuration
        )

        let recipe: TargetedTransformKeyframeRecipe
        do {
            recipe = try TargetedTransformKeyframeRecipe(
                source: timeline.targetPoint,
                durationSeconds: Double(timeline.durationFrames) / Double(timeline.rate.framesPerSecond),
                scaleStart: timeline.scaleStart,
                scaleEnd: timeline.scaleEnd,
                rotationStartDegrees: timeline.rotationStartDegrees,
                rotationEndDegrees: timeline.rotationEndDegrees
            )
        } catch {
            throw NativeEffectProbeError.invalidRecipe(String(describing: error))
        }

        let transform = NativeFCPXMLTransformChannel.targetedRotateZoom(
            recipe: recipe,
            rate: timeline.rate,
            origin: .movieFromZero,
            width: timeline.width,
            height: timeline.height,
            clipDurationFrames: timeline.durationFrames
        )

        var intrinsics: [NativeFCPXMLNode] = []
        if let node = transform.node { intrinsics.append(node) }

        let spineClip = clip.assetClipNode(offset: .zero, duration: timeline.duration, intrinsics: intrinsics)
        let document = NativeFCPXMLDocument(
            version: fcpxmlVersion,
            resources: [clip.formatNode, clip.assetNode],
            eventName: kind.eventName,
            projectName: kind.eventName,
            sequenceFormatID: "r1",
            sequenceDuration: timeline.duration,
            spineChildren: [spineClip]
        )
        return document.xmlString
    }

    /// A flickering, desaturated base image with a connected overlay above it.
    ///
    /// Every sub-construction here except the connected layer is one Final Cut
    /// has already returned intact: animated `adjust-blend` and the Color
    /// Adjustments filter both come from the living still pass. That is
    /// deliberate — the connected layer is the only unobserved thing in the
    /// document, so a failure has one candidate cause.
    private func makeOldTelevisionXML(media: [String: URL]) -> String {
        let timeline = NativeEffectProbeTimeline.self
        let clip = NativeFCPXMLMovieResources(
            formatID: "r1",
            assetID: "r2",
            name: "clip-a.mov",
            mediaURL: media["clip-a.mov"]!,
            sourceDuration: timeline.sourceDuration
        )
        let overlay = NativeFCPXMLStillResources(
            sequenceFormatID: "r1",
            assetID: "r3",
            stillFormatID: "r4",
            name: "living-still",
            mediaURL: media["living-still.png"]!,
            width: timeline.width,
            height: timeline.height,
            frameRate: timeline.rate
        )

        // Flicker on the base: animated amount, the observed param form.
        let flicker = NativeFCPXMLOpacityChannel(amount: [
            NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 0, rate: timeline.rate), value: NativeFCPXMLNumber.string(1)),
            NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 15, rate: timeline.rate), value: NativeFCPXMLNumber.string(timeline.flickerFloor)),
            NativeFCPXMLKeyframe(time: NativeFCPXMLTimingOrigin.movieFromZero.keyframeTime(frame: 30, rate: timeline.rate), value: NativeFCPXMLNumber.string(1))
        ])
        let colorFilter = NativeFCPXMLColorAdjustments.filterNode(ref: "r5", saturation: timeline.saturation)

        // The overlay: static amount and mode, the observed attribute form.
        let connected = NativeFCPXMLConnectedLayer(
            ref: "r3",
            lane: 1,
            offsetWithinParent: timeline.rate.time(frames: timeline.overlayStartFrame),
            name: "living-still",
            start: NativeFCPXMLStillTiming.sourceStart,
            duration: timeline.rate.time(frames: timeline.overlayDurationFrames),
            blend: .composite(opacity: timeline.overlayOpacity, mode: .overlay)
        )

        // Order is fixed by the DTD: intrinsics, then connected clips, then
        // filters. `assetClipNode` enforces it.
        var intrinsics: [NativeFCPXMLNode] = []
        if let node = flicker.node { intrinsics.append(node) }

        let spineClip = clip.assetClipNode(
            offset: .zero,
            duration: timeline.duration,
            intrinsics: intrinsics,
            connectedLayers: [connected],
            filters: [colorFilter]
        )
        let document = NativeFCPXMLDocument(
            version: fcpxmlVersion,
            resources: [clip.formatNode, clip.assetNode, overlay.assetNode, overlay.stillFormatNode, NativeFCPXMLColorAdjustments.effectNode(id: "r5")],
            eventName: kind.eventName,
            projectName: kind.eventName,
            sequenceFormatID: "r1",
            sequenceDuration: timeline.duration,
            spineChildren: [spineClip]
        )
        return document.xmlString
    }

    // MARK: - Rails

    private func validateAbsolutePath(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw NativeEffectProbeError.nonAbsolutePath(url) }
        guard !url.pathComponents.contains("..") else { throw NativeEffectProbeError.pathTraversal(url) }
    }

    func validateExportRoot(_ rawRoot: URL) throws -> URL {
        try validateAbsolutePath(rawRoot)
        let standardized = rawRoot.standardizedFileURL
        let canonical = standardized.resolvingSymlinksInPath().standardizedFileURL
        try rejectForbiddenExportRoot(standardized)
        try rejectForbiddenExportRoot(canonical)
        if isSymbolicLink(standardized) { throw NativeEffectProbeError.symlinkExportRoot(standardized) }
        guard approvedExportRoots().contains(where: { isStrictDescendant(canonical, of: $0) }) else {
            throw NativeEffectProbeError.forbiddenExportRoot(canonical)
        }
        return canonical
    }

    private func rejectForbiddenExportRoot(_ root: URL) throws {
        let path = root.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let explicitlyForbidden = ["/", home, "\(home)/Movies"]
        guard !explicitlyForbidden.contains(path) else { throw NativeEffectProbeError.forbiddenExportRoot(root) }
        let components = root.pathComponents
        guard !components.contains(where: { $0.lowercased().hasSuffix(".fcpbundle") }) else {
            throw NativeEffectProbeError.forbiddenExportRoot(root)
        }
        guard !components.contains(where: { $0.caseInsensitiveCompare("Final Cut Pro.app") == .orderedSame }) else {
            throw NativeEffectProbeError.forbiddenExportRoot(root)
        }
        // Captured ground truth is immutable evidence; nothing may be written
        // beneath it. Spent probe packages likewise.
        guard !components.contains("ground-truth") else {
            throw NativeEffectProbeError.forbiddenExportRoot(root)
        }
        guard !components.contains("roundtrip-spikes"), !components.contains("living-still-probes") else {
            throw NativeEffectProbeError.forbiddenExportRoot(root)
        }
    }

    private func outputChild(named name: String, of root: URL) throws -> URL {
        let child = root.appendingPathComponent(name, isDirectory: true).standardizedFileURL
        guard child.deletingLastPathComponent().path == root.standardizedFileURL.path else {
            throw NativeEffectProbeError.exportRootEscape(child)
        }
        return child
    }

    private func copyFixture(named filename: String, to mediaRoot: URL) throws -> String {
        let source = fixtureRoot.appendingPathComponent(filename)
        guard !isSymbolicLink(source) else { throw NativeEffectProbeError.symlinkFixture(source) }
        guard isRegularFile(source), FileManager.default.isReadableFile(atPath: source.path) else {
            throw NativeEffectProbeError.missingFixture(source)
        }
        let destination = mediaRoot.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: source, to: destination)
        guard !isSymbolicLink(destination) else { throw NativeEffectProbeError.symlinkDestination(destination) }
        let sourceHash = try ContentHasher.sha256File(source)
        let copiedHash = try ContentHasher.sha256File(destination)
        guard sourceHash == copiedHash else { throw NativeEffectProbeError.copyVerificationFailed(destination) }
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
            throw NativeEffectProbeError.dtdValidationTimedOut
        }
        guard process.terminationStatus == 0 else {
            let detail = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "xmllint exited \(process.terminationStatus)"
            throw NativeEffectProbeError.dtdValidationFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
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
        public let effectID: String
        public let operationID: UUID
        public let generatedAt: Date
        public let fcpxmlVersion: String
        public let mediaSHA256: [String: String]
        public let requiredContracts: [String]
        public let purpose: String
        public let checks: [Check]
    }

    private func makeEvidence(operationID: UUID, generatedAt: Date, mediaHashes: [String: String]) -> Evidence {
        Evidence(
            schemaVersion: "1",
            probe: kind.rawValue,
            effectID: kind.effectID.rawValue,
            operationID: operationID,
            generatedAt: generatedAt,
            fcpxmlVersion: fcpxmlVersion,
            mediaSHA256: mediaHashes,
            requiredContracts: ManualFCPXMLSemanticsEvidence.requiredContracts(for: kind.effectID).map(\.rawValue).sorted(),
            purpose: purpose,
            checks: checks
        )
    }

    private var purpose: String {
        switch kind {
        case .targetedRotateZoom:
            return "Asks whether a generated rotation, scale, and compensating position track is admitted. Rotation was captured 2026-08-05 and has never been emitted before. Targeting uses position compensation rather than an animated anchor, because the former is observed and the latter is not."
        case .oldTelevision:
            return "Asks whether a generated connected overlay layer is admitted. Every other construction in this document — animated adjust-blend, the Color Adjustments filter, the movie asset and asset-clip — has already returned intact from an earlier pass, so the connected layer is the only unobserved element and a failure has one candidate cause."
        }
    }

    private var checks: [Evidence.Check] {
        var shared: [Evidence.Check] = [
            .init(name: "DTD validity", status: .pass, note: "Validated against the installed \(fcpxmlVersion) DTD. This is syntax only — dissolve revisions 1 and 3 were both valid and both were rewritten."),
            .init(name: "fixture hashes", status: .pass, note: "Each copied fixture was hashed before and after the copy through one open descriptor."),
            .init(name: "import admission", status: .unknown, note: "Requires a manual import into the disposable library."),
            .init(name: "editability", status: .unknown, note: "A separate question with its own pass; import fidelity has never implied it in this project.")
        ]
        switch kind {
        case .targetedRotateZoom:
            shared.append(.init(name: "rotation encoding", status: .pass, note: "Single param, scalar value, no key attribute, plain degrees — reproduced from docs/ROTATION_GROUND_TRUTH.md."))
            shared.append(.init(name: "movie keyframe origin", status: .pass, note: "Keyframes start at 0s, not the stills' 3600s origin. Captured 2026-08-05; emitting the still origin here would place every keyframe an hour early."))
            shared.append(.init(name: "position Y sign", status: .pass, note: "Final Cut's +Y is up and normalized image coordinates are +Y down, so the emitted Y is negated. Measured from viewer screenshots, not assumed."))
        case .oldTelevision:
            shared.append(.init(name: "connected layer shape", status: .pass, note: "Child of the spine asset-clip with lane=1, reproduced from docs/CONNECTED_LAYERS_GROUND_TRUTH.md."))
            shared.append(.init(name: "parent-relative offset", status: .pass, note: "The overlay offset is measured from the parent clip's start. Timeline-relative would be valid FCPXML that silently misplaces the overlay."))
            shared.append(.init(name: "blend mode encoding", status: .pass, note: "mode=\"14 (Overlay)\" — the only blend mode any capture has observed."))
            shared.append(.init(name: "mode alongside animated amount", status: .unknown, note: "Not exercised. The overlay uses the observed static form (amount and mode as attributes); whether a mode attribute may coexist with an animated amount param is unobserved and deliberately avoided here."))
        }
        return shared
    }

    private func readme(operationID: UUID) -> String {
        """
        # \(kind.eventName)

        Operation `\(operationID.uuidString)`, FCPXML \(fcpxmlVersion).

        \(purpose)

        ## Import

        1. `pgrep -lf "Final Cut"` prints nothing.
        2. `Scripts/launch-isolated-fcpcommandconsole --launch`
        3. Open `/Users/marcboyer/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
        4. File ▸ Import ▸ XML…, choose `\(kind.fcpxmlFilename)` from this package.
        5. If Final Cut crashes or errors, **stop** and record the message.
        6. Do not edit anything — editability is a separate pass.
        7. Select the project in the browser, File ▸ Export XML…, name it
           `returned`, and save into this package's `Returned/` directory.

        ## What a pass admits

        Admission of this generated construction, and nothing more. It does not
        admit editability, it does not admit the composition's own numbers, and
        it does not move a capability gate on its own — see
        `service/FinalCutSemanticProfile.swift`.

        **DTD validity is not acceptance.** Dissolve revisions 1 and 3 were both
        valid; one crashed Final Cut and the other was silently re-flowed.
        """
    }
}
