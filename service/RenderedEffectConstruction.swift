import Foundation

/// Deterministic, aspect-preserving geometry for a prepared treatment movie.
///
/// Rendered overlays never exceed the registered long-edge ceiling and never
/// upscale a smaller admitted source. Both dimensions are rounded down to an
/// even value so ProRes 4:2:2 chroma sampling remains well-defined.
public struct RenderedOutputGeometry: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(source: LocalMediaDimensions, maximumLongEdge: Int) throws {
        guard source.width > 0, source.height > 0, maximumLongEdge >= 2 else {
            throw StandaloneExportError.invalidRecipe("rendered treatment dimensions are invalid")
        }
        let sourceLongEdge = max(source.width, source.height)
        let scale = min(1, Double(maximumLongEdge) / Double(sourceLongEdge))
        func even(_ value: Int) -> Int { max(2, value - (value % 2)) }
        width = even(Int((Double(source.width) * scale).rounded(.down)))
        height = even(Int((Double(source.height) * scale).rounded(.down)))
    }
}

/// A machine-checkable rendered-movie encoding identity.
///
/// The connected rendered-movie admission is profile- and fourCC-specific, so
/// codec identity must not be reconstructed from a free-form provenance note
/// at export time.
public enum RenderedMovieVideoFormat: Equatable, Sendable {
    case proRes422HQ10Bit
    case proRes422Standard10Bit
    case unsupported(codec: String, codecProfile: String, codecFourCC: String, pixelFormat: String)

    public var codec: String {
        switch self {
        case .proRes422HQ10Bit, .proRes422Standard10Bit: return "prores"
        case .unsupported(let codec, _, _, _): return codec
        }
    }

    public var codecProfile: String {
        switch self {
        case .proRes422HQ10Bit: return "HQ"
        case .proRes422Standard10Bit: return "Standard"
        case .unsupported(_, let profile, _, _): return profile
        }
    }

    public var codecFourCC: String {
        switch self {
        case .proRes422HQ10Bit: return "apch"
        case .proRes422Standard10Bit: return "apcn"
        case .unsupported(_, _, let fourCC, _): return fourCC
        }
    }

    public var pixelFormat: String {
        switch self {
        case .proRes422HQ10Bit, .proRes422Standard10Bit: return "yuv422p10le"
        case .unsupported(_, _, _, let pixelFormat): return pixelFormat
        }
    }

    /// Compatibility for the already-verified Old Television adapter. This is
    /// internal so a package client cannot turn descriptive strings into an
    /// admitted asset. New renderers use the typed initializer below.
    static func verifiedInternalFormat(
        codec: String,
        pixelFormat: String,
        provenance: [String: String]
    ) -> Self {
        let profile = provenance["codecProfile"] ?? ""
        let fourCC = provenance["codecFourCC"] ?? ""
        if codec == "prores", profile == "HQ", pixelFormat == "yuv422p10le",
           fourCC.isEmpty || fourCC == "apch" {
            return .proRes422HQ10Bit
        }
        if (codec == "prores" || codec == "Apple ProRes 422"),
           profile == "Standard", pixelFormat == "yuv422p10le",
           fourCC.isEmpty || fourCC == "apcn" {
            return .proRes422Standard10Bit
        }
        return .unsupported(
            codec: codec,
            codecProfile: profile,
            codecFourCC: fourCC,
            pixelFormat: pixelFormat
        )
    }
}

/// A sealed, video-only treatment movie prepared from admitted source media.
///
/// The app previews this exact file and standalone export copies this exact
/// file.  `emitPreparedDocument` is not allowed to render another version.
/// That checksum hand-off is the rendered equivalent of native effects sharing
/// one `NativeFCPXMLEffectChannels` value between preview and export.
public struct RenderedEffectAsset: Equatable, Sendable {
    public let url: URL
    public let sha256: String
    public let constructionDigest: String
    public let rendererRecipeDigest: String
    public let sourceSHA256: String
    public let width: Int
    public let height: Int
    public let fps: Int
    public let frameCount: Int
    public let durationSeconds: Double
    public let videoFormat: RenderedMovieVideoFormat
    public let videoOnly: Bool
    public let provenance: [String: String]

    public var codec: String { videoFormat.codec }
    public var codecProfile: String { videoFormat.codecProfile }
    public var codecFourCC: String { videoFormat.codecFourCC }
    public var pixelFormat: String { videoFormat.pixelFormat }

