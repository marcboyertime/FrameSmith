import Foundation
import Darwin

public enum ConnectedRenderedMovieProbeParentKind: String, Codable, CaseIterable, Sendable {
    case still
    case movie

    public var sourceFilename: String {
        switch self {
        case .still: return "living-still.png"
        case .movie: return "clip-a.mov"
        }
    }

    fileprivate var sourceKind: OldTelevisionSourceKind {
        switch self {
        case .still: return .still
        case .movie: return .movie
        }
    }

    public var projectName: String {
        "FCPCommandConsole Connected Rendered Movie Over \(rawValue.capitalized) Probe"
    }

    public var fcpxmlFilename: String {
        "FCPCommandConsole-ConnectedRenderedMovie-Over\(rawValue.capitalized)-Probe.fcpxml"
    }
}

public enum ConnectedRenderedMovieProbeError: Error, LocalizedError, Equatable {
    case nonAbsolutePath(URL)
    case pathTraversal(URL)
    case missingFixture(URL)
    case missingPackageArtifact(URL)
    case symlinkPath(URL)
    case invalidDTD(URL)
    case invalidSourceFixture(String)
    case forbiddenExportRoot(URL)
    case exportRootEscape(URL)
    case existingPackage(URL)
    case copyVerificationFailed(URL)
    case invalidPreparedMovie(String)
    case dtdValidationFailed(String)
    case dtdValidationTimedOut
    case malformedGeneratedXML
    case invalidEvidence(String)
    case returnedFileOutsidePackage(URL)
    case malformedReturnedXML(String)

    public var errorDescription: String? {
        switch self {
        case .nonAbsolutePath(let url): return "An absolute file path is required: \(url.path)"
        case .pathTraversal(let url): return "Path traversal is not allowed: \(url.path)"
        case .missingFixture(let url): return "Required probe fixture is missing or unreadable: \(url.path)"
        case .missingPackageArtifact(let url): return "Required probe package artifact is missing: \(url.path)"
        case .symlinkPath(let url): return "Probe paths must not be symbolic links: \(url.path)"
        case .invalidDTD(let url): return "The requested FCPXML DTD is missing or unreadable: \(url.path)"
        case .invalidSourceFixture(let detail): return "Probe source fixture is invalid: \(detail)"
        case .forbiddenExportRoot(let url): return "Probe output is forbidden at this path: \(url.path)"
        case .exportRootEscape(let url): return "Probe package path escaped its approved export root: \(url.path)"
        case .existingPackage(let url): return "Refusing to overwrite an existing probe package: \(url.path)"
        case .copyVerificationFailed(let url): return "Copied media hash did not match its source: \(url.path)"
        case .invalidPreparedMovie(let detail): return "Prepared connected movie is invalid: \(detail)"
        case .dtdValidationFailed(let detail): return "FCPXML DTD validation failed: \(detail)"
        case .dtdValidationTimedOut: return "FCPXML DTD validation timed out"
        case .malformedGeneratedXML: return "Generated FCPXML was not valid UTF-8"
        case .invalidEvidence(let detail): return "Probe evidence is invalid: \(detail)"
        case .returnedFileOutsidePackage(let url): return "Returned FCPXML must be inside the package Returned directory: \(url.path)"
        case .malformedReturnedXML(let detail): return "Returned FCPXML could not be parsed: \(detail)"
        }
    }
}

/// Exact media contract carried into the probe package.
///
/// Production values come only from `OldTelevisionRenderArtifact`, whose
/// adapter has already decoded every frame and rejected audio, alpha-capable
/// pixel formats, codec/profile drift, and inexact timing. The internal
/// initializer exists so focused package tests do not have to render 120
/// 1080p ProRes frames merely to exercise filesystem rails.
public struct ConnectedRenderedMoviePreparedMedia: Equatable, Sendable {
    public let url: URL
    public let sha256: String
    public let recipeDigest: String
    public let codec: String
    public let codecProfile: String
    public let codecTag: String
    public let pixelFormat: String
    public let width: Int
    public let height: Int
    public let frameRateNumerator: Int64
    public let frameRateDenominator: Int64
    public let frameCount: Int
    public let durationNumerator: Int64
    public let durationDenominator: Int64
    public let videoOnly: Bool

    init(verified artifact: OldTelevisionRenderArtifact) {
        url = artifact.url
        sha256 = artifact.sha256
        recipeDigest = artifact.recipeDigest
        codec = artifact.codec
        codecProfile = artifact.codecProfile
        codecTag = "apch"
        pixelFormat = artifact.pixelFormat
        width = artifact.width
        height = artifact.height
        frameRateNumerator = artifact.frameRate.numerator
        frameRateDenominator = artifact.frameRate.denominator
        frameCount = artifact.frameCount
        durationNumerator = artifact.duration.numerator
        durationDenominator = artifact.duration.denominator
        videoOnly = artifact.videoOnly
    }

    init(
        url: URL,
        sha256: String,
        recipeDigest: String,
        codec: String = "prores",
        codecProfile: String = "HQ",
        codecTag: String = "apch",
        pixelFormat: String = "yuv422p10le",
        width: Int = 1920,
        height: Int = 1080,
        frameRateNumerator: Int64 = 30,
        frameRateDenominator: Int64 = 1,
        frameCount: Int = 120,
        durationNumerator: Int64 = 4,
        durationDenominator: Int64 = 1,
        videoOnly: Bool = true
    ) {
        self.url = url
        self.sha256 = sha256
        self.recipeDigest = recipeDigest
        self.codec = codec
        self.codecProfile = codecProfile
        self.codecTag = codecTag
        self.pixelFormat = pixelFormat
        self.width = width
        self.height = height
        self.frameRateNumerator = frameRateNumerator
        self.frameRateDenominator = frameRateDenominator
        self.frameCount = frameCount
        self.durationNumerator = durationNumerator
        self.durationDenominator = durationDenominator
        self.videoOnly = videoOnly
    }
}

/// Generates one immutable admission probe for the semantic contract
/// `connectedRenderedMovieLayer`.
///
/// This is intentionally separate from every spent evidence builder. It emits
/// a hypothesis, not an admission: the prior connected-layer evidence used a
/// still image, while this probe references a full-duration video-only movie.
public struct ConnectedRenderedMovieProbeBuilder: Sendable {
    public static let preferredFCPXMLVersion = "1.14"
    public static let width = 1920
    public static let height = 1080
    public static let frameRate = 30
    public static let durationFrames = 120
    public static let durationSeconds = 4

    public let parentKind: ConnectedRenderedMovieProbeParentKind
    public let fixtureRoot: URL
    public let exportRoot: URL
    public let fcpxmlVersion: String
    public let dtdURL: URL
    public let renderer: OldTelevisionRenderAdapter

