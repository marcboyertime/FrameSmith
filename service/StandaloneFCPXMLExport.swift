import Foundation

public enum StandaloneExportError: Error, LocalizedError, Equatable {
    case capabilityRefused(String)
    case noEmitter(EffectID, reason: String)
    case missingMedia(LocalMediaRole)
    case nonAbsolutePath(URL)
    case forbiddenOutputRoot(URL)
    case existingPackage(URL)
    case malformedGeneratedXML
    case dtdValidationFailed(String)
    case invalidRecipe(String)
    case unconfirmedTarget
    case wrongMediaKind(String)
    case sourceDurationExceeded
    case registryUnavailable
    case admittedArtifactMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .capabilityRefused(let reason): return "standalone_fcpxml_export refused: \(reason)"
        case .noEmitter(let effect, let reason): return "No standalone emitter for \(effect.rawValue): \(reason)"
        case .missingMedia(let role): return "The plan names no admitted media for the \(role.rawValue) role"
        case .nonAbsolutePath(let url): return "An absolute file path is required: \(url.path)"
        case .forbiddenOutputRoot(let url): return "Standalone export is forbidden at this path: \(url.path)"
        case .existingPackage(let url): return "Refusing to overwrite an existing export: \(url.path)"
        case .malformedGeneratedXML: return "Generated FCPXML was not valid UTF-8"
        case .dtdValidationFailed(let detail): return "FCPXML DTD validation failed: \(detail)"
        case .invalidRecipe(let detail): return "Could not build the transform recipe: \(detail)"
        case .unconfirmedTarget: return "A confirmed, in-bounds target point is required; refusing to substitute the frame centre for a point the user did not confirm"
        case .wrongMediaKind(let reason): return reason
        case .sourceDurationExceeded: return "The requested frame-quantized duration exceeds the admitted movie duration"
        case .registryUnavailable: return "Standalone export requires a validated effect registry"
        case .admittedArtifactMismatch(let detail): return "The admitted treatment artifact no longer matches export: \(detail)"
        }
    }
}

/// A transition centred on a locked edit point.
///
/// `cutFrame` is the user's edit point and is never moved. The transition
/// extends `durationFrames / 2` either side of it, which is why handles are a
/// hard prerequisite rather than something to trim toward.
public struct NativeFCPXMLTransitionDescriptor: Equatable, Sendable {
    public let cutFrame: Int
    public let durationFrames: Int
    public let outgoingDurationFrames: Int
    public let incomingDurationFrames: Int

    public init(cutFrame: Int, durationFrames: Int, outgoingDurationFrames: Int, incomingDurationFrames: Int) {
        self.cutFrame = cutFrame
        self.durationFrames = durationFrames
        self.outgoingDurationFrames = outgoingDurationFrames
        self.incomingDurationFrames = incomingDurationFrames
    }

    /// Frames of unused source needed on each side.
    public var requiredHandleFrames: Int { durationFrames / 2 }
}

/// A connected layer above the spine clip.
public struct NativeFCPXMLOverlayDescriptor: Equatable, Sendable {
    public let startFrameWithinParent: Int
    public let durationFrames: Int
    public let opacity: Double
    public let blendMode: NativeFCPXMLBlendMode?

    public init(startFrameWithinParent: Int, durationFrames: Int, opacity: Double, blendMode: NativeFCPXMLBlendMode?) {
        self.startFrameWithinParent = startFrameWithinParent
        self.durationFrames = durationFrames
        self.opacity = opacity
        self.blendMode = blendMode
    }
}