    init(
        url: URL,
        sha256: String,
        constructionDigest: String,
        rendererRecipeDigest: String,
        sourceSHA256: String,
        width: Int,
        height: Int,
        fps: Int,
        frameCount: Int,
        durationSeconds: Double,
        videoFormat: RenderedMovieVideoFormat,
        videoOnly: Bool,
        provenance: [String: String] = [:]
    ) {
        self.url = url
        self.sha256 = sha256
        self.constructionDigest = constructionDigest
        self.rendererRecipeDigest = rendererRecipeDigest
        self.sourceSHA256 = sourceSHA256
        self.width = width
        self.height = height
        self.fps = fps
        self.frameCount = frameCount
        self.durationSeconds = durationSeconds
        self.videoFormat = videoFormat
        self.videoOnly = videoOnly
        self.provenance = provenance
    }

    /// Internal compatibility seam for the verified Old Television adapter.
    /// Keeping this non-public closes the previous arbitrary asset-fabrication
    /// API while that adapter moves to the typed initializer independently.
    init(
        url: URL,
        sha256: String,
        constructionDigest: String,
        rendererRecipeDigest: String,
        sourceSHA256: String,
        width: Int,
        height: Int,
        fps: Int,
        frameCount: Int,
        durationSeconds: Double,
        codec: String,
        pixelFormat: String,
        videoOnly: Bool,
        provenance: [String: String] = [:]
    ) {
        self.init(
            url: url,
            sha256: sha256,
            constructionDigest: constructionDigest,
            rendererRecipeDigest: rendererRecipeDigest,
            sourceSHA256: sourceSHA256,
            width: width,
            height: height,
            fps: fps,
            frameCount: frameCount,
            durationSeconds: durationSeconds,
            videoFormat: .verifiedInternalFormat(
                codec: codec,
                pixelFormat: pixelFormat,
                provenance: provenance
            ),
            videoOnly: videoOnly,
            provenance: provenance
        )
    }

    public func validate(plan: EffectPlan, media: [LocalMediaRole: LocalMediaAsset]) throws {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment movie is missing")
        }
        guard videoOnly else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment movie unexpectedly contains audio")
        }
        guard let primary = media[.primary], primary.sha256 == sourceSHA256 else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment source digest drifted")
        }
        let expectedConstruction = try RenderedConstructionIdentity.digest(plan: plan, media: media)
        guard expectedConstruction == constructionDigest else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment recipe or source identity drifted")
        }
        let observed = try ContentHasher.sha256File(url)
        guard observed == sha256 else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment movie digest drifted")
        }
        guard width > 0, height > 0, width.isMultiple(of: 2), height.isMultiple(of: 2),
              fps > 0, frameCount > 0, durationSeconds.isFinite, durationSeconds > 0 else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment media metadata is invalid")
        }
        let expectedFrames = Int((durationSeconds * Double(fps)).rounded())
        guard expectedFrames == frameCount else {
            throw StandaloneExportError.admittedArtifactMismatch("prepared treatment frame count and duration disagree")
        }
    }
}

/// The exact empirical envelope of `connectedRenderedMovieLayer`.
///
/// Registry ranges describe renderer capability, not Final Cut admission. The
/// final standalone builder calls both validators below and refuses to export
/// any tuple that was not present in the recorded Final Cut 12.3 pass.
enum ConnectedRenderedMovieAdmissionScope {
    static let finalCut = FinalCutVersionIdentity(shortVersion: "12.3", build: "450152")
    static let fcpxmlVersion = "1.14"
    static let width = 1_920
    static let height = 1_080
    static let fps = 30
    static let frameCount = 120
    static let durationSeconds = 4.0
    static let admittedMovieDurationSeconds = 8.0
    static let admittedMovieFrameCount = 240

