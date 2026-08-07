import Foundation

/// Everything a plan was derived from.
///
/// A plan is internally consistent with its own selection token, so no check
/// inside it can notice that the operator has since retyped the command, moved
/// the target point, or filled another role slot. Recording the inputs beside
/// the plan is what lets a caller detect that drift and refuse to package a
/// plan that no longer describes the current request. Unused role slots are
/// captured too: adding an `outgoing` source to a single-clip workflow changes
/// what a replan would produce even though the current plan ignores it.
public struct LocalMediaPlanInputs: Equatable, Sendable {
    public let request: String
    public let target: Target?
    public let sources: [LocalMediaRole: SourceIdentity]

    public init(request: String, target: Target?, primary: LocalMediaAsset?, outgoing: LocalMediaAsset?, incoming: LocalMediaAsset?) {
        self.request = request
        self.target = target
        var sources: [LocalMediaRole: SourceIdentity] = [:]
        sources[.primary] = primary?.sourceIdentity
        sources[.outgoing] = outgoing?.sourceIdentity
        sources[.incoming] = incoming?.sourceIdentity
        self.sources = sources
    }

    /// The first difference against a later set of inputs, in a fixed order so
    /// the same drift always reports the same reason.
    public func drift(against current: LocalMediaPlanInputs) -> LocalMediaPlanStaleness? {
        if request != current.request { return .commandChanged }
        if target != current.target { return .targetChanged }
        for role in LocalMediaRole.allCases {
            switch (sources[role], current.sources[role]) {
            case (nil, nil): continue
            case (nil, .some): return .sourceAdded(role)
            case (.some, nil): return .sourceRemoved(role)
            case (.some(let planned), .some(let now)): if planned != now { return .sourceChanged(role) }
            }
        }
        return nil
    }
}

public enum LocalMediaPlanStaleness: Equatable, Sendable {
    case commandChanged
    case targetChanged
    case sourceChanged(LocalMediaRole)
    case sourceAdded(LocalMediaRole)
    case sourceRemoved(LocalMediaRole)

    public var reason: String {
        switch self {
        case .commandChanged: return "The command changed after this plan was made. Plan again before saving a package."
        case .targetChanged: return "The target point changed after this plan was made. Plan again before saving a package."
        case .sourceChanged(let role): return "The \(role.rawValue) source changed after this plan was made. Plan again before saving a package."
        case .sourceAdded(let role): return "A \(role.rawValue) source was added after this plan was made. Plan again before saving a package."
        case .sourceRemoved(let role): return "The \(role.rawValue) source was removed after this plan was made. Plan again before saving a package."
        }
    }
}

/// The result of local deterministic planning. It deliberately retains the
/// capability decisions instead of letting any UI reimplement export policy,
/// and the inputs so no UI has to remember what the plan was made from.
public struct LocalMediaPlanningResult: Equatable, Sendable {
    public let plan: EffectPlan
    public let admission: EffectPlanAdmissionResult
    public let selection: LocalMediaSelection
    public let inputs: LocalMediaPlanInputs
    public let localPreviewDecision: CapabilityDecision
    public let inertPackageDecision: CapabilityDecision
    public let fcpxmlExportDecision: CapabilityDecision
    /// Whether a **new** Final Cut project may be generated from this plan.
    ///
    /// Distinct from `fcpxmlExportDecision`, which asks whether an *existing*
    /// timeline may be modified and can never be satisfied by local media. A UI
    /// that conflated the two would show the user a refusal for the thing they
    /// can actually do.
    public let standaloneExportDecision: CapabilityDecision

    public init(
        plan: EffectPlan,
        admission: EffectPlanAdmissionResult,
        selection: LocalMediaSelection,
        inputs: LocalMediaPlanInputs,
        localPreviewDecision: CapabilityDecision,
        inertPackageDecision: CapabilityDecision,
        fcpxmlExportDecision: CapabilityDecision,
        standaloneExportDecision: CapabilityDecision = CapabilityDecision(
            capability: .standaloneFCPXMLExport,
            allowed: false,
            reason: "Standalone export was not evaluated for this plan"
        )
    ) {
        self.plan = plan
        self.admission = admission
        self.selection = selection
        self.inputs = inputs
        self.localPreviewDecision = localPreviewDecision
        self.inertPackageDecision = inertPackageDecision
        self.fcpxmlExportDecision = fcpxmlExportDecision
        self.standaloneExportDecision = standaloneExportDecision
    }

    /// Reports the first way the live inputs have drifted from the ones this
    /// plan was built from, or `nil` when the plan is still current.
    public func staleness(against current: LocalMediaPlanInputs) -> LocalMediaPlanStaleness? {
        inputs.drift(against: current)
    }
}

public struct LocalMediaPlannerSession {
    public let registry: EffectRegistry
    public let schemaValidator: PlanSchemaValidator?
    public let capabilityGate: CapabilityGate

    public init(registry: EffectRegistry, schemaValidator: PlanSchemaValidator? = nil, capabilityGate: CapabilityGate = CapabilityGate()) {
        self.registry = registry
        self.schemaValidator = schemaValidator
        self.capabilityGate = capabilityGate
    }

    public func plan(request: String, primary: LocalMediaAsset?, outgoing: LocalMediaAsset?, incoming: LocalMediaAsset?, target: Target?) throws -> LocalMediaPlanningResult {
        let parser = DeterministicRequestParser(registry: registry)
        let interpretation = try parser.parse(request)
        guard let effectID = interpretation.effectID else { throw PlannerError.noMatch }
        let selection = try LocalMediaSelection(effectID: effectID, primary: primary, outgoing: outgoing, incoming: incoming)
        let effectPlan = try DeterministicPlanner(registry: registry).plan(request: request, selection: selection.token, target: target)
        let encoded = try JSONEncoder().encode(effectPlan)
        try schemaValidator?.validate(encoded)
        let admission = try EffectPlanAdmission.decode(encoded)

        // Evidence is minted here from the assets that actually came through
        // admission, never reconstructed from the plan. A plan is only a
        // description of media; it is not proof any of it was admitted.
        let admittedAssets = [primary, outgoing, incoming].compactMap { $0 }
        let standaloneDecision: CapabilityDecision
        if let mediaEvidence = AdmittedLocalMediaEvidence(admittedAssets: admittedAssets) {
            standaloneDecision = capabilityGate.decision(
                for: admission,
                capability: .standaloneFCPXMLExport,
                mediaEvidence: mediaEvidence
            )
        } else {
            standaloneDecision = CapabilityDecision(
                capability: .standaloneFCPXMLExport,
                allowed: false,
                reason: "No admitted local media to generate a project from"
            )
        }

        return LocalMediaPlanningResult(
            plan: effectPlan,
            admission: admission,
            selection: selection,
            inputs: LocalMediaPlanInputs(request: request, target: target, primary: primary, outgoing: outgoing, incoming: incoming),
            localPreviewDecision: capabilityGate.decision(for: admission, capability: .localOnlyPreview),
            inertPackageDecision: capabilityGate.decision(for: admission, capability: .inertPayloadNeutralPackage),
            fcpxmlExportDecision: capabilityGate.decision(for: admission, capability: .fcpxmlExport),
            standaloneExportDecision: standaloneDecision
        )
    }
}