    public init(
        parentKind: ConnectedRenderedMovieProbeParentKind,
        fixtureRoot: URL,
        exportRoot: URL,
        fcpxmlVersion: String = ConnectedRenderedMovieProbeBuilder.preferredFCPXMLVersion,
        dtdURL: URL? = nil,
        renderer: OldTelevisionRenderAdapter = OldTelevisionRenderAdapter()
    ) {
        self.parentKind = parentKind
        self.fixtureRoot = fixtureRoot
        self.exportRoot = exportRoot
        self.fcpxmlVersion = fcpxmlVersion
        self.dtdURL = dtdURL ?? NativeFCPXMLDTD.url(forVersion: fcpxmlVersion)
        self.renderer = renderer
    }

    public struct Package: Equatable, Sendable {
        public let operationID: UUID
        public let parentKind: ConnectedRenderedMovieProbeParentKind
        public let packageRoot: URL
        public let fcpxmlURL: URL
        public let evidenceURL: URL
        public let instructionsURL: URL
        public let sourceMediaURL: URL
        public let renderedMediaURL: URL
        public let sourceSHA256: String
        public let renderedSHA256: String
    }

    public struct Evidence: Codable, Equatable, Sendable {
        public struct Media: Codable, Equatable, Sendable {
            public let filename: String
            public let sha256: String
        }

        public struct RenderedMedia: Codable, Equatable, Sendable {
            public let filename: String
            public let sha256: String
            public let recipeDigest: String
            public let codec: String
            public let codecProfile: String
            public let codecTag: String
            public let pixelFormat: String
            public let width: Int
            public let height: Int
            public let frameRateNumerator: Int64
            public let frameRateDenominator: Int64
            public let frameCount: Int
            public let durationNumerator: Int64
            public let durationDenominator: Int64
            public let videoOnly: Bool
        }

        public struct Check: Codable, Equatable, Sendable {
            public let name: String
            public let status: FCPXMLRoundTripEvidenceStatus
            public let note: String
        }

        public let schemaVersion: String
        public let probe: String
        public let operationID: UUID
        public let generatedAt: Date
        public let finalCutVersion: String
        public let finalCutBuild: String
        public let fcpxmlVersion: String
        public let parentKind: ConnectedRenderedMovieProbeParentKind
        public let projectName: String
        public let source: Media
        public let rendered: RenderedMedia
        public let sourceFCPXMLSHA256: String
        public let finalCutAutomationPerformed: Bool
        public let manualImportExportPending: Bool
        public let semanticAcceptance: FCPXMLRoundTripEvidenceStatus
        public let checks: [Check]
    }

    public func build(operationID: UUID = UUID(), generatedAt: Date = Date()) throws -> Package {
        try build(operationID: operationID, generatedAt: generatedAt, preparedMovie: nil)
    }

    /// Test seam for package and verifier tests. Production callers use
    /// `build(operationID:generatedAt:)`, which always obtains this value from
    /// the closed, verifying renderer.
    func build(
        operationID: UUID,
        generatedAt: Date,
        preparedMovie: ConnectedRenderedMoviePreparedMedia
    ) throws -> Package {
        try build(operationID: operationID, generatedAt: generatedAt, preparedMovie: Optional(preparedMovie))
    }

    private func build(
        operationID: UUID,
        generatedAt: Date,
        preparedMovie: ConnectedRenderedMoviePreparedMedia?
    ) throws -> Package {
        try validateAbsolutePath(fixtureRoot)
        let approvedExportRoot = try validateExportRoot(exportRoot)
        try ConnectedRenderedMovieDTDValidator.requireReadable(dtdURL)

        let sourceFixtureURL = fixtureRoot.appendingPathComponent(parentKind.sourceFilename)
        try requireRegularNonSymlinkFile(
            sourceFixtureURL,
            missingError: .missingFixture(sourceFixtureURL)
        )
        try ConnectedRenderedMovieSourceValidator(ffprobeURL: renderer.ffprobe).validate(
            sourceFixtureURL,
            parentKind: parentKind
        )

        let finalRoot = try outputChild(named: operationID.uuidString, of: approvedExportRoot)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: finalRoot.path) else {
            throw ConnectedRenderedMovieProbeError.existingPackage(finalRoot)
        }
        try fileManager.createDirectory(at: approvedExportRoot, withIntermediateDirectories: true)
        _ = try validateExportRoot(approvedExportRoot)

        let stagingRoot = try outputChild(
            named: ".connected-rendered-movie-staging-\(operationID.uuidString)-\(UUID().uuidString)",
            of: approvedExportRoot
        )
        do {
            try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: false)
            let mediaRoot = stagingRoot.appendingPathComponent("Media", isDirectory: true)
            let returnedRoot = stagingRoot.appendingPathComponent("Returned", isDirectory: true)
            try fileManager.createDirectory(at: mediaRoot, withIntermediateDirectories: false)
            try fileManager.createDirectory(at: returnedRoot, withIntermediateDirectories: false)

            let sourceFilename = parentKind.sourceFilename
            let sourceHash = try copyRegularFile(
                from: sourceFixtureURL,
                to: mediaRoot.appendingPathComponent(sourceFilename),
                missingError: .missingFixture(sourceFixtureURL)
            )

            let prepared: ConnectedRenderedMoviePreparedMedia
            if let preparedMovie {
                prepared = preparedMovie
            } else {
                let artifact = try renderer.render(
                    OldTelevisionRenderRequest(
                        sourceURL: mediaRoot.appendingPathComponent(sourceFilename),
                        sourceSHA256: sourceHash,
                        sourceKind: parentKind.sourceKind,
                        targetWidth: Self.width,
                        targetHeight: Self.height,
                        duration: OldTelevisionRational(Int64(Self.durationSeconds)),
                        frameRate: OldTelevisionRational(Int64(Self.frameRate))
                    ),
                    in: mediaRoot
                )
                prepared = ConnectedRenderedMoviePreparedMedia(verified: artifact)
            }
            try validatePreparedMovie(prepared)

            let renderedFilename = prepared.url.lastPathComponent
            guard !renderedFilename.isEmpty,
                  renderedFilename != sourceFilename,
                  !renderedFilename.contains("/"),
                  renderedFilename.lowercased().hasSuffix(".mov") else {
                throw ConnectedRenderedMovieProbeError.invalidPreparedMovie("filename must be a distinct .mov basename")
            }
            let stagedRenderedURL = mediaRoot.appendingPathComponent(renderedFilename)
            let renderedHash: String
            if prepared.url.standardizedFileURL == stagedRenderedURL.standardizedFileURL {
                try requireRegularNonSymlinkFile(prepared.url, missingError: .missingPackageArtifact(prepared.url))
                renderedHash = try ContentHasher.sha256File(prepared.url)
            } else {
                renderedHash = try copyRegularFile(
                    from: prepared.url,
                    to: stagedRenderedURL,
                    missingError: .missingPackageArtifact(prepared.url)
                )
            }
            guard renderedHash.lowercased() == prepared.sha256.lowercased() else {
                throw ConnectedRenderedMovieProbeError.copyVerificationFailed(stagedRenderedURL)
            }