/// The intrinsic channels an effect will emit, before any document is built.
///
/// This exists so **preview and export read the same construction**. If a
/// preview were computed from the composition model and the export from these
/// channels, the two could disagree and only Final Cut would ever notice. With
/// one source, a preview that looks wrong is a symptom of an export that is
/// wrong — which is the useful direction for the error to point.
public struct NativeFCPXMLEffectChannels: Sendable {
    public let transform: NativeFCPXMLTransformChannel
    public let opacity: NativeFCPXMLOpacityChannel
    /// Present when the effect is a transition rather than a per-clip treatment.
    public var transition: NativeFCPXMLTransitionDescriptor?
    /// Present when the effect hangs a connected layer above the spine.
    public var overlay: NativeFCPXMLOverlayDescriptor?
    /// The Color Adjustments `Saturation` value, when the effect applies one.
    ///
    /// **Indicative only.** No observed mapping connects this 0–100 param to a
    /// perceptual result, and the probes reused a captured `25` rather than
    /// deriving it. A preview may suggest the direction of the change; it must
    /// not claim the magnitude.
    public let saturation: Double?
    public let durationSeconds: Double
    public let origin: NativeFCPXMLTimingOrigin
    public let frameWidth: Int
    public let frameHeight: Int

    public init(
        transform: NativeFCPXMLTransformChannel,
        opacity: NativeFCPXMLOpacityChannel,
        saturation: Double?,
        durationSeconds: Double,
        origin: NativeFCPXMLTimingOrigin,
        frameWidth: Int,
        frameHeight: Int,
        transition: NativeFCPXMLTransitionDescriptor? = nil,
        overlay: NativeFCPXMLOverlayDescriptor? = nil
    ) {
        self.transform = transform
        self.opacity = opacity
        self.transition = transition
        self.overlay = overlay
        self.saturation = saturation
        self.durationSeconds = durationSeconds
        self.origin = origin
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
    }
}

/// Emits the FCPXML body for one effect from a plan and its admitted media.
///
/// Separate from the probe builders on purpose. A probe reproduces one fixed
/// construction to ask a question; an emitter has to serve arbitrary plan
/// values, and the two have different failure modes.
public protocol StandaloneEffectEmitter: Sendable {
    var effectID: EffectID { get }

    /// The channels this effect will emit. `emitDocument` must build its
    /// document from exactly this, so preview and export cannot diverge.
    func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels

    func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String
}

// MARK: - Living still

public struct LivingStillStandaloneEmitter: StandaloneEffectEmitter {
    public let effectID: EffectID = .livingStill
    public init() {}

    public func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels {
        guard let asset = media[.primary] else { throw StandaloneExportError.missingMedia(.primary) }
        guard asset.kind == .still else { throw StandaloneExportError.wrongMediaKind("Living Still requires admitted still media") }
        let rate = NativeFCPXMLFrameRate.thirty
        let width = asset.dimensions.width
        let height = asset.dimensions.height
        let composition: LivingStillComposition
        do { composition = try LivingStillCompositionBuilder.build(from: plan) }
        catch { throw StandaloneExportError.invalidRecipe(error.localizedDescription) }
        let durationFrames = max(1, rate.frames(seconds: composition.durationSeconds))
        let fadeFrames = max(0, min(durationFrames, rate.frames(seconds: composition.fadeDurationSeconds)))
        let final = durationFrames - 1
        let start = composition.transformKeyframes[0]
        let end = composition.transformKeyframes[1]

        return NativeFCPXMLEffectChannels(
            transform: .pushInAndPan(
                startFrame: 0,
                endFrame: final,
                rate: rate,
                panXFraction: end.panX,
                panYFraction: end.panY,
                scaleStart: start.scale,
                scaleEnd: end.scale,
                width: width,
                height: height
            ),
            opacity: .fade(
                fadeStartFrame: max(0, durationFrames - fadeFrames),
                endFrame: final,
                rate: rate,
                startOpacity: composition.opacityKeyframes.first?.opacity ?? 1,
                endOpacity: composition.opacityKeyframes.last?.opacity ?? 0
            ),
            // Captured one-point adapter: no arbitrary colorEnrichment mapping.
            saturation: NativeFCPXMLColorAdjustments.capturedLivingStillSaturation,
            durationSeconds: Double(durationFrames) / Double(rate.framesPerSecond),
            origin: .still,
            frameWidth: width,
            frameHeight: height
        )
    }

