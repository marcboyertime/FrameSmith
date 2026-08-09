import Foundation

/// The user-visible state machine for the deliberately narrow first editorial
/// workflow. It is UI-free so every button reaches the same admission and
/// drift boundary instead of reimplementing a safety check in SwiftUI.
public struct EditorialTreatmentInputSnapshot: Equatable, Sendable {
    public let command: String
    public let primary: SourceIdentity?
    public let outgoing: SourceIdentity?
    public let incoming: SourceIdentity?
    public let overlay: SourceIdentity?
    public let target: Target?
    public let durationFrames: Int?
    public let capabilityDigest: String
    public let catalogDigest: String
    public let schemaDigest: String
    public let registryDigest: String

    public init(command: String, media: [LocalMediaRole: LocalMediaAsset], target: Target?, durationFrames: Int?, admittedCapabilities: Set<String>, catalog: EditorialKnowledgeCatalog, schemaDigest: String, registry: EffectRegistry) {
        self.command = command
        primary = media[.primary]?.sourceIdentity; outgoing = media[.outgoing]?.sourceIdentity
        incoming = media[.incoming]?.sourceIdentity; overlay = media[.overlay]?.sourceIdentity
        self.target = target; self.durationFrames = durationFrames
        capabilityDigest = TreatmentIdentity.digest(admittedCapabilities.sorted())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        catalogDigest = ContentHasher.sha256((try? encoder.encode(catalog.cards)) ?? Data())
        self.schemaDigest = schemaDigest
        registryDigest = ContentHasher.sha256((try? encoder.encode(registry.all)) ?? Data())
    }
}

public enum EditorialTreatmentWorkflowError: Error, LocalizedError, Equatable, Sendable {
    case durationRequired
    case unsupportedScope(String)
    case drifted(String)
    case unknownOption(String)
    case comparisonLimit
    case noAppliedTreatment

    public var errorDescription: String? {
        switch self {
        case .durationRequired: return "Enter a positive editorial duration in frames before using Surprise Me. No duration has been invented for you."
        case .unsupportedScope(let detail): return "Surprise Me currently supports one admitted primary still only: \(detail)"
        case .drifted(let reason): return "Editorial treatments were invalidated: \(reason). Generate and admit fresh options before continuing."
        case .unknownOption(let id): return "That treatment option is not currently admitted: \(id)"
        case .comparisonLimit: return "Compare supports at most three admitted treatment options."
        case .noAppliedTreatment: return "Choose an admitted treatment before refining it."
        }
    }
}

public struct EditorialTreatmentWorkflow {
    public struct State {
        public var snapshot: EditorialTreatmentInputSnapshot?
        public var lock: EditorialStructureLock?
        public var options: [String: AdmittedTreatmentExecution] = [:]
        public var applied: AdmittedTreatmentExecution?
        public var comparisonIDs: [String] = []
        public var history: [AdmittedTreatmentExecution] = []
        /// Candidates the generator considered but admission refused.  Keep
        /// these alongside generator rejections so a short list is explained,
        /// rather than silently discarding a duration-locked construction.
        public var rejected: [RejectedCandidate] = []
        public var shortfallExplanation: String?
        public var invalidationReason: String?
        public init() {}
    }

    public let catalog: EditorialKnowledgeCatalog
    public let registry: EffectRegistry
    public let admittedCapabilities: Set<String>
    public let schemaValidator: PlanSchemaValidator?
    public let treatmentContractValidator: TreatmentPlanContractValidator?
    public let capabilityGate: CapabilityGate

    public init(catalog: EditorialKnowledgeCatalog, registry: EffectRegistry, admittedCapabilities: Set<String>, schemaValidator: PlanSchemaValidator?, treatmentContractValidator: TreatmentPlanContractValidator?, capabilityGate: CapabilityGate) {
        self.catalog = catalog; self.registry = registry; self.admittedCapabilities = admittedCapabilities
        self.schemaValidator = schemaValidator; self.treatmentContractValidator = treatmentContractValidator; self.capabilityGate = capabilityGate
    }

