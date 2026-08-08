import Foundation

/// A capability declaration for a future Final Cut adapter.
///
/// The declaration is intentionally effect-specific and revision-bound.  An
/// offline/default capability has no effects and no revision, so it can never
/// enable Apply.  The command session also requires a mutation closure and
/// verified evidence from that closure; a capability alone is not a claim that
/// Final Cut was changed.
public struct CommandAdapterCapability: Codable, Equatable, Sendable {
    public var supportedEffects: [EffectID]
    public var currentRevision: String?
    public var exactEffectSupport: Bool
    public var undoSupport: Bool

    public init(
        supportedEffects: [EffectID] = [],
        currentRevision: String? = nil,
        exactEffectSupport: Bool = false,
        undoSupport: Bool = false
    ) {
        self.supportedEffects = Array(Set(supportedEffects)).sorted { $0.rawValue < $1.rawValue }
        self.currentRevision = currentRevision
        self.exactEffectSupport = exactEffectSupport
        self.undoSupport = undoSupport
    }

    public init(effect: EffectID, currentRevision: String, undoSupport: Bool = false) {
        self.init(supportedEffects: [effect], currentRevision: currentRevision, exactEffectSupport: true, undoSupport: undoSupport)
    }

    public static let offline = CommandAdapterCapability()

    public func proves(effect: EffectID, revision: String) -> Bool {
        exactEffectSupport && supportedEffects.contains(effect) && currentRevision == revision
    }
}

/// Closures supplied by a separately proven adapter.  No default closure is
/// supplied: the offline adapter is deliberately incapable of applying or
/// undoing anything.
public struct CommandSessionAdapter: Sendable {
    public typealias RevisionProvider = @Sendable () throws -> String
    public typealias SnapshotHashProvider = @Sendable (EffectPlan) throws -> String
    public typealias Mutation = @Sendable (EffectPlan) throws -> VerifiedMutationEvidence
    public typealias Undo = @Sendable (JobRecord) throws -> VerifiedMutationEvidence

    public let capability: CommandAdapterCapability
    private let revisionProvider: RevisionProvider?
    private let beforeSnapshotHashValue: String?
    private let beforeSnapshotHashProvider: SnapshotHashProvider?
    private let mutation: Mutation?
    private let undoMutation: Undo?

    public init(
        capability: CommandAdapterCapability = .offline,
        revisionProvider: RevisionProvider? = nil,
        mutation: Mutation? = nil,
        undo: Undo? = nil,
        beforeSnapshotHash: String? = nil,
        beforeSnapshotHashProvider: SnapshotHashProvider? = nil
    ) {
        self.capability = capability
        self.revisionProvider = revisionProvider
        self.beforeSnapshotHashValue = beforeSnapshotHash
        self.beforeSnapshotHashProvider = beforeSnapshotHashProvider
        self.mutation = mutation
        self.undoMutation = undo
    }

    public static let offline = CommandSessionAdapter()

    fileprivate var canMutate: Bool { mutation != nil }
    fileprivate var canUndo: Bool { undoMutation != nil }

    fileprivate func currentRevision() throws -> String? {
        if let revisionProvider { return try revisionProvider() }
        return capability.currentRevision
    }

    fileprivate func apply(_ plan: EffectPlan) throws -> VerifiedMutationEvidence {
        guard let mutation else {
            throw CommandSessionError.capabilityDenied("No mutation adapter was injected")
        }
        return try mutation(plan)
    }

    fileprivate func beforeSnapshotHash(for plan: EffectPlan) throws -> String? {
        if let beforeSnapshotHashProvider { return try beforeSnapshotHashProvider(plan) }
        return beforeSnapshotHashValue
    }

    fileprivate func undo(_ record: JobRecord) throws -> VerifiedMutationEvidence {
        guard let undoMutation else {
            throw CommandSessionError.undoUnavailable("No verified undo adapter was injected")
        }
        return try undoMutation(record)
    }
}