            let publishedSource = finalRoot.appendingPathComponent("Media/\(sourceFilename)")
            let publishedRendered = finalRoot.appendingPathComponent("Media/\(renderedFilename)")
            let xml = makeFCPXML(
                sourceMediaURL: publishedSource,
                renderedMediaURL: publishedRendered,
                renderedFilename: renderedFilename
            )
            guard let xmlData = xml.data(using: .utf8) else {
                throw ConnectedRenderedMovieProbeError.malformedGeneratedXML
            }
            let fcpxmlURL = stagingRoot.appendingPathComponent(parentKind.fcpxmlFilename)
            try xmlData.write(to: fcpxmlURL, options: .atomic)
            try ConnectedRenderedMovieDTDValidator.validate(xmlURL: fcpxmlURL, dtdURL: dtdURL)
            let sourceFCPXMLHash = try ContentHasher.sha256File(fcpxmlURL)

            let evidence = makeEvidence(
                operationID: operationID,
                generatedAt: generatedAt,
                sourceFilename: sourceFilename,
                sourceHash: sourceHash,
                renderedFilename: renderedFilename,
                renderedHash: renderedHash,
                prepared: prepared,
                sourceFCPXMLHash: sourceFCPXMLHash
            )
            try writeJSON(evidence, to: stagingRoot.appendingPathComponent("evidence.json"))
            try Data(readme(operationID: operationID).utf8).write(
                to: stagingRoot.appendingPathComponent("README.md"),
                options: .atomic
            )