    public func snapshot(command: String, media: [LocalMediaRole: LocalMediaAsset], target: Target?, durationFrames: Int?) -> EditorialTreatmentInputSnapshot {
        EditorialTreatmentInputSnapshot(command: command, media: media, target: target, durationFrames: durationFrames, admittedCapabilities: admittedCapabilities, catalog: catalog, schemaDigest: treatmentContractValidator?.schemaDigest ?? "missing-treatment-schema", registry: registry)
    }

    public mutating func invalidateIfDrifted(_ state: inout State, current: EditorialTreatmentInputSnapshot) -> String? {
        guard let snapshot = state.snapshot, snapshot != current else { return nil }
        let reason = driftReason(snapshot, current)
        state.options = [:]; state.applied = nil; state.comparisonIDs = []; state.history = []
        state.rejected = []; state.shortfallExplanation = nil
        state.snapshot = nil; state.lock = nil; state.invalidationReason = reason
        return reason
    }

    public mutating func generate(
        state: inout State,
        command: String,
        media: [LocalMediaRole: LocalMediaAsset],
        target: Target?,
        durationFrames: Int?,
        basePlans: [EffectID: EffectPlan]
    ) throws -> [AdmittedTreatmentExecution] {
        // A new generation attempt must never leave an old authoritative
        // option set usable.  The successful result replaces this cleared
        // state in one assignment below; validation failures stay empty.
        state = State()
        guard let frames = durationFrames, frames > 0 else { throw EditorialTreatmentWorkflowError.durationRequired }
        guard let primary = media[.primary], primary.kind == .still else { throw EditorialTreatmentWorkflowError.unsupportedScope("add one admitted still as Primary") }
        guard media[.outgoing] == nil, media[.incoming] == nil else { throw EditorialTreatmentWorkflowError.unsupportedScope("outgoing and incoming clips are not supported in this first still-only release") }
        let lock = EditorialStructureLock.establish(orderedMedia: [primary], clipDurationFrames: [frames], frameRate: 30)
        let current = snapshot(command: command, media: media, target: target, durationFrames: frames)
        let generator = TreatmentOptionGenerator(catalog: catalog, admittedCapabilities: admittedCapabilities, maximumOptions: 3)
        let set = generator.generate(lock: lock, media: media, intent: TreatmentIntent(originalWording: command.isEmpty ? "surprise me" : command, intensity: .restrained), basePlans: basePlans)
        let admission = TreatmentAdmission(lock: lock, catalog: catalog, admittedCapabilities: admittedCapabilities, registry: registry, treatmentContractValidator: treatmentContractValidator)
        var admitted: [AdmittedTreatmentExecution] = []
        var rejected = set.rejected
        for option in set.options {
            // A candidate may carry a fixed or unsupported duration (for
            // example the measured 4-second CRT base) while another candidate
            // exactly matches the director's lock. Admit each independently:
            // one refusal is evidence for a shortfall, never a reason to
            // discard a valid treatment set.
            do {
                admitted.append(try admission.admit(option, currentStructure: lock, media: media, impactEvidence: []))
            } catch {
                rejected.append(.init(name: option.name, reason: .techniqueUnavailable("admission refused: \(error.localizedDescription)")))
            }
        }
        let shortfall = admissionShortfall(
            count: admitted.count,
            generatorExplanation: set.shortfallExplanation,
            rejected: rejected
        )
        var replacement = State()
        replacement.snapshot = current
        replacement.lock = lock
        replacement.options = Dictionary(uniqueKeysWithValues: admitted.map { ($0.treatment.optionID, $0) })
        replacement.rejected = rejected
        replacement.shortfallExplanation = shortfall
        replacement.invalidationReason = admitted.isEmpty ? (shortfall ?? "No option could be admitted for this still.") : nil
        state = replacement
        return admitted
    }

