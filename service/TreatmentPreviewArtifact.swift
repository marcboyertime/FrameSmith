import Foundation

/// The fidelity and reuse boundary of an admitted treatment preview.
///
/// FrameSmith currently uses the complete renderer output for comparison. A
/// future proxy must be a distinct case with a distinct identity and may not
/// satisfy exact export admission.
public enum TreatmentPreviewProfile: String, Codable, Equatable, Sendable {
    case exactPreparedTreatment = "exact_prepared_treatment"
}

/// The exact construction a comparison tile is allowed to show.
///
/// Keeping the cases explicit makes it impossible for a rendered treatment to
/// silently route through neutral native channels or an untreated poster.
public enum TreatmentPreviewRepresentation: Equatable, Sendable {
    case native(AdmittedChannelSnapshot)
    case rendered(RenderedEffectAsset)

    public var contentDigest: String {
        switch self {
        case .native(let channels): return channels.digest
        case .rendered(let asset): return asset.sha256
        }
    }
}

public enum TreatmentPreviewAdmissionError: Error, LocalizedError, Equatable, Sendable {
    case renderedAssetRequired(String)
    case renderedAssetForbidden(String)
    case executionDrifted(String)
    case previewDrifted(String)
    case comparisonLimit
    case inconsistentTransport(String)

    public var errorDescription: String? {
        switch self {
        case .renderedAssetRequired(let id):
            return "Treatment \(id) is rendered and requires its already prepared exact movie"
        case .renderedAssetForbidden(let id):
            return "Treatment \(id) is native and refuses a rendered movie"
        case .executionDrifted(let detail):
            return "The admitted treatment execution drifted: \(detail)"
        case .previewDrifted(let detail):
            return "The admitted treatment preview drifted: \(detail)"
        case .comparisonLimit:
            return "Compare supports at most three admitted treatment options."
        case .inconsistentTransport(let detail):
            return "Comparison transport is inconsistent: \(detail)"
        }
    }
}

/// A second sealed admission artifact produced after cheap deterministic
/// treatment admission.
///
/// The initializer is intentionally internal. Package clients can only obtain
/// this value by asking `TreatmentPreviewAdmission` to validate an admitted
/// execution and, for rendered treatments, a sealed `RenderedEffectAsset`.
public struct AdmittedTreatmentPreview: Equatable, Sendable {
    public let optionID: String
    public let structureFingerprint: String
    public let constructionSignature: String
    public let admittedExecutionDigest: String
    public let registryDigest: String
    public let inputSnapshotDigest: String
    public let profile: TreatmentPreviewProfile
    public let representation: TreatmentPreviewRepresentation
    public let artifactDigest: String

    init(
        optionID: String,
        structureFingerprint: String,
        constructionSignature: String,
        admittedExecutionDigest: String,
        registryDigest: String,
        inputSnapshotDigest: String,
        profile: TreatmentPreviewProfile,
        representation: TreatmentPreviewRepresentation,
        artifactDigest: String
    ) {
        self.optionID = optionID
        self.structureFingerprint = structureFingerprint
        self.constructionSignature = constructionSignature
        self.admittedExecutionDigest = admittedExecutionDigest
        self.registryDigest = registryDigest
        self.inputSnapshotDigest = inputSnapshotDigest
        self.profile = profile
        self.representation = representation
        self.artifactDigest = artifactDigest
    }
}

/// Constructs and revalidates preview artifacts against the current admitted
/// execution. Rendering is deliberately outside this type.
public enum TreatmentPreviewAdmission {
    private struct InputBody: Codable {
        struct Source: Codable {
            let role: String
            let itemID: String
            let canonicalPath: String
            let sha256: String
            let context: LocalMediaContextFacts
        }

        let optionID: String
        let structureFingerprint: String
        let registryEffectID: String
        let registryDigest: String
        let treatmentContractDigest: String
        let techniqueVersions: [String: Int]
        let sources: [Source]
    }