            guard !fileManager.fileExists(atPath: finalRoot.path) else {
                throw ConnectedRenderedMovieProbeError.existingPackage(finalRoot)
            }
            try fileManager.moveItem(at: stagingRoot, to: finalRoot)
            return Package(
                operationID: operationID,
                parentKind: parentKind,
                packageRoot: finalRoot,
                fcpxmlURL: finalRoot.appendingPathComponent(parentKind.fcpxmlFilename),
                evidenceURL: finalRoot.appendingPathComponent("evidence.json"),
                instructionsURL: finalRoot.appendingPathComponent("README.md"),
                sourceMediaURL: finalRoot.appendingPathComponent("Media/\(sourceFilename)"),
                renderedMediaURL: finalRoot.appendingPathComponent("Media/\(renderedFilename)"),
                sourceSHA256: sourceHash,
                renderedSHA256: renderedHash
            )
        } catch {
            try? fileManager.removeItem(at: stagingRoot)
            throw error
        }
    }

    // MARK: - FCPXML

    public func makeFCPXML(
        sourceMediaURL: URL,
        renderedMediaURL: URL,
        renderedFilename: String
    ) -> String {
        let rate = NativeFCPXMLFrameRate.thirty
        let duration = rate.time(frames: Self.durationFrames)
        let rendered = NativeFCPXMLMovieResources(
            formatID: "r1",
            assetID: "r3",
            name: renderedFilename,
            mediaURL: renderedMediaURL,
            sourceDuration: duration,
            hasAudio: false
        )
        let connected = NativeFCPXMLConnectedLayer(
            ref: "r3",
            lane: 1,
            offsetWithinParent: .zero,
            name: renderedFilename,
            start: .zero,
            duration: duration
        )

        let resources: [NativeFCPXMLNode]
        let spineChild: NativeFCPXMLNode
        switch parentKind {
        case .still:
            let source = NativeFCPXMLStillResources(
                sequenceFormatID: "r1",
                assetID: "r2",
                stillFormatID: "r4",
                name: sourceMediaURL.deletingPathExtension().lastPathComponent,
                mediaURL: sourceMediaURL,
                width: Self.width,
                height: Self.height,
                frameRate: rate
            )
            resources = source.resourceNodes + [rendered.assetNode]
            spineChild = source.videoNode(
                offset: .zero,
                duration: duration,
                children: [connected.node]
            )
        case .movie:
            let source = NativeFCPXMLMovieResources(
                formatID: "r1",
                assetID: "r2",
                name: sourceMediaURL.lastPathComponent,
                mediaURL: sourceMediaURL,
                sourceDuration: .seconds(8),
                hasAudio: true
            )
            resources = [source.formatNode, source.assetNode, rendered.assetNode]
            spineChild = source.assetClipNode(
                offset: .zero,
                start: .zero,
                duration: duration,
                connectedLayers: [connected]
            )
        }

        return NativeFCPXMLDocument(
            version: fcpxmlVersion,
            resources: resources,
            eventName: parentKind.projectName,
            projectName: parentKind.projectName,
            sequenceFormatID: "r1",
            sequenceDuration: duration,
            spineChildren: [spineChild]
        ).xmlString
    }

    // MARK: - Package rails

    private func validateAbsolutePath(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/") else {
            throw ConnectedRenderedMovieProbeError.nonAbsolutePath(url)
        }
        guard !url.pathComponents.contains("..") else {
            throw ConnectedRenderedMovieProbeError.pathTraversal(url)
        }
    }

    func validateExportRoot(_ rawRoot: URL) throws -> URL {
        try validateAbsolutePath(rawRoot)
        let standardized = rawRoot.standardizedFileURL
        let canonical = standardized.resolvingSymlinksInPath().standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let forbiddenExact = ["/", home, "\(home)/Movies"]
        for candidate in [standardized, canonical] {
            let path = candidate.path
            guard !forbiddenExact.contains(path),
                  !candidate.pathComponents.contains(where: { $0.lowercased().hasSuffix(".fcpbundle") }),
                  !candidate.pathComponents.contains(where: { $0.caseInsensitiveCompare("Final Cut Pro.app") == .orderedSame }),
                  !candidate.pathComponents.contains("ground-truth"),
                  !candidate.pathComponents.contains("roundtrip-spikes"),
                  !candidate.pathComponents.contains("living-still-probes"),
                  !candidate.pathComponents.contains("native-effect-probes") else {
                throw ConnectedRenderedMovieProbeError.forbiddenExportRoot(candidate)
            }
        }
        if isSymbolicLink(standardized) {
            throw ConnectedRenderedMovieProbeError.symlinkPath(standardized)
        }
        guard approvedExportRoots().contains(where: { isStrictDescendant(canonical, of: $0) }) else {
            throw ConnectedRenderedMovieProbeError.forbiddenExportRoot(canonical)
        }
        return canonical
    }

    private func approvedExportRoots() -> [URL] {
        let productExports = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/FCPCommandConsole/exports", isDirectory: true)
        return Array(Set([
            productExports,
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
            URL(fileURLWithPath: "/tmp", isDirectory: true)
        ].map { $0.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL }))
    }

    private func outputChild(named name: String, of root: URL) throws -> URL {
        let child = root.appendingPathComponent(name, isDirectory: true).standardizedFileURL
        guard child.deletingLastPathComponent().path == root.standardizedFileURL.path else {
            throw ConnectedRenderedMovieProbeError.exportRootEscape(child)
        }
        return child
    }

    private func isStrictDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path.hasSuffix("/")
            ? root.standardizedFileURL.path
            : root.standardizedFileURL.path + "/"
        return candidate.standardizedFileURL.path.hasPrefix(rootPath)
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        var metadata = stat()
        return url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFLNK
        }
    }

    private func requireRegularNonSymlinkFile(
        _ url: URL,
        missingError: ConnectedRenderedMovieProbeError
    ) throws {
        if isSymbolicLink(url) { throw ConnectedRenderedMovieProbeError.symlinkPath(url) }
        var metadata = stat()
        let regular = url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFREG
        }
        guard regular, FileManager.default.isReadableFile(atPath: url.path) else { throw missingError }
    }

    private func copyRegularFile(
        from source: URL,
        to destination: URL,
        missingError: ConnectedRenderedMovieProbeError
    ) throws -> String {
        try requireRegularNonSymlinkFile(source, missingError: missingError)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ConnectedRenderedMovieProbeError.copyVerificationFailed(destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        try requireRegularNonSymlinkFile(destination, missingError: .missingPackageArtifact(destination))
        let sourceHash = try ContentHasher.sha256File(source)
        let destinationHash = try ContentHasher.sha256File(destination)
        guard sourceHash == destinationHash else {
            throw ConnectedRenderedMovieProbeError.copyVerificationFailed(destination)
        }
        return destinationHash
    }

    private func validatePreparedMovie(_ media: ConnectedRenderedMoviePreparedMedia) throws {
        try requireRegularNonSymlinkFile(media.url, missingError: .missingPackageArtifact(media.url))
        let digest = try ContentHasher.sha256File(media.url)
        guard digest.lowercased() == media.sha256.lowercased() else {
            throw ConnectedRenderedMovieProbeError.invalidPreparedMovie("SHA-256 does not match verified artifact")
        }
        guard media.codec == "prores",
              media.codecProfile == "HQ",
              media.codecTag == "apch",
              media.pixelFormat == "yuv422p10le",
              media.width == Self.width,
              media.height == Self.height,
              media.frameRateNumerator == Int64(Self.frameRate),
              media.frameRateDenominator == 1,
              media.frameCount == Self.durationFrames,
              media.durationNumerator == Int64(Self.durationSeconds),
              media.durationDenominator == 1,
              media.videoOnly else {
            throw ConnectedRenderedMovieProbeError.invalidPreparedMovie(
                "expected one opaque video-only 1920x1080 30 fps four-second ProRes 422 HQ artifact"
            )
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func makeEvidence(
        operationID: UUID,
        generatedAt: Date,
        sourceFilename: String,
        sourceHash: String,
        renderedFilename: String,
        renderedHash: String,
        prepared: ConnectedRenderedMoviePreparedMedia,
        sourceFCPXMLHash: String
    ) -> Evidence {
        Evidence(
            schemaVersion: "1",
            probe: "connected-rendered-movie-over-\(parentKind.rawValue)-revision-1",
            operationID: operationID,
            generatedAt: generatedAt,
            finalCutVersion: "12.3",
            finalCutBuild: "450152",
            fcpxmlVersion: fcpxmlVersion,
            parentKind: parentKind,
            projectName: parentKind.projectName,
            source: .init(filename: sourceFilename, sha256: sourceHash),
            rendered: .init(
                filename: renderedFilename,
                sha256: renderedHash,
                recipeDigest: prepared.recipeDigest,
                codec: prepared.codec,
                codecProfile: prepared.codecProfile,
                codecTag: prepared.codecTag,
                pixelFormat: prepared.pixelFormat,
                width: prepared.width,
                height: prepared.height,
                frameRateNumerator: prepared.frameRateNumerator,
                frameRateDenominator: prepared.frameRateDenominator,
                frameCount: prepared.frameCount,
                durationNumerator: prepared.durationNumerator,
                durationDenominator: prepared.durationDenominator,
                videoOnly: prepared.videoOnly
            ),
            sourceFCPXMLSHA256: sourceFCPXMLHash,
            finalCutAutomationPerformed: false,
            manualImportExportPending: true,
            semanticAcceptance: .unknown,
            checks: [
                .init(name: "source media preservation", status: .pass, note: "The original fixture was copied without byte changes and remains the spine resource."),
                .init(name: "rendered media contract", status: .pass, note: "The closed renderer verified one video stream, zero audio streams, ProRes 422 HQ apch/yuv422p10le, exact 1920x1080 30 fps timing, 120 decoded frames, and four-second duration."),
                .init(name: "DTD validity", status: .pass, note: "Validated against the installed FCPXML \(fcpxmlVersion) DTD. This proves syntax only, never Final Cut semantics."),
                .init(name: "connected movie element", status: .unknown, note: "The probe deliberately asks whether a video-only movie survives as the generated <video> child. Prior evidence covered a connected still only."),
                .init(name: "parent context", status: .unknown, note: "This package covers only a \(parentKind.rawValue) spine parent. The other parent kind requires its own package."),
                .init(name: "import admission", status: .unknown, note: "Requires one import into the isolated Final Cut 12.3 (450152) copy and a returned export."),
                .init(name: "editability", status: .unknown, note: "Not part of this pass. Do not edit the imported project."),
                .init(name: "returned FCPXML round trip", status: .unknown, note: "Requires Returned/returned.fcpxmld/Info.fcpxml and the read-only verifier.")
            ]
        )
    }

    private func readme(operationID: UUID) -> String {
        """
        # Connected Rendered Movie Over \(parentKind.rawValue.capitalized) Probe

        Operation `\(operationID.uuidString)`, FCPXML \(fcpxmlVersion), scoped to Final Cut Pro 12.3 (450152).

        This immutable package asks one narrow question: does one full-duration,
        opaque, video-only ProRes 422 HQ movie survive as a lane-1 connected
        visual above an otherwise unchanged \(parentKind.rawValue) spine clip?
        The generated `<video>` child is a hypothesis. Prior admission covered a
        connected still, not a movie. DTD validity is not acceptance.

        ## Isolated pass

        1. With stock and copied Final Cut both closed, run
           `Scripts/launch-isolated-fcpcommandconsole --preflight-only`.
        2. Launch only with `Scripts/launch-isolated-fcpcommandconsole --launch`.
        3. Open the absolute path
           `/Users/marcboyer/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
        4. File ▸ Import ▸ XML…, and choose `\(parentKind.fcpxmlFilename)` from this package.
        5. Stop at the first crash, alert, missing media, missing connected layer,
           or export mismatch. Capture a screenshot for any UI refusal. Do not retry
           this package and do not edit the project.
        6. Confirm one four-second project with the rendered movie covering the
           unchanged source. For a movie parent, its original audio must remain.
        7. Select the project in the browser, File ▸ Export XML…, name it
           `returned`, and save into this package's empty `Returned/` directory.
        8. Quit Final Cut and wait for the guarded launcher to finish its postflight.
        9. Run the probe CLI's read-only `verify` command against
           `Returned/returned.fcpxmld/Info.fcpxml`.

        A passing returned comparison admits only this parent context and does not
        admit editability. Moving `connectedRenderedMovieLayer` into the semantic
        profile is a separate reviewed source edit and is not performed by this probe.
        """
    }
}

private struct ConnectedRenderedMovieSourceValidator: Sendable {
    private struct Envelope: Decodable {
        let streams: [Stream]
        let format: Format?
    }

    private struct Stream: Decodable {
        let codecType: String?
        let width: Int?
        let height: Int?
        let frameRate: String?
        let averageFrameRate: String?
        let duration: String?
        let decodedFrameCount: String?
        let declaredFrameCount: String?
        let sampleRate: String?
        let channels: Int?

        enum CodingKeys: String, CodingKey {
            case codecType = "codec_type"
            case width, height
            case frameRate = "r_frame_rate"
            case averageFrameRate = "avg_frame_rate"
            case duration
            case decodedFrameCount = "nb_read_frames"
            case declaredFrameCount = "nb_frames"
            case sampleRate = "sample_rate"
            case channels
        }
    }

    private struct Format: Decodable {
        let duration: String?
    }

    let ffprobeURL: URL

    func validate(
        _ sourceURL: URL,
        parentKind: ConnectedRenderedMovieProbeParentKind
    ) throws {
        guard FileManager.default.isExecutableFile(atPath: ffprobeURL.path) else {
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                "ffprobe is unavailable at \(ffprobeURL.path)"
            )
        }
        let envelope = try probe(sourceURL, countFrames: parentKind == .still)
        let video = envelope.streams.filter { $0.codecType == "video" }
        let audio = envelope.streams.filter { $0.codecType == "audio" }
        guard video.count == 1, let videoStream = video.first else {
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                "expected exactly one video stream, found \(video.count)"
            )
        }
        guard videoStream.width == ConnectedRenderedMovieProbeBuilder.width,
              videoStream.height == ConnectedRenderedMovieProbeBuilder.height else {
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                "expected 1920x1080 source video, found \(videoStream.width ?? -1)x\(videoStream.height ?? -1)"
            )
        }

        switch parentKind {
        case .still:
            guard audio.isEmpty, envelope.streams.count == 1 else {
                throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                    "still fixture must contain only its single video stream"
                )
            }
            guard let countText = videoStream.decodedFrameCount ?? videoStream.declaredFrameCount,
                  Int(countText) == 1 else {
                throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                    "still fixture must contain exactly one decoded frame"
                )
            }
        case .movie:
            guard audio.count == 1, envelope.streams.count == 2, let audioStream = audio.first else {
                throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                    "movie fixture must contain exactly one video and one audio stream"
                )
            }
            guard ratio(videoStream.averageFrameRate ?? videoStream.frameRate, equals: 30, over: 1) else {
                throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                    "movie fixture must be exact 30 fps"
                )
            }
            guard seconds(videoStream.duration ?? envelope.format?.duration, equalTo: 8),
                  seconds(audioStream.duration ?? envelope.format?.duration, equalTo: 8) else {
                throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                    "movie fixture video and audio must both be exactly eight seconds"
                )
            }
            guard audioStream.sampleRate == "48000", audioStream.channels == 2 else {
                throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                    "movie fixture must contain one 48 kHz stereo audio stream"
                )
            }
        }
    }

    private func probe(_ sourceURL: URL, countFrames: Bool) throws -> Envelope {
        let process = Process()
        process.executableURL = ffprobeURL
        var arguments = ["-v", "error"]
        if countFrames { arguments.append("-count_frames") }
        arguments += ["-show_streams", "-show_format", "-of", "json", sourceURL.path]
        process.arguments = arguments
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError
        do {
            try process.run()
        } catch {
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                "ffprobe could not start: \(error.localizedDescription)"
            )
        }
        let deadline = Date().addingTimeInterval(30)
        while process.isRunning, Date() < deadline { usleep(50_000) }
        guard !process.isRunning else {
            process.terminate()
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture("ffprobe timed out")
        }
        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let captured = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = captured.isEmpty ? "ffprobe exited \(process.terminationStatus)" : captured
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                detail
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: output)
        } catch {
            throw ConnectedRenderedMovieProbeError.invalidSourceFixture(
                "ffprobe returned undecodable metadata: \(error.localizedDescription)"
            )
        }
    }

    private func ratio(_ raw: String?, equals numerator: Int64, over denominator: Int64) -> Bool {
        guard let raw else { return false }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let actualNumerator = Int64(parts[0]),
              let actualDenominator = Int64(parts[1]),
              actualDenominator > 0 else {
            return false
        }
        let left = actualNumerator.multipliedReportingOverflow(by: denominator)
        let right = numerator.multipliedReportingOverflow(by: actualDenominator)
        return !left.overflow && !right.overflow && left.partialValue == right.partialValue
    }

    private func seconds(_ raw: String?, equalTo expected: Double) -> Bool {
        guard let raw, let value = Double(raw), value.isFinite else { return false }
        return abs(value - expected) <= 0.000_001
    }
}