    private func admissionShortfall(count: Int, generatorExplanation: String?, rejected: [RejectedCandidate]) -> String? {
        guard count < 3 else { return nil }
        let admissionRefusals = rejected.filter {
            if case .techniqueUnavailable(let detail) = $0.reason { return detail.hasPrefix("admission refused:") }
            return false
        }
        if !admissionRefusals.isEmpty {
            let names = admissionRefusals.map(\.name).sorted().joined(separator: ", ")
            return "Showing \(count) options rather than 3 because \(names) could not be admitted against the director-locked duration. Padding the list with near-duplicates would waste your attention."
        }
        return generatorExplanation ?? "Showing \(count) options rather than 3 because no additional candidate was safely available. Padding the list with near-duplicates would waste your attention."
    }

    /// Re-admits this exact artifact before every action. A caller gets a new
    /// immutable snapshot, never permission to keep using an old one.
    public func readmit(_ execution: AdmittedTreatmentExecution, current: EditorialTreatmentInputSnapshot, media: [LocalMediaRole: LocalMediaAsset]) throws -> AdmittedTreatmentExecution {
        guard let lock = execution.structure as EditorialStructureLock?, execution.admittedAtFingerprint == lock.fingerprint else { throw EditorialTreatmentWorkflowError.drifted("the locked structure changed") }
        guard current == snapshot(command: current.command, media: media, target: current.target, durationFrames: current.durationFrames) else { throw EditorialTreatmentWorkflowError.drifted("the current input snapshot is malformed") }
        let admission = TreatmentAdmission(lock: lock, catalog: catalog, admittedCapabilities: admittedCapabilities, registry: registry, treatmentContractValidator: treatmentContractValidator)
        return try admission.admit(execution.treatment, currentStructure: lock, media: media, impactEvidence: [])
    }

    public mutating func use(_ optionID: String, state: inout State, current: EditorialTreatmentInputSnapshot, media: [LocalMediaRole: LocalMediaAsset]) throws -> (AdmittedTreatmentExecution, LocalMediaPlanningResult) {
        guard state.snapshot == current else { throw EditorialTreatmentWorkflowError.drifted(state.invalidationReason ?? "an input or installed contract changed") }
        guard let option = state.options[optionID] else { throw EditorialTreatmentWorkflowError.unknownOption(optionID) }
        var selected = option.treatment
        selected.effectPlan = option.selectingForExecution() // minted exactly once at selection
        selected.constructionSignature = TreatmentIdentity.constructionSignature(for: selected.effectPlan)
        let readmitted = try TreatmentAdmission(lock: option.structure, catalog: catalog, admittedCapabilities: admittedCapabilities, registry: registry, treatmentContractValidator: treatmentContractValidator).admit(selected, currentStructure: option.structure, media: media, impactEvidence: [])
        let result = try LocalMediaPlannerSession(registry: registry, schemaValidator: schemaValidator, capabilityGate: capabilityGate).adopt(exactPlan: readmitted.treatment.effectPlan, request: current.command, primary: media[.primary], outgoing: media[.outgoing], incoming: media[.incoming], target: current.target)
        if let applied = state.applied { state.history.append(applied) }
        state.applied = readmitted
        return (readmitted, result)
    }

    public mutating func revise(state: inout State, current: EditorialTreatmentInputSnapshot, media: [LocalMediaRole: LocalMediaAsset], patch: [String: ParameterValue]) throws -> (AdmittedTreatmentExecution, LocalMediaPlanningResult) {
        guard state.snapshot == current else { throw EditorialTreatmentWorkflowError.drifted("an input or installed contract changed") }
        guard let applied = state.applied else { throw EditorialTreatmentWorkflowError.noAppliedTreatment }
        let baseline = try LocalMediaPlannerSession(registry: registry, schemaValidator: schemaValidator, capabilityGate: capabilityGate).adopt(exactPlan: applied.treatment.effectPlan, request: current.command, primary: media[.primary], outgoing: nil, incoming: nil, target: current.target)
        let revised = try LocalMediaPlanRevisionService(registry: registry, schemaValidator: schemaValidator, capabilityGate: capabilityGate).revise(baseline, patch: patch)
        var treatment = applied.treatment; treatment.effectPlan = revised.plan; treatment.constructionSignature = TreatmentIdentity.constructionSignature(for: revised.plan)
        let readmitted = try TreatmentAdmission(lock: applied.structure, catalog: catalog, admittedCapabilities: admittedCapabilities, registry: registry, treatmentContractValidator: treatmentContractValidator).admit(treatment, currentStructure: applied.structure, media: media, impactEvidence: [])
        state.history.append(applied); state.applied = readmitted
        return (readmitted, revised)
    }