    public static func admit(
        execution: AdmittedTreatmentExecution,
        preparedRenderedAsset: RenderedEffectAsset?
    ) throws -> AdmittedTreatmentPreview {
        try validateExecution(execution)
        guard let emitter = StandaloneEmitterCatalog().emitter(for: execution.treatment.effectPlan.effectID) else {
            throw TreatmentPreviewAdmissionError.executionDrifted("the registered emitter is missing")
        }

        let representation: TreatmentPreviewRepresentation
        if emitter is any StandaloneRenderedEffectEmitter {
            guard let preparedRenderedAsset else {
                throw TreatmentPreviewAdmissionError.renderedAssetRequired(execution.treatment.optionID)
            }
            try validateRenderedAsset(preparedRenderedAsset, execution: execution)
            representation = .rendered(preparedRenderedAsset)
        } else {
            guard preparedRenderedAsset == nil else {
                throw TreatmentPreviewAdmissionError.renderedAssetForbidden(execution.treatment.optionID)
            }
            let current = try emitter.channels(
                plan: execution.treatment.effectPlan,
                media: execution.media
            )
            guard execution.channels.matches(current) else {
                throw TreatmentPreviewAdmissionError.executionDrifted("native channel construction changed")
            }
            representation = .native(execution.channels)
        }

        let inputDigest = try inputSnapshotDigest(execution)
        let profile = TreatmentPreviewProfile.exactPreparedTreatment
        let artifactDigest = TreatmentIdentity.digest([
            "framesmith-admitted-treatment-preview-v1",
            execution.treatment.optionID,
            execution.structure.fingerprint,
            execution.treatment.constructionSignature,
            execution.constructionSignature,
            execution.registryDigest,
            inputDigest,
            profile.rawValue,
            representation.contentDigest
        ])
        return AdmittedTreatmentPreview(
            optionID: execution.treatment.optionID,
            structureFingerprint: execution.structure.fingerprint,
            constructionSignature: execution.treatment.constructionSignature,
            admittedExecutionDigest: execution.constructionSignature,
            registryDigest: execution.registryDigest,
            inputSnapshotDigest: inputDigest,
            profile: profile,
            representation: representation,
            artifactDigest: artifactDigest
        )
    }

    public static func validate(
        _ preview: AdmittedTreatmentPreview,
        against execution: AdmittedTreatmentExecution
    ) throws {
        let rebuilt: AdmittedTreatmentPreview
        switch preview.representation {
        case .native:
            rebuilt = try admit(execution: execution, preparedRenderedAsset: nil)
        case .rendered(let asset):
            rebuilt = try admit(execution: execution, preparedRenderedAsset: asset)
        }
        guard rebuilt == preview else {
            throw TreatmentPreviewAdmissionError.previewDrifted(
                "option, structure, registry, inputs, profile, construction, or content identity changed"
            )
        }
    }