    public func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String {
        guard let asset = media[.primary], let url = publishedMediaURLs[.primary] else {
            throw StandaloneExportError.missingMedia(.primary)
        }
        let rate = NativeFCPXMLFrameRate.thirty
        let width = asset.dimensions.width
        let height = asset.dimensions.height

        let resources = NativeFCPXMLStillResources(
            sequenceFormatID: "r1",
            assetID: "r2",
            stillFormatID: "r3",
            name: asset.itemID,
            mediaURL: url,
            width: width,
            height: height,
            frameRate: rate
        )
        // Built from the shared construction, never re-derived here.
        let built = try channels(plan: plan, media: media)
        let transform = built.transform
        let opacity = built.opacity
        let colorFilter = NativeFCPXMLColorAdjustments.filterNode(ref: "r4", saturation: built.saturation ?? NativeFCPXMLColorAdjustments.capturedLivingStillSaturation)

        var children: [NativeFCPXMLNode] = []
        if let node = transform.node { children.append(node) }
        if let node = opacity.node { children.append(node) }
        children.append(colorFilter)

        let duration = rate.time(frames: max(1, rate.frames(seconds: built.durationSeconds)))
        let video = resources.videoNode(offset: .zero, duration: duration, children: children)
        let name = StandaloneFCPXMLExportBuilder.projectName(for: plan)
        return NativeFCPXMLDocument(
            version: version,
            resources: resources.resourceNodes + [NativeFCPXMLColorAdjustments.effectNode(id: "r4")],
            eventName: name,
            projectName: name,
            sequenceFormatID: "r1",
            sequenceDuration: duration,
            spineChildren: [video]
        ).xmlString
    }
}

// MARK: - Targeted rotate/zoom

public struct TargetedRotateZoomStandaloneEmitter: StandaloneEffectEmitter {
    public let effectID: EffectID = .targetedRotateZoom
    public init() {}