    static func validateContext(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        installedFinalCut: FinalCutVersionIdentity?,
        fcpxmlVersion: String
    ) throws {
        guard installedFinalCut == finalCut else {
            throw StandaloneExportError.capabilityRefused(
                "connected rendered-movie export is admitted only for Final Cut \(finalCut.description)"
            )
        }
        guard fcpxmlVersion == Self.fcpxmlVersion else {
            throw StandaloneExportError.capabilityRefused(
                "connected rendered-movie export is admitted only for FCPXML \(Self.fcpxmlVersion)"
            )
        }
        guard Set(media.keys) == [.primary], let primary = media[.primary] else {
            throw StandaloneExportError.capabilityRefused(
                "connected rendered-movie export requires exactly one primary parent"
            )
        }
        guard plan.parameters["durationSeconds"]?.numberValue == durationSeconds,
              plan.parameters["fps"]?.numberValue == Double(fps),
              plan.parameters["outputLongEdge"]?.numberValue == Double(width),
              plan.parameters["preserveOriginal"] == .boolean(true) else {
            throw StandaloneExportError.capabilityRefused(
                "connected rendered-movie export is admitted only at 4.000s, 30 fps, and a 1920-pixel long edge"
            )
        }
        guard plan.generatedAssets.count == 1,
              plan.generatedAssets[0].format == "prores-422-10bit",
              plan.generatedAssets[0].alpha == false else {
            throw StandaloneExportError.capabilityRefused(
                "connected rendered-movie export requires one opaque ProRes 422 10-bit generated movie"
            )
        }
        guard primary.dimensions == LocalMediaDimensions(width: width, height: height) else {
            throw StandaloneExportError.capabilityRefused(
                "connected rendered-movie parent must be exactly 1920x1080"
            )
        }

        switch plan.effectID {
        case .livingStill:
            guard admittedStill(primary) else {
                throw StandaloneExportError.capabilityRefused(
                    "Living Still admission requires an unrotated, timing-free, audio-free 1920x1080 still parent"
                )
            }
        case .oldTelevision:
            guard admittedStill(primary) || admittedMovie(primary) else {
                throw StandaloneExportError.capabilityRefused(
                    "Old Television admission requires either the recorded unrotated timing-free audio-free still parent or the identity-transform progressive 8.000s/30-CFR movie parent with the exact observed single untagged two-channel 48 kHz audio stream"
                )
            }
        default:
            throw StandaloneExportError.capabilityRefused(
                "this rendered parent/effect shape has no connected rendered-movie admission"
            )
        }
    }

    private static func admittedStill(_ asset: LocalMediaAsset) -> Bool {
        asset.kind == .still
            && asset.durationSeconds == nil
            && asset.frameRate == nil
            && asset.hasAudio == false
            && asset.stillOrientation == .up
            && asset.moviePreferredTransform == nil
            && asset.videoTrackCount == nil
            && asset.videoScanMode == nil
            && asset.videoCadence == nil
            && asset.audioStreams == nil
    }

    private static func admittedMovie(_ asset: LocalMediaAsset) -> Bool {
        guard asset.kind == .movie,
              asset.durationSeconds == admittedMovieDurationSeconds,
              asset.frameRate == Double(fps),
              asset.hasAudio,
              asset.stillOrientation == nil,
              asset.moviePreferredTransform == .identity,
              asset.videoTrackCount == 1,
              asset.videoScanMode == .progressive,
              let cadence = asset.videoCadence,
              cadence.classification == .constant,
              cadence.decodedFrameCount == admittedMovieFrameCount,
              exactThirtyFPS(cadence.minimumFrameDurationSeconds),
              exactThirtyFPS(cadence.maximumFrameDurationSeconds),
              asset.audioStreams == [.observedUntaggedTwoChannel48k] else {
            return false
        }
        return true
    }

    private static func exactThirtyFPS(_ frameDuration: Double?) -> Bool {
        guard let frameDuration, frameDuration.isFinite else { return false }
        return abs(frameDuration - (1.0 / Double(fps))) <= 1e-9
    }

    static func validatePreparedAsset(_ asset: RenderedEffectAsset) throws {
        guard asset.videoOnly else {
            throw StandaloneExportError.admittedArtifactMismatch(
                "connected rendered-movie admission is video-only"
            )
        }
        guard asset.videoFormat == .proRes422HQ10Bit else {
            throw StandaloneExportError.admittedArtifactMismatch(
                "connected rendered-movie admission requires ProRes 422 HQ (prores/HQ/apch/yuv422p10le)"
            )
        }
        guard asset.width == width, asset.height == height else {
            throw StandaloneExportError.admittedArtifactMismatch(
                "connected rendered-movie admission requires exactly 1920x1080 output"
            )
        }
        guard asset.fps == fps else {
            throw StandaloneExportError.admittedArtifactMismatch(
                "connected rendered-movie admission requires exactly 30 fps output"
            )
        }
        guard asset.frameCount == frameCount else {
            throw StandaloneExportError.admittedArtifactMismatch(
                "connected rendered-movie admission requires exactly 120 output frames"
            )
        }
        guard asset.durationSeconds == durationSeconds else {
            throw StandaloneExportError.admittedArtifactMismatch(
                "connected rendered-movie admission requires exactly 4.000s output"
            )
        }
    }
}