    public static func inputSnapshotDigest(_ execution: AdmittedTreatmentExecution) throws -> String {
        let sources = LocalMediaRole.structuralRoles.compactMap { role -> InputBody.Source? in
            guard let asset = execution.media[role] else { return nil }
            return .init(
                role: role.rawValue,
                itemID: asset.itemID,
                canonicalPath: asset.canonicalPath,
                sha256: asset.sha256,
                context: asset.contextFacts
            )
        }
        let body = InputBody(
            optionID: execution.treatment.optionID,
            structureFingerprint: execution.structure.fingerprint,
            registryEffectID: execution.registryEffectID,
            registryDigest: execution.registryDigest,
            treatmentContractDigest: execution.contract.schemaDigest,
            techniqueVersions: execution.treatment.techniqueCardVersions,
            sources: sources
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return ContentHasher.sha256(try encoder.encode(body))
    }

    private static func validateExecution(_ execution: AdmittedTreatmentExecution) throws {
        guard execution.structure.fingerprint == execution.admittedAtFingerprint,
              execution.treatment.structureFingerprint == execution.structure.fingerprint else {
            throw TreatmentPreviewAdmissionError.executionDrifted("the editorial structure fingerprint changed")
        }
        guard execution.registryEffectID == execution.treatment.effectPlan.effectID.rawValue,
              !execution.registryDigest.isEmpty else {
            throw TreatmentPreviewAdmissionError.executionDrifted("the registry snapshot changed")
        }
        guard execution.treatment.constructionSignature == TreatmentIdentity.constructionSignature(
            for: execution.treatment.effectPlan
        ) else {
            throw TreatmentPreviewAdmissionError.executionDrifted("the treatment construction signature changed")
        }
        let expectedExecution = TreatmentIdentity.digest([
            execution.treatment.constructionSignature,
            execution.channels.canonicalPayload
        ])
        guard execution.constructionSignature == expectedExecution else {
            throw TreatmentPreviewAdmissionError.executionDrifted("the admitted execution digest changed")
        }
    }

    private static func validateRenderedAsset(
        _ asset: RenderedEffectAsset,
        execution: AdmittedTreatmentExecution
    ) throws {
        try asset.validate(plan: execution.treatment.effectPlan, media: execution.media)
        guard asset.videoOnly, asset.videoFormat == .proRes422HQ10Bit else {
            throw TreatmentPreviewAdmissionError.previewDrifted(
                "exact rendered comparison requires verified video-only ProRes 422 HQ bytes"
            )
        }
        guard !asset.rendererRecipeDigest.isEmpty else {
            throw TreatmentPreviewAdmissionError.previewDrifted("renderer recipe identity is missing")
        }
        guard let primary = execution.media[.primary],
              let maximumLongEdge = execution.treatment.effectPlan.parameters["outputLongEdge"]?.numberValue,
              maximumLongEdge.rounded() == maximumLongEdge else {
            throw TreatmentPreviewAdmissionError.previewDrifted("rendered output geometry inputs are missing")
        }
        let geometry = try RenderedOutputGeometry(
            source: primary.dimensions,
            maximumLongEdge: Int(maximumLongEdge)
        )
        guard asset.width == geometry.width, asset.height == geometry.height else {
            throw TreatmentPreviewAdmissionError.previewDrifted("rendered output geometry changed")
        }
        guard let fps = execution.treatment.effectPlan.parameters["fps"]?.numberValue,
              fps.rounded() == fps,
              asset.fps == Int(fps),
              let duration = execution.treatment.effectPlan.parameters["durationSeconds"]?.numberValue,
              duration.isFinite,
              asset.frameCount == Int((duration * fps).rounded()),
              abs(asset.durationSeconds - duration) <= 0.000_001 else {
            throw TreatmentPreviewAdmissionError.previewDrifted("rendered timing changed")
        }
    }
}

/// A UI-independent descriptor proving which rendering path a comparison tile
/// must use.
public struct TreatmentComparisonTileDescriptor: Equatable, Sendable {
    public enum Representation: Equatable, Sendable {
        case native(AdmittedChannelSnapshot)
        case rendered(RenderedEffectAsset)
    }

    public let optionID: String
    public let title: String
    public let artifactDigest: String
    public let representation: Representation
    public let frameRate: Int
    public let frameCount: Int

    public static func make(
        preview: AdmittedTreatmentPreview,
        execution: AdmittedTreatmentExecution
    ) throws -> Self {
        try TreatmentPreviewAdmission.validate(preview, against: execution)
        switch preview.representation {
        case .native(let channels):
            let fps = NativeFCPXMLFrameRate.thirty.framesPerSecond
            return .init(
                optionID: preview.optionID,
                title: execution.treatment.name,
                artifactDigest: preview.artifactDigest,
                representation: .native(channels),
                frameRate: fps,
                frameCount: max(1, NativeFCPXMLFrameRate.thirty.frames(seconds: channels.durationSeconds))
            )
        case .rendered(let asset):
            return .init(
                optionID: preview.optionID,
                title: execution.treatment.name,
                artifactDigest: preview.artifactDigest,
                representation: .rendered(asset),
                frameRate: asset.fps,
                frameCount: asset.frameCount
            )
        }
    }
}

/// One integer clock shared by source, native channels, and exact movie-frame
/// sampling. Integer frame ownership avoids independently autoplaying players.
public struct TreatmentComparisonTransport: Equatable, Sendable {
    public let frameRate: Int
    public let frameCount: Int
    public private(set) var frameIndex: Int
    public private(set) var isPlaying: Bool

    public init(
        descriptors: [TreatmentComparisonTileDescriptor],
        frameIndex: Int = 0,
        isPlaying: Bool = false
    ) throws {
        guard !descriptors.isEmpty, descriptors.count <= 3 else {
            throw descriptors.count > 3
                ? TreatmentPreviewAdmissionError.comparisonLimit
                : TreatmentPreviewAdmissionError.inconsistentTransport("at least one tile is required")
        }
        guard let first = descriptors.first,
              descriptors.allSatisfy({ $0.frameRate == first.frameRate && $0.frameCount == first.frameCount }) else {
            throw TreatmentPreviewAdmissionError.inconsistentTransport(
                "all options must use one exact frame rate and interval"
            )
        }
        guard first.frameRate > 0, first.frameCount > 0 else {
            throw TreatmentPreviewAdmissionError.inconsistentTransport("frame rate and count must be positive")
        }
        self.frameRate = first.frameRate
        self.frameCount = first.frameCount
        self.frameIndex = min(first.frameCount - 1, max(0, frameIndex))
        self.isPlaying = isPlaying
    }