    public func channels(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws -> NativeFCPXMLEffectChannels {
        guard let asset = media[.primary] else { throw StandaloneExportError.missingMedia(.primary) }
        let rate = NativeFCPXMLFrameRate.thirty
        let width = asset.dimensions.width
        let height = asset.dimensions.height

        // The plan's confirmed target point drives the compensation.
        //
        // An unconfirmed point is refused rather than defaulted to centre. A
        // zoom toward the middle is a different effect from the one the user
        // asked for, and substituting it would produce a plausible result that
        // silently ignores the request — the exact failure mode this project
        // keeps finding in FCPXML and has no reason to reintroduce here.
        guard let point = plan.normalizedPoint, point.confirmed, point.isInNormalizedBounds else {
            throw StandaloneExportError.unconfirmedTarget
        }
        guard let durationSeconds = plan.parameters["durationSeconds"]?.numberValue, durationSeconds.isFinite else { throw StandaloneExportError.invalidRecipe("durationSeconds is missing") }
        let expectedKeys: Set<String> = ["durationSeconds", "scaleStart", "scaleEnd", "rotationStartDegrees", "rotationEndDegrees", "direction", "easing"]
        guard Set(plan.parameters.keys) == expectedKeys else { throw StandaloneExportError.invalidRecipe("targeted parameters must exactly match the registry") }
        let durationFrames = max(1, rate.frames(seconds: durationSeconds))
        if asset.kind == .movie, let sourceSeconds = asset.durationSeconds, durationFrames > rate.frames(seconds: sourceSeconds) {
            throw StandaloneExportError.sourceDurationExceeded
        }
        guard let scaleStart = plan.parameters["scaleStart"]?.numberValue,
              let scaleEnd = plan.parameters["scaleEnd"]?.numberValue,
              let rotationStart = plan.parameters["rotationStartDegrees"]?.numberValue,
              let rotationEnd = plan.parameters["rotationEndDegrees"]?.numberValue else { throw StandaloneExportError.invalidRecipe("targeted parameters are missing") }
        guard [scaleStart, scaleEnd, rotationStart, rotationEnd].allSatisfy(\.isFinite),
              plan.parameters["easing"] == .string(Easing.easeInOut.rawValue),
              plan.parameters["direction"] == .string(rotationEnd - rotationStart > 0 ? "counterclockwise" : "clockwise") else {
            throw StandaloneExportError.invalidRecipe("targeted metadata or signed rotation compatibility is invalid")
        }

        let recipe: TargetedTransformKeyframeRecipe
        do {
            recipe = try TargetedTransformKeyframeRecipe(
                source: Point2D(x: point.x, y: point.y),
                durationSeconds: Double(durationFrames) / Double(rate.framesPerSecond),
                scaleStart: scaleStart,
                scaleEnd: scaleEnd,
                rotationStartDegrees: rotationStart,
                rotationEndDegrees: rotationEnd
            )
        } catch {
            throw StandaloneExportError.invalidRecipe(String(describing: error))
        }

        // A still and a movie do not share a keyframe origin.
        let origin: NativeFCPXMLTimingOrigin = asset.kind == .still ? .still : .movieFromZero
        return NativeFCPXMLEffectChannels(
            transform: .targetedRotateZoom(
                recipe: recipe,
                rate: rate,
                origin: origin,
                width: width,
                height: height,
                clipDurationFrames: durationFrames
            ),
            opacity: NativeFCPXMLOpacityChannel(),
            saturation: nil,
            durationSeconds: Double(durationFrames) / Double(rate.framesPerSecond),
            origin: origin,
            frameWidth: width,
            frameHeight: height
        )
    }

    public func emitDocument(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        publishedMediaURLs: [LocalMediaRole: URL],
        version: String
    ) throws -> String {
        guard let asset = media[.primary], let url = publishedMediaURLs[.primary] else {
            throw StandaloneExportError.missingMedia(.primary)
        }
        let rate = NativeFCPXMLFrameRate.thirty
        let width = asset.dimensions.width
        let height = asset.dimensions.height
        let built = try channels(plan: plan, media: media)
        let durationFrames = max(1, rate.frames(seconds: built.durationSeconds))

        // Built from the shared construction, never re-derived here.
        let transform = built.transform
        let duration = rate.time(frames: durationFrames)
        let name = StandaloneFCPXMLExportBuilder.projectName(for: plan)

        switch asset.kind {
        case .still:
            let resources = NativeFCPXMLStillResources(
                sequenceFormatID: "r1", assetID: "r2", stillFormatID: "r3",
                name: asset.itemID, mediaURL: url,
                width: width, height: height, frameRate: rate
            )
            var children: [NativeFCPXMLNode] = []
            if let node = transform.node { children.append(node) }
            let video = resources.videoNode(offset: .zero, duration: duration, children: children)
            return NativeFCPXMLDocument(
                version: version, resources: resources.resourceNodes,
                eventName: name, projectName: name,
                sequenceFormatID: "r1", sequenceDuration: duration, spineChildren: [video]
            ).xmlString
        case .movie:
            let sourceDuration = asset.durationSeconds.map { rate.time(frames: rate.frames(seconds: $0)) } ?? duration
            let resources = NativeFCPXMLMovieResources(
                formatID: "r1", assetID: "r2", name: asset.itemID,
                mediaURL: url, sourceDuration: sourceDuration, hasAudio: asset.hasAudio
            )
            var intrinsics: [NativeFCPXMLNode] = []
            if let node = transform.node { intrinsics.append(node) }
            let clip = resources.assetClipNode(offset: .zero, duration: duration, intrinsics: intrinsics)
            return NativeFCPXMLDocument(
                version: version, resources: [resources.formatNode, resources.assetNode],
                eventName: name, projectName: name,
                sequenceFormatID: "r1", sequenceDuration: duration, spineChildren: [clip]
            ).xmlString
        }
    }
}

// MARK: - Builder

/// Generates a **new** Final Cut project from admitted local media.
///
/// The claim boundary is the whole point of this type. It writes a project to
/// disk for the user to import by hand. It does not open Final Cut, does not
/// name an existing timeline, and does not modify one — which is why it takes
/// `AdmittedLocalMediaEvidence` rather than `VerifiedFinalCutSelectionEvidence`,
/// and why `standaloneFCPXMLExport` refuses a Final Cut selection outright.
///
/// Everything else the gate enforces still applies in full: schema v2, every
/// source matched on path and digest, and the effect's semantic contracts
/// admitted for the installed Final Cut build.
public struct StandaloneFCPXMLExportBuilder: Sendable {
    public static let preferredFCPXMLVersion = "1.14"
    public static let defaultOutputRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/FCPCommandConsole/exports/standalone", isDirectory: true)