public enum PanelEditability: String, Codable, CaseIterable, Sendable {
    case editable
    case baked
}

public struct PanelEditabilityLabel: Codable, Equatable, Sendable {
    public var value: String
    public var classification: PanelEditability

    public init(value: String, classification: PanelEditability) {
        self.value = value
        self.classification = classification
    }
}

/// Compact, display-oriented editability metadata derived from the current
/// registry definition. Generated assets are labelled baked. Empty editable
/// lists are intentional when the registry declares no live controls.
public struct PanelEditabilitySummary: Codable, Equatable, Sendable {
    public var editable: [String]
    public var baked: [String]
    public var labels: [PanelEditabilityLabel]

    public init(editable: [String] = [], baked: [String] = [], labels: [PanelEditabilityLabel] = []) {
        self.editable = editable
        self.baked = baked
        self.labels = labels
    }

    public var hasEditableProperties: Bool { !editable.isEmpty }
    public var hasBakedAssets: Bool { !baked.isEmpty }
}

public enum PanelPreviewStatus: String, Codable, CaseIterable, Sendable {
    case unavailable
    case ready
    case cancelled
    case applying
    case applied
    case undoing
    case undone
    case failed
}

public struct SelectedClipSummary: Codable, Equatable, Sendable {
    public var timelineID: String
    public var clipIDs: [String]
    public var selectionType: SelectionType
    public var revision: String
    public var frameStart: Int?
    public var frameEnd: Int?
    public var adjacent: Bool
    public var sourceCount: Int

    public init(selection: SelectionToken) {
        timelineID = selection.timelineID
        clipIDs = selection.clipIDs
        selectionType = selection.selectionType
        revision = selection.revision
        frameStart = selection.startFrame
        frameEnd = selection.endFrame
        adjacent = selection.adjacent
        sourceCount = selection.sourceIdentities.count
    }
}

public struct PanelIssue: Codable, Equatable, Sendable, LocalizedError {
    public enum Code: String, Codable, CaseIterable, Sendable {
        case missingCommand
        case unsupportedRequest
        case missingRequiredTarget
        case invalidSelection
        case schemaValidation
        case planValidation
        case capabilityDenied
        case staleRevision
        case noPlan
        case cancellationDenied
        case undoUnavailable
        case adapterRejected
        case jobCoordinator
    }

    public var code: Code
    public var message: String
    public var operationID: UUID?

    public init(code: Code, message: String, operationID: UUID? = nil) {
        self.code = code
        self.message = message
        self.operationID = operationID
    }

    public var errorDescription: String? { message }
}

public enum CommandSessionError: Error, LocalizedError, Equatable, Sendable {
    case missingCommand
    case unsupportedRequest(String)
    case missingRequiredTarget
    case invalidSelection(String)
    case schemaValidation(String)
    case planValidation(String)
    case capabilityDenied(String)
    case staleRevision(expected: String, actual: String)
    case noPlan
    case cancellationDenied(String)
    case undoUnavailable(String)
    case adapterRejected(String)
    case jobCoordinator(String)

    public var errorDescription: String? {
        switch self {
        case .missingCommand: return "A command is required"
        case .unsupportedRequest(let reason): return "Unsupported request: \(reason)"
        case .missingRequiredTarget: return "This workflow requires a confirmed normalized target point"
        case .invalidSelection(let reason): return "Invalid selection: \(reason)"
        case .schemaValidation(let reason): return "Plan schema validation failed: \(reason)"
        case .planValidation(let reason): return "Plan validation failed: \(reason)"
        case .capabilityDenied(let reason): return "Apply is disabled: \(reason)"
        case .staleRevision(let expected, let actual): return "Apply is disabled for stale revision (expected \(expected), got \(actual))"
        case .noPlan: return "No validated plan is available"
        case .cancellationDenied(let reason): return "Cancellation is unavailable: \(reason)"
        case .undoUnavailable(let reason): return "Undo is unavailable: \(reason)"
        case .adapterRejected(let reason): return "Adapter rejected the operation: \(reason)"
        case .jobCoordinator(let reason): return "Job lifecycle error: \(reason)"
        }
    }
}