    public var seconds: Double { Double(frameIndex) / Double(frameRate) }
    public var durationSeconds: Double { Double(frameCount) / Double(frameRate) }

    public mutating func togglePlayback() { isPlaying.toggle() }
    public mutating func pause() { isPlaying = false }
    public mutating func reset() { frameIndex = 0 }

    public mutating func scrub(toFrame requested: Int) {
        frameIndex = min(frameCount - 1, max(0, requested))
    }

    public mutating func scrub(toSeconds requested: Double) {
        guard requested.isFinite else { return }
        scrub(toFrame: Int((requested * Double(frameRate)).rounded(.down)))
    }

    public mutating func advance() {
        frameIndex = (frameIndex + 1) % frameCount
    }

    public func resolvedFrameIndices(tileCount: Int) -> [Int] {
        Array(repeating: frameIndex, count: max(0, tileCount))
    }
}

public struct TreatmentPreviewPreparationWorker: Sendable {
    private let operation: @Sendable (AdmittedTreatmentExecution) async throws -> RenderedEffectAsset

    public init(
        operation: @escaping @Sendable (AdmittedTreatmentExecution) async throws -> RenderedEffectAsset
    ) {
        self.operation = operation
    }

    public func prepare(_ execution: AdmittedTreatmentExecution) async throws -> RenderedEffectAsset {
        try await operation(execution)
    }

    public static func localExact(
        outputRoot: URL = StandaloneFCPXMLExportBuilder.defaultRenderCacheRoot
    ) -> Self {
        Self { execution in
            guard let emitter = StandaloneEmitterCatalog().emitter(
                for: execution.treatment.effectPlan.effectID
            ) as? any StandaloneRenderedEffectEmitter else {
                throw TreatmentPreviewAdmissionError.renderedAssetForbidden(execution.treatment.optionID)
            }
            let task = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let asset = try emitter.prepareRenderedAsset(
                    plan: execution.treatment.effectPlan,
                    media: execution.media,
                    outputRoot: outputRoot
                )
                try Task.checkCancellation()
                return asset
            }
            return try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        }
    }
}

public enum TreatmentPreviewPreparationState: Equatable, Sendable {
    case idle
    case queued
    case preparing
    case ready(AdmittedTreatmentPreview)
    case failed(String)
    case cancelled
}