private enum ConnectedRenderedMovieDTDValidator {
    static func requireReadable(_ dtdURL: URL) throws {
        var metadata = stat()
        let regular = dtdURL.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFREG
        }
        guard regular, FileManager.default.isReadableFile(atPath: dtdURL.path) else {
            throw ConnectedRenderedMovieProbeError.invalidDTD(dtdURL)
        }
    }

    static func validate(xmlURL: URL, dtdURL: URL) throws {
        try requireReadable(dtdURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xmllint")
        process.arguments = [
            "--nonet", "--noout", "--dtdvalid",
            dtdURL.standardizedFileURL.absoluteString,
            xmlURL.standardizedFileURL.absoluteString
        ]
        let standardError = Pipe()
        process.standardError = standardError
        try process.run()
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning, Date() < deadline { usleep(50_000) }
        guard !process.isRunning else {
            process.terminate()
            throw ConnectedRenderedMovieProbeError.dtdValidationTimedOut
        }
        guard process.terminationStatus == 0 else {
            let detail = String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "xmllint exited \(process.terminationStatus)"
            throw ConnectedRenderedMovieProbeError.dtdValidationFailed(
                detail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

// MARK: - Returned evidence verifier

public struct ConnectedRenderedMovieVerificationReport: Codable, Equatable, Sendable {
    public struct Check: Codable, Equatable, Sendable {
        public let name: String
        public let status: FCPXMLRoundTripEvidenceStatus
        public let note: String
    }

    public let schemaVersion: String
    public let operationID: UUID
    public let parentKind: ConnectedRenderedMovieProbeParentKind
    public let packageRoot: String
    public let returnedFCPXML: String
    public let returnedSHA256: String
    public let status: FCPXMLRoundTripEvidenceStatus
    public let checks: [Check]
}

/// Performs no writes. It checks the package contents against the pinned local
/// evidence contract, validates the returned document against the exact DTD,
/// and reads only the exact probe project. This is local integrity checking,
/// not an external signature over the package.
public struct ConnectedRenderedMovieRoundTripVerifier: Sendable {
    public let fcpxmlVersion: String
    public let dtdURL: URL

    public init(
        fcpxmlVersion: String = ConnectedRenderedMovieProbeBuilder.preferredFCPXMLVersion,
        dtdURL: URL? = nil
    ) {
        self.fcpxmlVersion = fcpxmlVersion
        self.dtdURL = dtdURL ?? NativeFCPXMLDTD.url(forVersion: fcpxmlVersion)
    }

    public func verify(packageRoot rawPackageRoot: URL, returnedXMLURL rawReturnedURL: URL) throws -> ConnectedRenderedMovieVerificationReport {
        let packageRoot = try canonicalDirectory(rawPackageRoot)
        let returnedRoot = try canonicalDirectory(packageRoot.appendingPathComponent("Returned", isDirectory: true))
        let returnedURL = try canonicalRegularFile(rawReturnedURL)
        guard isStrictDescendant(returnedURL, of: returnedRoot) else {
            throw ConnectedRenderedMovieProbeError.returnedFileOutsidePackage(returnedURL)
        }

        let evidenceURL = try canonicalRegularFile(packageRoot.appendingPathComponent("evidence.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let evidence: ConnectedRenderedMovieProbeBuilder.Evidence
        do {
            evidence = try decoder.decode(
                ConnectedRenderedMovieProbeBuilder.Evidence.self,
                from: Data(contentsOf: evidenceURL)
            )
        } catch {
            throw ConnectedRenderedMovieProbeError.invalidEvidence(error.localizedDescription)
        }
        try validateEvidence(evidence, packageRoot: packageRoot)

        var checks: [ConnectedRenderedMovieVerificationReport.Check] = []
        func record(_ name: String, _ passed: Bool, _ note: String) {
            checks.append(.init(name: name, status: passed ? .pass : .fail, note: note))
        }

        let sourceURL = try canonicalRegularFile(
            packageRoot.appendingPathComponent("Media/\(evidence.source.filename)")
        )
        let renderedURL = try canonicalRegularFile(
            packageRoot.appendingPathComponent("Media/\(evidence.rendered.filename)")
        )
        let sourceFCPXMLURL = try canonicalRegularFile(
            packageRoot.appendingPathComponent(evidence.parentKind.fcpxmlFilename)
        )
        let sourceHash = try ContentHasher.sha256File(sourceURL)
        let renderedHash = try ContentHasher.sha256File(renderedURL)
        let sourceFCPXMLHash = try ContentHasher.sha256File(sourceFCPXMLURL)
        record("source package media hash", sourceHash == evidence.source.sha256, "expected \(evidence.source.sha256), found \(sourceHash)")
        record("rendered package media hash", renderedHash == evidence.rendered.sha256, "expected \(evidence.rendered.sha256), found \(renderedHash)")
        record("source FCPXML hash", sourceFCPXMLHash == evidence.sourceFCPXMLSHA256, "expected \(evidence.sourceFCPXMLSHA256), found \(sourceFCPXMLHash)")

        do {
            try ConnectedRenderedMovieDTDValidator.validate(xmlURL: returnedURL, dtdURL: dtdURL)
            record("returned DTD validity", true, "Returned XML validates against \(dtdURL.lastPathComponent).")
        } catch {
            record("returned DTD validity", false, error.localizedDescription)
        }

        let document = try ParsedFCPXMLDocument.parse(url: returnedURL)
        record(
            "returned FCPXML version",
            document.root.attributes["version"] == evidence.fcpxmlVersion,
            "expected \(evidence.fcpxmlVersion), found \(document.root.attributes["version"] ?? "missing")"
        )
        let projects = document.descendants(named: "project").filter { $0.attributes["name"] == evidence.projectName }
        record("exact project", projects.count == 1, "found \(projects.count) project(s) named \(evidence.projectName)")

        if let project = projects.first, projects.count == 1 {
            verifyProject(project, evidence: evidence, document: document, record: record)
        } else {
            record("sequence geometry", false, "Cannot inspect a unique probe project.")
            record("unchanged spine", false, "Cannot inspect a unique probe project.")
            record("connected rendered movie", false, "Cannot inspect a unique probe project.")
            record("video-only resource", false, "Cannot inspect a unique probe project.")
        }

        let returnedHash = try ContentHasher.sha256File(returnedURL)
        let status: FCPXMLRoundTripEvidenceStatus = checks.allSatisfy { $0.status == .pass } ? .pass : .fail
        return ConnectedRenderedMovieVerificationReport(
            schemaVersion: "1",
            operationID: evidence.operationID,
            parentKind: evidence.parentKind,
            packageRoot: packageRoot.path,
            returnedFCPXML: returnedURL.path,
            returnedSHA256: returnedHash,
            status: status,
            checks: checks
        )
    }

    private func verifyProject(
        _ project: ParsedFCPXMLElement,
        evidence: ConnectedRenderedMovieProbeBuilder.Evidence,
        document: ParsedFCPXMLDocument,
        record: (String, Bool, String) -> Void
    ) {
        guard let sequence = project.firstDirectChild(named: "sequence"),
              let spine = sequence.firstDirectChild(named: "spine") else {
            record("sequence geometry", false, "Project has no direct sequence/spine.")
            record("unchanged spine", false, "Project has no direct sequence/spine.")
            record("connected rendered movie", false, "Project has no direct sequence/spine.")
            record("video-only resource", false, "Project has no direct sequence/spine.")
            return
        }

        let durationOK = time(sequence.attributes["duration"], equals: 4, over: 1)
            && time(sequence.attributes["tcStart"], equals: 0, over: 1, missingMeansZero: true)
            && sequence.attributes["tcFormat"] == "NDF"
            && sequence.attributes["audioLayout"] == "stereo"
            && sequence.attributes["audioRate"] == "48k"
            && (spine.attributes["lane"] == nil || spine.attributes["lane"] == "0")
            && time(spine.attributes["offset"], equals: 0, over: 1, missingMeansZero: true)
        let sequenceFormat = document.format(withID: sequence.attributes["format"])
        let formatOK = sequenceFormat?.attributes["name"] == "FFVideoFormat1080p30"
            && sequenceFormat?.attributes["width"] == "1920"
            && sequenceFormat?.attributes["height"] == "1080"
            && time(sequenceFormat?.attributes["frameDuration"], equals: 1, over: 30)
            && (sequenceFormat?.attributes["fieldOrder"] == nil
                || sequenceFormat?.attributes["fieldOrder"] == "progressive")
        let storyElements = spine.children.filter { Self.storyElementNames.contains($0.name) }
        let expectedParentName = evidence.parentKind == .still ? "video" : "asset-clip"
        let parentOK = storyElements.count == 1 && storyElements.first?.name == expectedParentName
        record(
            "sequence geometry",
            durationOK && formatOK && parentOK,
            "duration=\(sequence.attributes["duration"] ?? "missing"), format=\(sequenceFormat?.attributes ?? [:]), spine children=\(storyElements.map(\.name))"
        )
        guard let parent = storyElements.first, parentOK else {
            record("unchanged spine", false, "Expected one \(expectedParentName) parent.")
            record("connected rendered movie", false, "Expected one \(expectedParentName) parent.")
            record("video-only resource", false, "Expected one \(expectedParentName) parent.")
            return
        }

        let parentForbidden = parent.children.filter {
            $0.name.hasPrefix("adjust-") || $0.name.hasPrefix("filter-video")
        }
        let parentNonAnchorMutations = parent.children.filter {
            !Self.anchorElementNames.contains($0.name)
        }
        let parentAudioMutations = parent.children.filter {
            $0.name == "audio-channel-source"
                || $0.name == "audio-role-source"
                || $0.name == "filter-audio"
                || $0.name == "mute"
                || $0.name.hasPrefix("adjust-volume")
                || $0.name.hasPrefix("adjust-panner")
                || $0.name.hasPrefix("adjust-EQ")
        }
        let parentEnabled = parent.attributes["enabled"] == nil || parent.attributes["enabled"] == "1"
        let parentSourcesEnabled = parent.attributes["srcEnable"] == nil || parent.attributes["srcEnable"] == "all"
        let parentTiming = time(parent.attributes["offset"], equals: 0, over: 1)
            && time(parent.attributes["duration"], equals: 4, over: 1)
            && (parent.attributes["lane"] == nil || parent.attributes["lane"] == "0")
            && time(
                parent.attributes["start"],
                equals: evidence.parentKind == .still ? 3600 : 0,
                over: 1,
                missingMeansZero: evidence.parentKind == .movie
            )
        let parentResource = document.asset(withID: parent.attributes["ref"])
        let parentMediaNameOK = parentResource?.mediaFilename == evidence.source.filename
        let parentResourceTimingOK = time(parentResource?.attributes["start"], equals: 0, over: 1, missingMeansZero: true)
            && time(
                parentResource?.attributes["duration"],
                equals: evidence.parentKind == .still ? 0 : 8,
                over: 1
            )
            && parentResource?.attributes["hasVideo"] == "1"
        let movieAudioOK: Bool
        if evidence.parentKind == .movie {
            movieAudioOK = parentResource?.attributes["hasAudio"] == "1"
                && parentResource?.attributes["audioSources"] == "1"
                && parentResource?.attributes["audioChannels"] == "2"
                && parentResource?.attributes["audioRate"] == "48000"
                && parent.attributes["audioRole"] == "dialogue"
                && parent.attributes["audioStart"] == nil
                && parent.attributes["audioDuration"] == nil
        } else {
            movieAudioOK = parentResource?.attributes["hasAudio"] == nil
                || parentResource?.attributes["hasAudio"] == "0"
        }
        record(
            "unchanged spine",
            parentTiming && parentEnabled && parentSourcesEnabled
                && parentForbidden.isEmpty && parentAudioMutations.isEmpty
                && parentNonAnchorMutations.isEmpty
                && parentMediaNameOK && parentResourceTimingOK && movieAudioOK,
            "parent=\(parent.name), enabled=\(parent.attributes["enabled"] ?? "default-1"), srcEnable=\(parent.attributes["srcEnable"] ?? "default-all"), source=\(parentResource?.mediaFilename ?? "unresolved"), source-timing-preserved=\(parentResourceTimingOK), non-anchor mutations=\(parentNonAnchorMutations.map(\.name)), visual intrinsics=\(parentForbidden.map(\.name)), audio mutations=\(parentAudioMutations.map(\.name)), source-audio-preserved=\(movieAudioOK)"
        )

        let anchored = parent.children.filter { Self.anchorElementNames.contains($0.name) }
        guard anchored.count == 1, let connected = anchored.first else {
            record("connected rendered movie", false, "Expected exactly one anchored child, found \(anchored.count).")
            record("video-only resource", false, "No unique connected resource to inspect.")
            return
        }
        let connectedForbidden = connected.children
        let connectedEnabled = connected.attributes["enabled"] == nil || connected.attributes["enabled"] == "1"
        let connectedTiming = connected.attributes["lane"] == "1"
            && time(connected.attributes["offset"], equals: 0, over: 1)
            && time(connected.attributes["start"], equals: 0, over: 1, missingMeansZero: true)
            && time(connected.attributes["duration"], equals: 4, over: 1)
        let connectedResource = document.asset(withID: connected.attributes["ref"])
        let connectedMediaNameOK = connectedResource?.mediaFilename == evidence.rendered.filename
        record(
            "connected rendered movie",
            connected.name == "video" && connectedEnabled && connectedTiming
                && connectedForbidden.isEmpty && connectedMediaNameOK,
            "element=\(connected.name), enabled=\(connected.attributes["enabled"] ?? "default-1"), lane=\(connected.attributes["lane"] ?? "missing"), offset=\(connected.attributes["offset"] ?? "missing"), start=\(connected.attributes["start"] ?? "inherited"), duration=\(connected.attributes["duration"] ?? "missing"), visual children=\(connectedForbidden.map(\.name))"
        )

        let noAudioAttributes = connectedResource.map { asset in
            let hasAudio = asset.attributes["hasAudio"]
            return (hasAudio == nil || hasAudio == "0")
                && asset.attributes["audioSources"] == nil
                && asset.attributes["audioChannels"] == nil
                && asset.attributes["audioRate"] == nil
        } ?? false
        let resourceTiming = time(connectedResource?.attributes["start"], equals: 0, over: 1, missingMeansZero: true)
            && time(connectedResource?.attributes["duration"], equals: 4, over: 1)
        record(
            "video-only resource",
            connectedResource?.attributes["hasVideo"] == "1" && noAudioAttributes && resourceTiming,
            "asset hasVideo=\(connectedResource?.attributes["hasVideo"] ?? "missing"), hasAudio=\(connectedResource?.attributes["hasAudio"] ?? "omitted"), audioSources=\(connectedResource?.attributes["audioSources"] ?? "omitted"), duration=\(connectedResource?.attributes["duration"] ?? "missing")"
        )
    }

    private static let storyElementNames: Set<String> = [
        "audio", "video", "clip", "title", "mc-clip", "ref-clip", "sync-clip",
        "asset-clip", "audition", "gap", "live-drawing", "transition"
    ]

    private static let anchorElementNames: Set<String> = [
        "audio", "video", "clip", "title", "caption", "mc-clip", "ref-clip",
        "sync-clip", "asset-clip", "audition", "spine", "live-drawing"
    ]

    private func validateEvidence(
        _ evidence: ConnectedRenderedMovieProbeBuilder.Evidence,
        packageRoot: URL
    ) throws {
        let expectedProbe = "connected-rendered-movie-over-\(evidence.parentKind.rawValue)-revision-1"
        let renderedFilename = evidence.rendered.filename
        let renderedContract = evidence.rendered.codec == "prores"
            && evidence.rendered.codecProfile == "HQ"
            && evidence.rendered.codecTag == "apch"
            && evidence.rendered.pixelFormat == "yuv422p10le"
            && evidence.rendered.width == ConnectedRenderedMovieProbeBuilder.width
            && evidence.rendered.height == ConnectedRenderedMovieProbeBuilder.height
            && evidence.rendered.frameRateNumerator == 30
            && evidence.rendered.frameRateDenominator == 1
            && evidence.rendered.frameCount == ConnectedRenderedMovieProbeBuilder.durationFrames
            && evidence.rendered.durationNumerator == 4
            && evidence.rendered.durationDenominator == 1
            && evidence.rendered.videoOnly
        let expectedUnknownChecks: Set<String> = [
            "connected movie element", "parent context", "import admission",
            "editability", "returned FCPXML round trip"
        ]
        let unknownChecks = Set(
            evidence.checks
                .filter { $0.status == .unknown }
                .map(\.name)
        )

        guard evidence.schemaVersion == "1",
              evidence.probe == expectedProbe,
              evidence.fcpxmlVersion == fcpxmlVersion,
              evidence.finalCutVersion == "12.3",
              evidence.finalCutBuild == "450152",
              evidence.projectName == evidence.parentKind.projectName,
              evidence.source.filename == evidence.parentKind.sourceFilename,
              renderedFilename != evidence.source.filename,
              renderedFilename == URL(fileURLWithPath: renderedFilename).lastPathComponent,
              renderedFilename.lowercased().hasSuffix(".mov"),
              !renderedFilename.isEmpty,
              evidence.finalCutAutomationPerformed == false,
              evidence.manualImportExportPending,
              evidence.semanticAcceptance == .unknown,
              expectedUnknownChecks.isSubset(of: unknownChecks),
              renderedContract,
              isSHA256(evidence.source.sha256),
              isSHA256(evidence.rendered.sha256),
              isSHA256(evidence.rendered.recipeDigest),
              isSHA256(evidence.sourceFCPXMLSHA256),
              packageRoot.lastPathComponent == evidence.operationID.uuidString else {
            throw ConnectedRenderedMovieProbeError.invalidEvidence(
                "pinned package identity, media contract, or pre-admission fields drifted"
            )
        }
    }

    private func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }

    private func canonicalDirectory(_ url: URL) throws -> URL {
        try requireAbsolute(url)
        let standardized = url.standardizedFileURL
        guard !isSymbolicLink(standardized) else { throw ConnectedRenderedMovieProbeError.symlinkPath(standardized) }
        let canonical = standardized.resolvingSymlinksInPath().standardizedFileURL
        guard canonical == standardized, isDirectory(canonical) else {
            throw ConnectedRenderedMovieProbeError.missingPackageArtifact(standardized)
        }
        return canonical
    }

    private func canonicalRegularFile(_ url: URL) throws -> URL {
        try requireAbsolute(url)
        let standardized = url.standardizedFileURL
        guard !isSymbolicLink(standardized) else { throw ConnectedRenderedMovieProbeError.symlinkPath(standardized) }
        let canonical = standardized.resolvingSymlinksInPath().standardizedFileURL
        guard canonical == standardized, isRegularFile(canonical) else {
            throw ConnectedRenderedMovieProbeError.missingPackageArtifact(standardized)
        }
        return canonical
    }

    private func requireAbsolute(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/") else {
            throw ConnectedRenderedMovieProbeError.nonAbsolutePath(url)
        }
        guard !url.pathComponents.contains("..") else {
            throw ConnectedRenderedMovieProbeError.pathTraversal(url)
        }
    }

    private func isStrictDescendant(_ candidate: URL, of root: URL) -> Bool {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(prefix)
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        var metadata = stat()
        return url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFLNK
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var metadata = stat()
        return url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFDIR
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        var metadata = stat()
        return url.path.withCString { path in
            lstat(path, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFREG
        }
    }

    private func time(
        _ raw: String?,
        equals numerator: Int64,
        over denominator: Int64,
        missingMeansZero: Bool = false
    ) -> Bool {
        guard let raw else { return missingMeansZero && numerator == 0 }
        guard raw.hasSuffix("s") else { return false }
        let body = raw.dropLast()
        let parts = body.split(separator: "/", omittingEmptySubsequences: false)
        let actualNumerator: Int64
        let actualDenominator: Int64
        if parts.count == 1, let value = Int64(parts[0]) {
            actualNumerator = value
            actualDenominator = 1
        } else if parts.count == 2,
                  let value = Int64(parts[0]),
                  let scale = Int64(parts[1]),
                  scale > 0 {
            actualNumerator = value
            actualDenominator = scale
        } else {
            return false
        }
        let left = actualNumerator.multipliedReportingOverflow(by: denominator)
        let right = numerator.multipliedReportingOverflow(by: actualDenominator)
        return !left.overflow && !right.overflow && left.partialValue == right.partialValue
    }
}

private final class ParsedFCPXMLElement {
    let name: String
    let attributes: [String: String]
    weak var parent: ParsedFCPXMLElement?
    var children: [ParsedFCPXMLElement] = []

    init(name: String, attributes: [String: String], parent: ParsedFCPXMLElement?) {
        self.name = name
        self.attributes = attributes
        self.parent = parent
    }

    func firstDirectChild(named name: String) -> ParsedFCPXMLElement? {
        children.first { $0.name == name }
    }
}

private final class ParsedFCPXMLDelegate: NSObject, XMLParserDelegate {
    var root: ParsedFCPXMLElement?
    var stack: [ParsedFCPXMLElement] = []
    var parseError: Error?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = ParsedFCPXMLElement(name: elementName, attributes: attributeDict, parent: stack.last)
        if let parent = stack.last { parent.children.append(element) } else { root = element }
        stack.append(element)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if !stack.isEmpty { stack.removeLast() }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

private struct ParsedFCPXMLDocument {
    let root: ParsedFCPXMLElement

    static func parse(url: URL) throws -> ParsedFCPXMLDocument {
        guard let parser = XMLParser(contentsOf: url) else {
            throw ConnectedRenderedMovieProbeError.malformedReturnedXML("XMLParser could not open the file")
        }
        let delegate = ParsedFCPXMLDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), delegate.parseError == nil, let root = delegate.root, root.name == "fcpxml" else {
            throw ConnectedRenderedMovieProbeError.malformedReturnedXML(
                delegate.parseError?.localizedDescription ?? parser.parserError?.localizedDescription ?? "missing fcpxml root"
            )
        }
        return ParsedFCPXMLDocument(root: root)
    }

    func descendants(named name: String) -> [ParsedFCPXMLElement] {
        var matches: [ParsedFCPXMLElement] = []
        var pending = [root]
        while let element = pending.popLast() {
            if element.name == name { matches.append(element) }
            pending.append(contentsOf: element.children.reversed())
        }
        return matches
    }

    func asset(withID id: String?) -> ParsedFCPXMLElement? {
        guard let id else { return nil }
        return descendants(named: "asset").first { $0.attributes["id"] == id }
    }

    func format(withID id: String?) -> ParsedFCPXMLElement? {
        guard let id else { return nil }
        return descendants(named: "format").first { $0.attributes["id"] == id }
    }
}

private extension ParsedFCPXMLElement {
    var mediaFilename: String? {
        guard let mediaRep = firstDirectChild(named: "media-rep"),
              let raw = mediaRep.attributes["src"],
              let url = URL(string: raw) else {
            return attributes["name"]
        }
        return url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
    }
}