/// The complete state needed by a compact command panel.  `previewRendered`
/// remains false in this service-only layer: a plan can be inspected and its
/// strategy can be shown without pretending that a media preview was rendered.
public struct PanelState: Codable, Equatable, Sendable {
    public var commandText: String
    public var selectedClipSummary: SelectedClipSummary?
    public var normalizedTarget: Target?
    public var plan: EffectPlan?
    public var editability: PanelEditabilitySummary
    public var previewStrategy: String?
    public var previewStatus: PanelPreviewStatus
    public var previewRendered: Bool
    public var applyEnabled: Bool
    public var cancelEnabled: Bool
    public var undoEnabled: Bool
    public var jobState: JobState?
    public var history: [JobHistoryEvent]
    public var error: PanelIssue?

    public init(
        commandText: String = "",
        selectedClipSummary: SelectedClipSummary? = nil,
        normalizedTarget: Target? = nil,
        plan: EffectPlan? = nil,
        editability: PanelEditabilitySummary = PanelEditabilitySummary(),
        previewStrategy: String? = nil,
        previewStatus: PanelPreviewStatus = .unavailable,
        previewRendered: Bool = false,
        applyEnabled: Bool = false,
        cancelEnabled: Bool = false,
        undoEnabled: Bool = false,
        jobState: JobState? = nil,
        history: [JobHistoryEvent] = [],
        error: PanelIssue? = nil
    ) {
        self.commandText = commandText
        self.selectedClipSummary = selectedClipSummary
        self.normalizedTarget = normalizedTarget
        self.plan = plan
        self.editability = editability
        self.previewStrategy = previewStrategy
        self.previewStatus = previewStatus
        self.previewRendered = previewRendered
        self.applyEnabled = applyEnabled
        self.cancelEnabled = cancelEnabled
        self.undoEnabled = undoEnabled
        self.jobState = jobState
        self.history = history
        self.error = error
    }

    public var command: String { commandText }
    public var selectedClip: SelectedClipSummary? { selectedClipSummary }
    public var structuredPlan: EffectPlan? { plan }
}

public typealias CommandPanelState = PanelState
public typealias CommandSessionState = PanelState