    public let gate: CapabilityGate
    public let outputRoot: URL
    public let fcpxmlVersion: String
    public let emitters: [EffectID: any StandaloneEffectEmitter]
    public let catalog: StandaloneEmitterCatalog
    /// Injected by installed callers so export never relies on checkout paths.
    public let registry: EffectRegistry?

    public init(
        gate: CapabilityGate,
        outputRoot: URL = StandaloneFCPXMLExportBuilder.defaultOutputRoot,
        fcpxmlVersion: String = StandaloneFCPXMLExportBuilder.preferredFCPXMLVersion,
        emitters: [any StandaloneEffectEmitter] = [LivingStillStandaloneEmitter(), TargetedRotateZoomStandaloneEmitter(), NaturalDissolveStandaloneEmitter(), OldTelevisionStandaloneEmitter()],
        registry: EffectRegistry? = nil
    ) {
        self.gate = gate
        self.outputRoot = outputRoot
        self.fcpxmlVersion = fcpxmlVersion
        self.catalog = StandaloneEmitterCatalog(emitters: emitters)
        self.emitters = catalog.emitters
        self.registry = registry
    }

    /// Why an effect has no emitter yet. Stated rather than left as an absence,
    /// so the gap is legible in the error a caller sees.
    public static func missingEmitterReason(for effectID: EffectID) -> String {
        StandaloneEmitterCatalog().absenceReason(for: effectID) ?? "an emitter exists"
    }

    public static func projectName(for plan: EffectPlan) -> String {
        "FrameSmith \(plan.effectID.rawValue) \(plan.operationID.uuidString.prefix(8))"
    }

    public struct Package: Equatable, Sendable {
        public let operationID: UUID
        public let effectID: EffectID
        public let packageRoot: URL
        public let fcpxmlURL: URL
        public let instructionsURL: URL
        public let provenanceURL: URL
        public let mediaSHA256: [String: String]
        public let fcpxmlVersion: String
        /// The exact Final Cut build whose profile authorised this export.
        public let admittedAgainst: FinalCutVersionIdentity?
    }