/// Per-option, content-deduplicating, serial rendered-preview coordinator.
///
/// A returned asset is already durable. If ownership was cancelled while the
/// renderer crossed publication, the bytes may enter the validated content
/// cache but can never become the current option's ready state.
public actor TreatmentPreviewPreparationCoordinator {
    private let worker: TreatmentPreviewPreparationWorker
    private let selectionLimit: Int
    private var states: [String: TreatmentPreviewPreparationState] = [:]
    private var selectedOptionIDs: [String] = []
    private var generations: [String: UUID] = [:]
    private var optionContentKeys: [String: String] = [:]
    private var ownersByContentKey: [String: Set<String>] = [:]
    private var inFlight: [String: Task<RenderedEffectAsset, Error>] = [:]
    private var serialTail: Task<Void, Never>?
    private var assetCache: [String: RenderedEffectAsset] = [:]
    public private(set) var durableStaleArtifactCount = 0

    public init(
        worker: TreatmentPreviewPreparationWorker = .localExact(),
        selectionLimit: Int = 3
    ) {
        precondition(selectionLimit > 0)
        self.worker = worker
        self.selectionLimit = selectionLimit
    }

    public func state(for optionID: String) -> TreatmentPreviewPreparationState {
        states[optionID] ?? .idle
    }

    public func allStates() -> [String: TreatmentPreviewPreparationState] { states }

    @discardableResult
    public func prepare(
        _ execution: AdmittedTreatmentExecution,
        comparisonSelected: Bool = true
    ) async throws -> TreatmentPreviewPreparationState {
        let optionID = execution.treatment.optionID
        if comparisonSelected, !selectedOptionIDs.contains(optionID) {
            guard selectedOptionIDs.count < selectionLimit else {
                throw TreatmentPreviewAdmissionError.comparisonLimit
            }
            selectedOptionIDs.append(optionID)
        }

        cancelOwnership(optionID, keepSelection: true)
        let generation = UUID()
        generations[optionID] = generation

        guard let emitter = StandaloneEmitterCatalog().emitter(for: execution.treatment.effectPlan.effectID) else {
            let failed = TreatmentPreviewPreparationState.failed("The registered emitter is missing")
            states[optionID] = failed
            return failed
        }

        if !(emitter is any StandaloneRenderedEffectEmitter) {
            let preview = try TreatmentPreviewAdmission.admit(
                execution: execution,
                preparedRenderedAsset: nil
            )
            let ready = TreatmentPreviewPreparationState.ready(preview)
            states[optionID] = ready
            return ready
        }

        let contentKey = try RenderedConstructionIdentity.digest(
            plan: execution.treatment.effectPlan,
            media: execution.media
        )
        optionContentKeys[optionID] = contentKey
        ownersByContentKey[contentKey, default: []].insert(optionID)

        if let cached = assetCache[contentKey] {
            do {
                let preview = try TreatmentPreviewAdmission.admit(
                    execution: execution,
                    preparedRenderedAsset: cached
                )
                let ready = TreatmentPreviewPreparationState.ready(preview)
                states[optionID] = ready
                return ready
            } catch {
                assetCache.removeValue(forKey: contentKey)
            }
        }

        states[optionID] = .queued
        let task: Task<RenderedEffectAsset, Error>
        if let existing = inFlight[contentKey] {
            task = existing
        } else {
            let predecessor = serialTail
            let worker = self.worker
            let newTask = Task<RenderedEffectAsset, Error> { [weak self] in
                if let predecessor { await predecessor.value }
                try Task.checkCancellation()
                await self?.markPreparing(contentKey: contentKey)
                try Task.checkCancellation()
                return try await worker.prepare(execution)
            }
            task = newTask
            inFlight[contentKey] = newTask
            serialTail = Task { _ = try? await newTask.value }
        }

        let result = await task.result
        inFlight.removeValue(forKey: contentKey)

        switch result {
        case .success(let asset):
            do {
                let preview = try TreatmentPreviewAdmission.admit(
                    execution: execution,
                    preparedRenderedAsset: asset
                )
                assetCache[contentKey] = asset
                guard generations[optionID] == generation,
                      (!comparisonSelected || selectedOptionIDs.contains(optionID)) else {
                    durableStaleArtifactCount += 1
                    return .cancelled
                }
                let ready = TreatmentPreviewPreparationState.ready(preview)
                states[optionID] = ready
                return ready
            } catch {
                guard generations[optionID] == generation else { return .cancelled }
                let failed = TreatmentPreviewPreparationState.failed(error.localizedDescription)
                states[optionID] = failed
                return failed
            }
        case .failure(let error):
            guard generations[optionID] == generation else { return .cancelled }
            let terminal: TreatmentPreviewPreparationState
            if error is CancellationError {
                terminal = .cancelled
            } else {
                terminal = .failed(error.localizedDescription)
            }
            states[optionID] = terminal
            return terminal
        }
    }

    public func deselect(_ optionID: String) {
        cancelOwnership(optionID, keepSelection: false)
    }

    public func invalidateAll() {
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
        ownersByContentKey.removeAll()
        optionContentKeys.removeAll()
        generations.removeAll()
        for id in selectedOptionIDs { states[id] = .cancelled }
        selectedOptionIDs.removeAll()
    }

    private func markPreparing(contentKey: String) {
        for optionID in ownersByContentKey[contentKey] ?? [] {
            if generations[optionID] != nil { states[optionID] = .preparing }
        }
    }

    private func cancelOwnership(_ optionID: String, keepSelection: Bool) {
        generations.removeValue(forKey: optionID)
        if !keepSelection { selectedOptionIDs.removeAll { $0 == optionID } }
        if let contentKey = optionContentKeys.removeValue(forKey: optionID) {
            ownersByContentKey[contentKey]?.remove(optionID)
            if ownersByContentKey[contentKey]?.isEmpty == true {
                ownersByContentKey.removeValue(forKey: contentKey)
                inFlight[contentKey]?.cancel()
            }
        }
        if states[optionID] != nil { states[optionID] = .cancelled }
    }
}