    public mutating func restore(_ index: Int, state: inout State, current: EditorialTreatmentInputSnapshot, media: [LocalMediaRole: LocalMediaAsset]) throws -> AdmittedTreatmentExecution {
        guard state.snapshot == current else { throw EditorialTreatmentWorkflowError.drifted("an input or installed contract changed") }
        guard state.history.indices.contains(index) else { throw EditorialTreatmentWorkflowError.unknownOption("history-\(index)") }
        let old = state.history[index]
        let restored = try readmit(old, current: current, media: media)
        if let applied = state.applied { state.history.append(applied) }
        state.applied = restored
        return restored
    }

    public mutating func toggleComparison(
        _ id: String,
        state: inout State,
        current: EditorialTreatmentInputSnapshot,
        media: [LocalMediaRole: LocalMediaAsset]
    ) throws {
        guard state.snapshot == current else {
            let reason = invalidateIfDrifted(&state, current: current) ?? "an input or installed contract changed"
            throw EditorialTreatmentWorkflowError.drifted(reason)
        }
        guard state.options[id] != nil else { throw EditorialTreatmentWorkflowError.unknownOption(id) }
        if let index = state.comparisonIDs.firstIndex(of: id) { state.comparisonIDs.remove(at: index); return }
        guard state.comparisonIDs.count < 3 else { throw EditorialTreatmentWorkflowError.comparisonLimit }

        // Compare is an execution-adjacent preview action.  Re-admit every
        // member of the comparison, not merely the newly tapped card, against
        // the current structure, catalog, schema, registry, capability profile
        // and emitter construction.  A stale artifact is removed immediately.
        for candidateID in state.comparisonIDs + [id] {
            guard let candidate = state.options[candidateID] else {
                state.comparisonIDs.removeAll { $0 == candidateID }
                throw EditorialTreatmentWorkflowError.unknownOption(candidateID)
            }
            do {
                let readmitted = try readmit(candidate, current: current, media: media)
                state.options[candidateID] = readmitted
            } catch {
                clearStaleOption(candidateID, from: &state)
                throw EditorialTreatmentWorkflowError.drifted(error.localizedDescription)
            }
        }
        state.comparisonIDs.append(id)
    }

    /// Compatibility entry point for callers that have not yet supplied live
    /// UI inputs.  It still re-admits against all current in-process contracts;
    /// UI callers should use the overload above to prove current media too.
    public mutating func toggleComparison(_ id: String, state: inout State) throws {
        guard let snapshot = state.snapshot, let option = state.options[id] else {
            throw EditorialTreatmentWorkflowError.unknownOption(id)
        }
        try toggleComparison(id, state: &state, current: snapshot, media: option.media)
    }

    private func clearStaleOption(_ id: String, from state: inout State) {
        state.options.removeValue(forKey: id)
        state.comparisonIDs.removeAll { $0 == id }
        if state.applied?.treatment.optionID == id { state.applied = nil }
        state.invalidationReason = "an admitted treatment became stale during comparison"
    }

    private func driftReason(_ old: EditorialTreatmentInputSnapshot, _ new: EditorialTreatmentInputSnapshot) -> String {
        if old.command != new.command { return "the command changed" }; if old.primary != new.primary { return "the primary source identity changed" }
        if old.outgoing != new.outgoing || old.incoming != new.incoming { return "the outgoing or incoming source changed" }
        if old.overlay != new.overlay { return "the overlay source changed" }; if old.target != new.target { return "the focal target changed" }
        if old.durationFrames != new.durationFrames { return "the explicit editorial duration changed" }
        if old.capabilityDigest != new.capabilityDigest { return "the installed Final Cut capability profile changed" }
        if old.catalogDigest != new.catalogDigest { return "the source catalog changed" }; if old.schemaDigest != new.schemaDigest { return "the treatment schema changed" }
        return "the effect registry changed"
    }
}
