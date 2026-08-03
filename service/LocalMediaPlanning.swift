import Foundation

/// The result of local deterministic planning. It deliberately retains the
/// capability decisions instead of letting any UI reimplement export policy.
public struct LocalMediaPlanningResult: Equatable, Sendable {
    public let plan: EffectPlan
    public let admission: EffectPlanAdmissionResult
    public let selection: LocalMediaSelection
    public let localPreviewDecision: CapabilityDecision
    public let inertPackageDecision: CapabilityDecision
    public let fcpxmlExportDecision: CapabilityDecision

    public init(plan: EffectPlan, admission: EffectPlanAdmissionResult, selection: LocalMediaSelection, localPreviewDecision: CapabilityDecision, inertPackageDecision: CapabilityDecision, fcpxmlExportDecision: CapabilityDecision) {
        self.plan = plan
        self.admission = admission
        self.selection = selection
        self.localPreviewDecision = localPreviewDecision
        self.inertPackageDecision = inertPackageDecision
        self.fcpxmlExportDecision = fcpxmlExportDecision
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
        return LocalMediaPlanningResult(
            plan: effectPlan,
            admission: admission,
            selection: selection,
            localPreviewDecision: capabilityGate.decision(for: admission, capability: .localOnlyPreview),
            inertPackageDecision: capabilityGate.decision(for: admission, capability: .inertPayloadNeutralPackage),
            fcpxmlExportDecision: capabilityGate.decision(for: admission, capability: .fcpxmlExport)
        )
    }
}