/// Read-only product-facing evaluation of the exact connected rendered-movie
/// evidence envelope. It exposes no way to fabricate a prepared asset; callers
/// can only ask whether an asset already produced by Core is exportable.
public enum ConnectedRenderedMovieExportAdmission {
    public static func decision(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        preparedAsset: RenderedEffectAsset,
        installedFinalCut: FinalCutVersionIdentity?,
        fcpxmlVersion: String = StandaloneFCPXMLExportBuilder.preferredFCPXMLVersion
    ) -> CapabilityDecision {
        do {
            try ConnectedRenderedMovieAdmissionScope.validateContext(
                plan: plan,
                media: media,
                installedFinalCut: installedFinalCut,
                fcpxmlVersion: fcpxmlVersion
            )
            try ConnectedRenderedMovieAdmissionScope.validatePreparedAsset(preparedAsset)
            try preparedAsset.validate(plan: plan, media: media)
            return CapabilityDecision(
                capability: .standaloneFCPXMLExport,
                allowed: true,
                reason: "The prepared rendered movie is inside the exact Final Cut 12.3 connected-layer admission scope"
            )
        } catch {
            return CapabilityDecision(
                capability: .standaloneFCPXMLExport,
                allowed: false,
                reason: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }
}

/// Pixel-affecting identity only.  Operation IDs and wording are deliberately
/// excluded: selecting an already-admitted treatment mints a fresh operation
/// ID, but must reuse the same pixels when the source and recipe did not move.
public enum RenderedConstructionIdentity {
    private struct Body: Codable {
        let schemaVersion: String
        let effectID: EffectID
        let representation: RepresentationClass
        let parameters: [String: ParameterValue]
        let generatedAssets: [GeneratedAssetDefinition]
        let previewStrategy: String
        let fallback: String
        let sources: [Source]
    }

    private struct Source: Codable {
        let role: String
        let canonicalPath: String
        let sha256: String
        let context: LocalMediaContextFacts
    }

    public static func digest(plan: EffectPlan, media: [LocalMediaRole: LocalMediaAsset]) throws -> String {
        let sources = LocalMediaRole.structuralRoles.compactMap { role -> Source? in
            guard let asset = media[role] else { return nil }
            return Source(
                role: role.rawValue,
                canonicalPath: asset.canonicalPath,
                sha256: asset.sha256,
                context: asset.contextFacts
            )
        }
        let body = Body(
            schemaVersion: plan.schemaVersion,
            effectID: plan.effectID,
            representation: plan.representation,
            parameters: plan.parameters,
            generatedAssets: plan.generatedAssets,
            previewStrategy: plan.previewStrategy,
            fallback: plan.fallback,
            sources: sources
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return ContentHasher.sha256(try encoder.encode(body))
    }
}

/// Additional protocol for effects whose visible treatment is a rendered
/// movie. Native emitters remain unchanged and continue to use `channels()`.
public protocol StandaloneRenderedEffectEmitter: StandaloneEffectEmitter {
    func prepareRenderedAsset(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        outputRoot: URL
    ) throws -> RenderedEffectAsset

    func emitPreparedDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        preparedAsset: RenderedEffectAsset,
        publishedPreparedURL: URL,
        version: String
    ) throws -> String
}

public struct RenderedEffectAssetProvenance: Codable, Equatable, Sendable {
    public let filename: String
    public let sha256: String
    public let constructionDigest: String
    public let rendererRecipeDigest: String
    public let sourceSHA256: String
    public let width: Int
    public let height: Int
    public let fps: Int
    public let frameCount: Int
    public let durationSeconds: Double
    public let codec: String
    public let codecProfile: String
    public let codecFourCC: String
    public let pixelFormat: String
    public let videoOnly: Bool
    public let details: [String: String]

    public init(asset: RenderedEffectAsset) {
        filename = asset.url.lastPathComponent
        sha256 = asset.sha256
        constructionDigest = asset.constructionDigest
        rendererRecipeDigest = asset.rendererRecipeDigest
        sourceSHA256 = asset.sourceSHA256
        width = asset.width
        height = asset.height
        fps = asset.fps
        frameCount = asset.frameCount
        durationSeconds = asset.durationSeconds
        codec = asset.codec
        codecProfile = asset.codecProfile
        codecFourCC = asset.codecFourCC
        pixelFormat = asset.pixelFormat
        videoOnly = asset.videoOnly
        details = asset.provenance
    }
}