/// Actor-backed planning and lifecycle state for the Phase 1 command panel.
/// It owns no Final Cut runtime and never performs UI automation, networking,
/// media upload, or arbitrary backend dispatch.
public actor CommandSession {
    public let registry: EffectRegistry
    public let schemaURL: URL
    public let coordinator: JobCoordinator

    private let planner: DeterministicPlanner
    private let schemaValidator: PlanSchemaValidator
    private let adapter: CommandSessionAdapter
    private var activePlan: EffectPlan?
    private var activeRecord: JobRecord?
    private var panel: PanelState

    public init(
        registry: EffectRegistry,
        schemaURL: URL,
        coordinator: JobCoordinator,
        adapter: CommandSessionAdapter = .offline
    ) throws {
        self.registry = registry
        self.schemaURL = schemaURL.standardizedFileURL
        self.coordinator = coordinator
        self.planner = DeterministicPlanner(registry: registry)
        self.schemaValidator = try PlanSchemaValidator(schemaURL: schemaURL)
        self.adapter = adapter
        self.activePlan = nil
        self.activeRecord = nil
        self.panel = PanelState()
    }

    public init(
        registry: EffectRegistry,
        schemaURL: URL,
        runtimeRoot: URL,
        adapter: CommandSessionAdapter = .offline
    ) throws {
        let coordinator = try JobCoordinator(runtimeRoot: runtimeRoot, registry: registry)
        try self.init(registry: registry, schemaURL: schemaURL, coordinator: coordinator, adapter: adapter)
    }

    /// Convenience initializer for callers running from the checked-out
    /// repository. Tests and embedding callers should prefer an explicit URL.
    public init(
        registry: EffectRegistry,
        runtimeRoot: URL,
        adapter: CommandSessionAdapter = .offline
    ) throws {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("schemas/effect-plan.schema.json"),
            URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("schemas/effect-plan.schema.json")
        ]
        guard let schemaURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw PlanSchemaValidationError.schemaUnreadable("EffectPlan schema not found")
        }
        try self.init(registry: registry, schemaURL: schemaURL, runtimeRoot: runtimeRoot, adapter: adapter)
    }

    public func state() -> PanelState {
        panel
    }

    /// Alias useful to UI bindings that call the value a snapshot.
    public func snapshot() -> PanelState { panel }

    /// Plan a command through parser, registry, semantic validation, and the
    /// checked-in JSON schema. The coordinator records this as a previewable
    /// plan; this is lifecycle bookkeeping, not a rendered media preview.
    @discardableResult
    public func plan(
        command: String,
        selection: SelectionToken,
        target: Target? = nil,
        operationID: UUID = UUID()
    ) async throws -> PanelState {
        panel = PanelState(commandText: command, selectedClipSummary: SelectedClipSummary(selection: selection), normalizedTarget: target)
        activePlan = nil
        activeRecord = nil

        do {
            guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CommandSessionError.missingCommand }
            let interpretation: RequestInterpretation
            do {
                interpretation = try planner.parser.parse(command)
            } catch let error as PlannerError {
                throw CommandSessionError.unsupportedRequest(error.localizedDescription)
            }
            if interpretation.effectID == .targetedRotateZoom && target == nil {
                throw CommandSessionError.missingRequiredTarget
            }
            guard let effectID = interpretation.effectID else {
                throw CommandSessionError.unsupportedRequest("no supported Phase 1 workflow matched")
            }

            let plan: EffectPlan
            do {
                plan = try planner.plan(request: command, selection: selection, target: target, operationID: operationID)
            } catch let error as PlannerError {
                switch error {
                case .invalidSelection(let reason): throw CommandSessionError.invalidSelection(reason)
                case .validation(let validation): throw CommandSessionError.planValidation(validation.localizedDescription)
                case .noMatch, .ambiguous, .unsafeRequest:
                    throw CommandSessionError.unsupportedRequest(error.localizedDescription)
                }
            } catch {
                throw CommandSessionError.planValidation(error.localizedDescription)
            }

            let encoded: Data
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                encoded = try encoder.encode(plan)
                try schemaValidator.validate(encoded)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let roundTrip = try decoder.decode(EffectPlan.self, from: encoded)
                try PlanValidator(registry: registry).validate(roundTrip)
            } catch let error as PlanSchemaValidationError {
                throw CommandSessionError.schemaValidation(error.localizedDescription)
            } catch let error as PlanValidationError {
                throw CommandSessionError.planValidation(error.localizedDescription)
            } catch {
                throw CommandSessionError.schemaValidation(error.localizedDescription)
            }

            let record: JobRecord
            do {
                record = try await coordinator.preview(plan: plan)
            } catch {
                throw CommandSessionError.jobCoordinator(error.localizedDescription)
            }
            activePlan = plan
            activeRecord = record
            await refreshPanel(error: nil)
            // Keep the explicit effect binding alive for source-level readers
            // and fail closed if a future parser ever yields a different one.
            guard plan.effectID == effectID else { throw CommandSessionError.unsupportedRequest("effect resolution changed during planning") }
            return panel
        } catch let error as CommandSessionError {
            activePlan = nil
            activeRecord = nil
            await refreshPanel(error: issue(for: error))
            throw error
        } catch {
            let wrapped = CommandSessionError.planValidation(error.localizedDescription)
            activePlan = nil
            activeRecord = nil
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
    }

    /// Re-read the coordinator lifecycle record and capability gate without
    /// changing the plan. Useful after a host selection/revision update.
    @discardableResult
    public func refresh() async -> PanelState {
        await refreshPanel(error: panel.error)
        return panel
    }

    /// Preview is intentionally plan-only in Phase 1. Planning already records
    /// the coordinator's `.previewed` lifecycle state, so this operation is
    /// idempotent and does not render or mutate media.
    @discardableResult
    public func preview() async throws -> PanelState {
        guard let plan = activePlan else {
            let error = CommandSessionError.noPlan
            await refreshPanel(error: issue(for: error))
            throw error
        }
        do {
            activeRecord = try await coordinator.preview(plan: plan)
            await refreshPanel(error: nil)
            return panel
        } catch {
            let wrapped = CommandSessionError.jobCoordinator(error.localizedDescription)
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
    }

    @discardableResult
    public func cancel() async throws -> PanelState {
        guard let plan = activePlan, let record = activeRecord else {
            let error = CommandSessionError.noPlan
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard record.state == .planned || record.state == .previewed else {
            let error = CommandSessionError.cancellationDenied("operation is already \(record.state.rawValue)")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        do {
            activeRecord = try await coordinator.cancel(operationID: plan.operationID)
            await refreshPanel(error: nil)
            return panel
        } catch {
            let wrapped = CommandSessionError.cancellationDenied(error.localizedDescription)
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
    }

    @discardableResult
    public func apply() async throws -> PanelState {
        guard let plan = activePlan, let record = activeRecord else {
            let error = CommandSessionError.noPlan
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard record.state == .planned || record.state == .previewed else {
            let error = CommandSessionError.capabilityDenied("operation is already \(record.state.rawValue)")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard adapter.capability.exactEffectSupport, adapter.capability.supportedEffects.contains(plan.effectID) else {
            let error = CommandSessionError.capabilityDenied("exact support for \(plan.effectID.rawValue) was not proven")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard adapter.canMutate else {
            let error = CommandSessionError.capabilityDenied("no mutation adapter was injected")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        let actualRevision: String
        do {
            guard let revision = try adapter.currentRevision() else {
                throw CommandSessionError.capabilityDenied("a current revision was not proven")
            }
            actualRevision = revision
        } catch let error as CommandSessionError {
            await refreshPanel(error: issue(for: error))
            throw error
        } catch {
            let wrapped = CommandSessionError.capabilityDenied("current revision could not be read: \(error.localizedDescription)")
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
        guard actualRevision == plan.preconditionRevision else {
            let error = CommandSessionError.staleRevision(expected: plan.preconditionRevision, actual: actualRevision)
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard adapter.capability.proves(effect: plan.effectID, revision: actualRevision) else {
            let error = CommandSessionError.capabilityDenied("the adapter capability is not current for \(plan.effectID.rawValue)")
            await refreshPanel(error: issue(for: error))
            throw error
        }

        let adapterForApply = adapter
        do {
            activeRecord = try await coordinator.apply(
                plan: plan,
                revisionProvider: {
                    guard let revision = try adapterForApply.currentRevision() else {
                        throw CommandSessionError.capabilityDenied("a current revision was not proven")
                    }
                    return revision
                },
                beforeSnapshotHash: try adapterForApply.beforeSnapshotHash(for: plan),
                mutation: { try adapterForApply.apply(plan) }
            )
            await refreshPanel(error: nil)
            return panel
        } catch let error as JobCoordinatorError {
            activeRecord = await coordinator.record(operationID: plan.operationID)
            let wrapped: CommandSessionError = {
                if case .staleRevision(let expected, let actual) = error {
                    return .staleRevision(expected: expected, actual: actual)
                }
                return .jobCoordinator(error.localizedDescription)
            }()
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        } catch let error as CommandSessionError {
            activeRecord = await coordinator.record(operationID: plan.operationID)
            let wrapped = error
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        } catch {
            activeRecord = await coordinator.record(operationID: plan.operationID)
            let wrapped = CommandSessionError.adapterRejected(error.localizedDescription)
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
    }

    @discardableResult
    public func undo() async throws -> PanelState {
        guard let plan = activePlan, let record = activeRecord else {
            let error = CommandSessionError.noPlan
            await refreshPanel(error: issue(for: error))
            throw error
        }
        if record.state == .undone {
            await refreshPanel(error: nil)
            return panel
        }
        guard record.state == .applied else {
            let error = CommandSessionError.undoUnavailable("operation is already \(record.state.rawValue)")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard adapter.capability.exactEffectSupport,
              adapter.capability.supportedEffects.contains(plan.effectID),
              adapter.capability.undoSupport else {
            let error = CommandSessionError.undoUnavailable("exact undo support for \(plan.effectID.rawValue) was not proven")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard adapter.canUndo else {
            let error = CommandSessionError.undoUnavailable("no verified undo adapter was injected")
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard let evidence = record.verifiedEvidence,
              evidence.verified, !evidence.evidenceID.isEmpty, !evidence.afterSnapshotHash.isEmpty,
              let postRevision = evidence.postMutationRevision,
              !postRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let error = CommandSessionError.undoUnavailable("verified apply evidence has no complete post-mutation revision")
            await refreshPanel(error: issue(for: error))
            throw error
        }

        let currentRevision: String
        do {
            guard let revision = try adapter.currentRevision() else {
                throw CommandSessionError.undoUnavailable("a current revision was not proven")
            }
            currentRevision = revision
        } catch let error as CommandSessionError {
            await refreshPanel(error: issue(for: error))
            throw error
        } catch {
            let wrapped = CommandSessionError.undoUnavailable("current revision could not be read: \(error.localizedDescription)")
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
        guard currentRevision == postRevision else {
            let error = CommandSessionError.staleRevision(expected: postRevision, actual: currentRevision)
            await refreshPanel(error: issue(for: error))
            throw error
        }
        guard await coordinator.canUndo(operationID: plan.operationID, currentRevision: currentRevision) else {
            let error = CommandSessionError.undoUnavailable("rollback payload or current adapter capability is not valid for undo")
            await refreshPanel(error: issue(for: error))
            throw error
        }

        let adapterForUndo = adapter
        do {
            activeRecord = try await coordinator.undo(
                plan: plan,
                revisionProvider: {
                    guard let revision = try adapterForUndo.currentRevision() else {
                        throw CommandSessionError.undoUnavailable("a current revision was not proven")
                    }
                    return revision
                },
                mutation: { try adapterForUndo.undo($0) }
            )
            await refreshPanel(error: nil)
            return panel
        } catch let error as JobCoordinatorError {
            activeRecord = await coordinator.record(operationID: plan.operationID)
            let wrapped: CommandSessionError = {
                if case .staleRevision(let expected, let actual) = error {
                    return .staleRevision(expected: expected, actual: actual)
                }
                if case .undoUnavailable(let reason) = error {
                    return .undoUnavailable(reason)
                }
                return .jobCoordinator(error.localizedDescription)
            }()
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        } catch let error as CommandSessionError {
            activeRecord = await coordinator.record(operationID: plan.operationID)
            await refreshPanel(error: issue(for: error))
            throw error
        } catch {
            activeRecord = await coordinator.record(operationID: plan.operationID)
            let wrapped = CommandSessionError.adapterRejected(error.localizedDescription)
            await refreshPanel(error: issue(for: wrapped))
            throw wrapped
        }
    }

    private func refreshPanel(error: PanelIssue?) async {
        if let plan = activePlan {
            activeRecord = await coordinator.record(operationID: plan.operationID) ?? activeRecord
        }
        let history = await coordinator.history()
        let recordState = activeRecord?.state
        let previewStatus: PanelPreviewStatus
        switch recordState {
        case .previewed, .planned: previewStatus = .ready
        case .applying: previewStatus = .applying
        case .applied: previewStatus = .applied
        case .undoing: previewStatus = .undoing
        case .undone: previewStatus = .undone
        case .cancelled: previewStatus = .cancelled
        case .failed, .rollbackRequired: previewStatus = .failed
        case nil: previewStatus = .unavailable
        }
        let editability = activePlan.map { editabilitySummary(for: $0) } ?? PanelEditabilitySummary()
        let currentRevision: String?
        do { currentRevision = try adapter.currentRevision() }
        catch { currentRevision = nil }
        let canApply: Bool
        if let plan = activePlan, let state = recordState, (state == .planned || state == .previewed), let currentRevision {
            canApply = adapter.canMutate && currentRevision == plan.preconditionRevision && adapter.capability.proves(effect: plan.effectID, revision: currentRevision)
        } else {
            canApply = false
        }
        let canUndo: Bool
        if let plan = activePlan, let state = recordState, state == .applied,
           adapter.canUndo,
           adapter.capability.undoSupport,
           adapter.capability.exactEffectSupport,
           adapter.capability.supportedEffects.contains(plan.effectID),
           let currentRevision,
           !currentRevision.isEmpty {
            canUndo = await coordinator.canUndo(operationID: plan.operationID, currentRevision: currentRevision)
        } else {
            canUndo = false
        }
        panel = PanelState(
            commandText: panel.commandText,
            selectedClipSummary: panel.selectedClipSummary,
            normalizedTarget: activePlan?.normalizedPoint ?? panel.normalizedTarget,
            plan: activePlan,
            editability: editability,
            previewStrategy: activePlan?.previewStrategy,
            previewStatus: previewStatus,
            previewRendered: false,
            applyEnabled: canApply,
            cancelEnabled: recordState == .planned || recordState == .previewed,
            undoEnabled: canUndo,
            jobState: recordState,
            history: history,
            error: error
        )
    }

    private func editabilitySummary(for plan: EffectPlan) -> PanelEditabilitySummary {
        // `EffectPlan.editableProperties` is legacy metadata, not presentation
        // truth. The current registry parameter exposure is the sole liveness
        // authority. A missing definition fails closed to no editable labels.
        let editable = (try? registry.definition(for: plan.effectID))?.parameters.compactMap { parameter in
            (parameter.presentation ?? .failClosed).exposure.isEditable ? parameter.name : nil
        } ?? []
        let baked = plan.generatedAssets.map(\.kind)
        let editableLabels = editable.map { PanelEditabilityLabel(value: $0, classification: .editable) }
        let bakedLabels = baked.map { PanelEditabilityLabel(value: $0, classification: .baked) }
        return PanelEditabilitySummary(editable: editable, baked: baked, labels: editableLabels + bakedLabels)
    }

    private func issue(for error: CommandSessionError) -> PanelIssue {
        let code: PanelIssue.Code
        switch error {
        case .missingCommand: code = .missingCommand
        case .unsupportedRequest: code = .unsupportedRequest
        case .missingRequiredTarget: code = .missingRequiredTarget
        case .invalidSelection: code = .invalidSelection
        case .schemaValidation: code = .schemaValidation
        case .planValidation: code = .planValidation
        case .capabilityDenied: code = .capabilityDenied
        case .staleRevision: code = .staleRevision
        case .noPlan: code = .noPlan
        case .cancellationDenied: code = .cancellationDenied
        case .undoUnavailable: code = .undoUnavailable
        case .adapterRejected: code = .adapterRejected
        case .jobCoordinator: code = .jobCoordinator
        }
        return PanelIssue(code: code, message: error.localizedDescription, operationID: activePlan?.operationID)
    }

}
