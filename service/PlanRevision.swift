import Foundation

public enum PlanRevisionError: Error, LocalizedError, Equatable, Sendable {
    case unknownParameter(String), readOnly(String), invalid(String)
    public var errorDescription: String? {
        switch self { case .unknownParameter(let n): return "Unknown parameter: \(n)"; case .readOnly(let n): return "\(n) is read-only in this construction"; case .invalid(let m): return m }
    }
}

/// Atomic, typed parameter revision. No mutation is made until all validation,
/// schema admission, media correspondence and capability decisions succeed.
public struct LocalMediaPlanRevisionService {
    public let registry: EffectRegistry
    public let schemaValidator: PlanSchemaValidator?
    public let capabilityGate: CapabilityGate
    public let catalog: StandaloneEmitterCatalog

    public init(registry: EffectRegistry, schemaValidator: PlanSchemaValidator? = nil, capabilityGate: CapabilityGate = CapabilityGate(), catalog: StandaloneEmitterCatalog = StandaloneEmitterCatalog()) {
        self.registry = registry; self.schemaValidator = schemaValidator; self.capabilityGate = capabilityGate; self.catalog = catalog
    }

    public func revise(_ result: LocalMediaPlanningResult, patch: [String: ParameterValue]) throws -> LocalMediaPlanningResult {
        let definition = try registry.definition(for: result.plan.effectID)
        var plan = result.plan
        for (name, value) in patch {
            guard let parameter = definition.parameters.first(where: { $0.name == name }) else { throw PlanRevisionError.unknownParameter(name) }
            guard (parameter.presentation ?? .failClosed).exposure.isEditable else { throw PlanRevisionError.readOnly(name) }
            plan.parameters[name] = value
        }
        // Direction is a legacy-derived compatibility value, not a control.
        if patch["direction"] != nil { throw PlanRevisionError.readOnly("direction") }
        if plan.effectID == .targetedRotateZoom,
           let start = plan.parameters["rotationStartDegrees"]?.numberValue,
           let end = plan.parameters["rotationEndDegrees"]?.numberValue {
            plan.parameters["direction"] = .string(end - start > 0 ? "counterclockwise" : "clockwise")
        }
        plan.operationID = UUID() // only after the prospective revision is built
        do { try PlanValidator(registry: registry).validate(plan) }
        catch { throw PlanRevisionError.invalid(error.localizedDescription) }
        let encoded = try JSONEncoder().encode(plan)
        do { try schemaValidator?.validate(encoded) } catch { throw PlanRevisionError.invalid(error.localizedDescription) }
        let admission: EffectPlanAdmissionResult
        do { admission = try EffectPlanAdmission.decode(encoded) } catch { throw PlanRevisionError.invalid(error.localizedDescription) }

        let assets = Dictionary(uniqueKeysWithValues: result.selection.slots.map { ($0.role, $0.media) })
        guard assets.values.allSatisfy({ asset in result.plan.selectionToken.sourceIdentities.contains(asset.sourceIdentity) }) else { throw PlanRevisionError.invalid("selection media correspondence failed") }
        let evidence = AdmittedLocalMediaEvidence(admittedAssets: result.selection.slots.map(\.media))
        let standalone: CapabilityDecision
        if let reason = catalog.absenceReason(for: plan.effectID) {
            standalone = CapabilityDecision(capability: .standaloneFCPXMLExport, allowed: false, reason: reason)
        } else if let evidence {
            standalone = capabilityGate.decision(for: admission, capability: .standaloneFCPXMLExport, mediaEvidence: evidence)
        } else { standalone = CapabilityDecision(capability: .standaloneFCPXMLExport, allowed: false, reason: "No admitted local media") }
        return LocalMediaPlanningResult(plan: plan, admission: admission, selection: result.selection, inputs: result.inputs,
            localPreviewDecision: capabilityGate.decision(for: admission, capability: .localOnlyPreview),
            inertPackageDecision: capabilityGate.decision(for: admission, capability: .inertPayloadNeutralPackage),
            fcpxmlExportDecision: capabilityGate.decision(for: admission, capability: .fcpxmlExport),
            standaloneExportDecision: standalone, baselineParameters: result.baselineParameters)
    }

    public func reset(_ result: LocalMediaPlanningResult, parameter: String) throws -> LocalMediaPlanningResult {
        guard let value = result.baselineParameters[parameter] else { throw PlanRevisionError.unknownParameter(parameter) }
        return try revise(result, patch: [parameter: value])
    }

    public func resetAllCreative(_ result: LocalMediaPlanningResult) throws -> LocalMediaPlanningResult {
        let definition = try registry.definition(for: result.plan.effectID)
        let patch = Dictionary(uniqueKeysWithValues: definition.parameters.compactMap { parameter -> (String, ParameterValue)? in
            (parameter.presentation ?? .failClosed).exposure.isEditable ? result.baselineParameters[parameter.name].map { (parameter.name, $0) } : nil
        })
        return try revise(result, patch: patch)
    }
}