    public func export(
        plan: EffectPlan,
        media: [LocalMediaRole: LocalMediaAsset],
        mediaEvidence: AdmittedLocalMediaEvidence,
        installedFinalCut: FinalCutVersionIdentity? = InstalledFinalCutVersionReader().read(),
        generatedAt: Date = Date()
    ) throws -> Package {
        // State a catalog absence before semantic validation, so unavailable
        // effects always receive their actionable reason.
        guard let emitter = catalog.emitter(for: plan.effectID) else {
            throw StandaloneExportError.noEmitter(plan.effectID, reason: Self.missingEmitterReason(for: plan.effectID))
        }
        if plan.effectID == .targetedRotateZoom,
           !(plan.normalizedPoint?.confirmed == true && plan.normalizedPoint?.isInNormalizedBounds == true) {
            throw StandaloneExportError.unconfirmedTarget
        }
        // Export is never allowed to skip semantic validation. CLI/checkouts
        // may discover the registry; installed callers inject their bundle copy.
        guard let registry = registry ?? (try? EffectRegistry.discover()) else {
            throw StandaloneExportError.registryUnavailable
        }
        try ValidatedPlanExecution(registry: registry, catalog: catalog).validate(plan: plan, media: media)
        // 1. The gate, in full. Nothing below runs on a refused plan.
        do {
            try gate.require(plan, capability: .standaloneFCPXMLExport, mediaEvidence: mediaEvidence)
        } catch {
            throw StandaloneExportError.capabilityRefused(error.localizedDescription)
        }

        // 2. An emitter must exist. A gate pass without one is a real gap, not
        //    something to paper over with a partial document.
        try validateOutputRoot(outputRoot)
        let fileManager = FileManager.default
        let packageRoot = outputRoot.appendingPathComponent(plan.operationID.uuidString, isDirectory: true)
        guard !fileManager.fileExists(atPath: packageRoot.path) else {
            throw StandaloneExportError.existingPackage(packageRoot)
        }

        let stagingRoot = outputRoot.appendingPathComponent(
            ".standalone-staging-\(plan.operationID.uuidString)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        do {
            let mediaRoot = stagingRoot.appendingPathComponent("Media", isDirectory: true)
            try fileManager.createDirectory(at: mediaRoot, withIntermediateDirectories: false)

            var hashes: [String: String] = [:]
            var publishedURLs: [LocalMediaRole: URL] = [:]
            for (role, asset) in media {
                let filename = URL(fileURLWithPath: asset.canonicalPath).lastPathComponent
                let destination = mediaRoot.appendingPathComponent(filename)
                if !fileManager.fileExists(atPath: destination.path) {
                    try fileManager.copyItem(at: URL(fileURLWithPath: asset.canonicalPath), to: destination)
                }
                let copied = try ContentHasher.sha256File(destination)
                // The digest the plan was admitted against must survive the copy.
                guard copied == asset.sha256 else {
                    throw StandaloneExportError.capabilityRefused("copied media digest does not match the admitted asset for role \(role.rawValue)")
                }
                hashes[filename] = copied
                publishedURLs[role] = packageRoot.appendingPathComponent("Media/\(filename)")
            }

            let xml = try emitter.emitDocument(
                plan: plan, media: media, publishedMediaURLs: publishedURLs, version: fcpxmlVersion)
            guard let data = xml.data(using: .utf8) else { throw StandaloneExportError.malformedGeneratedXML }
            let fcpxmlURL = stagingRoot.appendingPathComponent("FrameSmith.fcpxml")
            try data.write(to: fcpxmlURL, options: .atomic)
            try validateDTD(xmlURL: fcpxmlURL)

            let provenance = Provenance(
                schemaVersion: "1",
                operationID: plan.operationID,
                effectID: plan.effectID.rawValue,
                planSchemaVersion: plan.schemaVersion,
                originalRequest: plan.originalRequest,
                generatedAt: generatedAt,
                fcpxmlVersion: fcpxmlVersion,
                admittedAgainstFinalCut: installedFinalCut.map(\.description),
                admittedContracts: ManualFCPXMLSemanticsEvidence
                    .requiredContracts(for: plan.effectID).map(\.rawValue).sorted(),
                mediaSHA256: hashes,
                claim: Self.claimStatement
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(provenance).write(to: stagingRoot.appendingPathComponent("provenance.json"), options: .atomic)
            try Data(readme(plan: plan, installedFinalCut: installedFinalCut).utf8)
                .write(to: stagingRoot.appendingPathComponent("README.md"), options: .atomic)

            guard !fileManager.fileExists(atPath: packageRoot.path) else {
                throw StandaloneExportError.existingPackage(packageRoot)
            }
            try fileManager.moveItem(at: stagingRoot, to: packageRoot)
            return Package(
                operationID: plan.operationID,
                effectID: plan.effectID,
                packageRoot: packageRoot,
                fcpxmlURL: packageRoot.appendingPathComponent("FrameSmith.fcpxml"),
                instructionsURL: packageRoot.appendingPathComponent("README.md"),
                provenanceURL: packageRoot.appendingPathComponent("provenance.json"),
                mediaSHA256: hashes,
                fcpxmlVersion: fcpxmlVersion,
                admittedAgainst: installedFinalCut
            )
        } catch {
            try? fileManager.removeItem(at: stagingRoot)
            throw error
        }
    }

    /// The sentence the package must never contradict.
    public static let claimStatement =
        "FrameSmith generated a new Final Cut project from admitted local media. It did not open Final Cut, did not read an existing timeline, and did not modify one. Import it by hand."

    public struct Provenance: Codable, Equatable, Sendable {
        public let schemaVersion: String
        public let operationID: UUID
        public let effectID: String
        public let planSchemaVersion: String
        public let originalRequest: String
        public let generatedAt: Date
        public let fcpxmlVersion: String
        public let admittedAgainstFinalCut: String?
        public let admittedContracts: [String]
        public let mediaSHA256: [String: String]
        public let claim: String
    }

    // MARK: - Rails

    func validateOutputRoot(_ root: URL) throws {
        guard root.isFileURL, root.path.hasPrefix("/"), !root.pathComponents.contains("..") else {
            throw StandaloneExportError.nonAbsolutePath(root)
        }
        let components = root.standardizedFileURL.pathComponents
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard !["/", home, "\(home)/Movies"].contains(root.standardizedFileURL.path) else {
            throw StandaloneExportError.forbiddenOutputRoot(root)
        }
        // Libraries, the application, captured ground truth, and spent probe
        // packages are all off limits.
        let forbidden = ["ground-truth", "roundtrip-spikes", "living-still-probes", "native-effect-probes"]
        guard !components.contains(where: { $0.lowercased().hasSuffix(".fcpbundle") }),
              !components.contains(where: { $0.caseInsensitiveCompare("Final Cut Pro.app") == .orderedSame }),
              !components.contains(where: { forbidden.contains($0) }) else {
            throw StandaloneExportError.forbiddenOutputRoot(root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func validateDTD(xmlURL: URL) throws {
        let dtdURL = NativeFCPXMLDTD.url(forVersion: fcpxmlVersion)
        guard FileManager.default.isReadableFile(atPath: dtdURL.path) else { return }
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
            throw StandaloneExportError.dtdValidationFailed("timed out")
        }
        guard process.terminationStatus == 0 else {
            let detail = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "xmllint exited \(process.terminationStatus)"
            throw StandaloneExportError.dtdValidationFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func readme(plan: EffectPlan, installedFinalCut: FinalCutVersionIdentity?) -> String {
        """
        # \(Self.projectName(for: plan))

        \(Self.claimStatement)

        - Effect: `\(plan.effectID.rawValue)`
        - Request: "\(plan.originalRequest)"
        - FCPXML \(fcpxmlVersion)
        - Admitted against Final Cut \(installedFinalCut?.description ?? "(unknown build)")

        ## Import

        1. Open your library in Final Cut Pro.
        2. File ▸ Import ▸ XML…, choose `FrameSmith.fcpxml` from this package.
        3. A **new project** appears. Nothing you already had is touched.

        The media in `Media/` is referenced by absolute path from this package.
        Moving the package will break those references until you relink.

        ## What this is and is not

        This project was generated from semantics observed in Final Cut
        \(installedFinalCut?.description ?? "an unrecorded build") and recorded in
        `service/FinalCutSemanticProfile.swift`. If you have since updated Final
        Cut, that profile no longer applies and the constructions here have not
        been verified against your build.

        `provenance.json` records the plan, the media digests, and the contracts
        this export required.
        """
    }

    /// Export boundary for editorial treatments. The emitter is allowed to
    /// build XML only after it proves its current construction is byte-for-byte
    /// equivalent to the admitted channel snapshot.
    public func export(
        admitted execution: AdmittedTreatmentExecution,
        mediaEvidence: AdmittedLocalMediaEvidence,
        installedFinalCut: FinalCutVersionIdentity? = InstalledFinalCutVersionReader().read(),
        generatedAt: Date = Date()
    ) throws -> Package {
        guard execution.structure.fingerprint == execution.admittedAtFingerprint else { throw StandaloneExportError.admittedArtifactMismatch("structure fingerprint drifted") }
        guard let emitter = catalog.emitter(for: execution.treatment.effectPlan.effectID) else { throw StandaloneExportError.noEmitter(execution.treatment.effectPlan.effectID, reason: Self.missingEmitterReason(for: execution.treatment.effectPlan.effectID)) }
        let current = try emitter.channels(plan: execution.treatment.effectPlan, media: execution.media)
        guard execution.channels.matches(current) else { throw StandaloneExportError.admittedArtifactMismatch("channel digest \(AdmittedChannelSnapshot(channels: current).digest) does not match \(execution.channels.digest)") }
        guard execution.registryEffectID == execution.treatment.effectPlan.effectID.rawValue else { throw StandaloneExportError.admittedArtifactMismatch("registry effect identity drifted") }
        return try export(plan: execution.treatment.effectPlan, media: execution.media, mediaEvidence: mediaEvidence, installedFinalCut: installedFinalCut, generatedAt: generatedAt)
    }
}
