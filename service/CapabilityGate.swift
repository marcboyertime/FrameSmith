import Foundation

/// Domain-level capability classes. These decisions are intentionally separate
/// from UI state and from syntax validation: a DTD-valid plan is not evidence
/// that Final Cut has accepted its semantics.
public enum FCPCommandConsoleCapability: String, Codable, CaseIterable, Sendable {
    case localOnlyPreview = "local_only_preview"
    case inertPayloadNeutralPackage = "inert_payload_neutral_package"
    case fcpxmlPreview = "fcpxml_preview"
    case fcpxmlExport = "fcpxml_export"
}

/// Each contract is admitted only after manual evidence establishes that Final
/// Cut accepts that specific semantic construct.  A successful reduced
/// dissolve probe is therefore not evidence for transform, color, or overlay
/// semantics.
public enum FCPXMLSemanticContract: String, Codable, CaseIterable, Hashable, Sendable {
    case assetAdmission = "asset_admission"
    case bareDissolveTransition = "bare_dissolve_transition"
    case transformKeyframes = "transform_keyframes"
    case opacityKeyframes = "opacity_keyframes"
    case nativeColorAdjustment = "native_color_adjustment"
    case connectedOverlayLayers = "connected_overlay_layers"
}

/// The explicitly admitted subset of FCPXML semantics. An empty profile is the
/// default and means no FCPXML workflow is authorized.
public struct ManualFCPXMLSemanticsEvidence: Codable, Equatable, Sendable {
    public let admittedContracts: Set<FCPXMLSemanticContract>

    public init(admittedContracts: Set<FCPXMLSemanticContract> = []) {
        self.admittedContracts = admittedContracts
    }

    public static let unknown = ManualFCPXMLSemanticsEvidence()

    public static func requiredContracts(for effectID: EffectID) -> Set<FCPXMLSemanticContract> {
        switch effectID {
        case .naturalDissolve:
            return [.assetAdmission, .bareDissolveTransition]
        case .targetedRotateZoom:
            return [.assetAdmission, .transformKeyframes]
        case .livingStill:
            return [.assetAdmission, .transformKeyframes, .opacityKeyframes, .nativeColorAdjustment]
        case .oldTelevision:
            return [.assetAdmission, .opacityKeyframes, .nativeColorAdjustment, .connectedOverlayLayers]
        }
    }

    public func missingContracts(for effectID: EffectID) -> Set<FCPXMLSemanticContract> {
        Self.requiredContracts(for: effectID).subtracting(admittedContracts)
    }
}

public struct CapabilityDecision: Equatable, Sendable {
    public let capability: FCPCommandConsoleCapability
    public let allowed: Bool
    public let reason: String

    public init(capability: FCPCommandConsoleCapability, allowed: Bool, reason: String) {
        self.capability = capability
        self.allowed = allowed
        self.reason = reason
    }
}

public enum CapabilityGateError: Error, LocalizedError, Equatable, Sendable {
    case migrationRequired(LegacyEffectPlanQuarantine)
    case invalidCurrentPlanSchema(String)
    case missingManualFCPXMLSemanticsEvidence(
        capability: FCPCommandConsoleCapability,
        effectID: EffectID,
        missing: Set<FCPXMLSemanticContract>
    )

    public var errorDescription: String? {
        switch self {
        case .migrationRequired: return "Legacy effect plans are quarantined and must be replanned as schema 2.0"
        case .invalidCurrentPlanSchema(let version): return "Capability requires a current schema 2.0 plan, got \(version)"
        case .missingManualFCPXMLSemanticsEvidence(let capability, let effectID, let missing):
            let requirements = missing.map(\.rawValue).sorted().joined(separator: ", ")
            return "\(capability.rawValue) for \(effectID.rawValue) is blocked until manual FCPXML semantics evidence admits: \(requirements)"
        }
    }
}

public struct CapabilityGate: Sendable {
    public let manualSemanticsEvidence: ManualFCPXMLSemanticsEvidence

    public init(manualSemanticsEvidence: ManualFCPXMLSemanticsEvidence = .unknown) {
        self.manualSemanticsEvidence = manualSemanticsEvidence
    }

    public func decision(for admission: EffectPlanAdmissionResult, capability: FCPCommandConsoleCapability) -> CapabilityDecision {
        switch admission {
        case .migrationRequired:
            return CapabilityDecision(capability: capability, allowed: false, reason: "Legacy plan is quarantined; replan and validate schema 2.0")
        case .current(let plan):
            return decision(for: plan, capability: capability)
        }
    }

    public func decision(for plan: EffectPlan, capability: FCPCommandConsoleCapability) -> CapabilityDecision {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            return CapabilityDecision(capability: capability, allowed: false, reason: "Current capability admission requires schema 2.0")
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return CapabilityDecision(capability: capability, allowed: true, reason: "Current v2 plan is eligible for local-only, payload-neutral work")
        case .fcpxmlPreview, .fcpxmlExport:
            let missing = manualSemanticsEvidence.missingContracts(for: plan.effectID)
            guard missing.isEmpty else {
                let requirements = missing.map(\.rawValue).sorted().joined(separator: ", ")
                return CapabilityDecision(capability: capability, allowed: false, reason: "Manual FCPXML semantics evidence is incomplete: \(requirements)")
            }
            return CapabilityDecision(capability: capability, allowed: true, reason: "Manual FCPXML semantics evidence admits all required contracts")
        }
    }

    public func require(_ admission: EffectPlanAdmissionResult, capability: FCPCommandConsoleCapability) throws {
        if case .migrationRequired(let legacy) = admission { throw CapabilityGateError.migrationRequired(legacy) }
        if case .current(let plan) = admission { try require(plan, capability: capability) }
    }

    public func require(_ plan: EffectPlan, capability: FCPCommandConsoleCapability) throws {
        guard plan.schemaVersion == SchemaVersion.v2_0.rawValue else {
            throw CapabilityGateError.invalidCurrentPlanSchema(plan.schemaVersion)
        }
        switch capability {
        case .localOnlyPreview, .inertPayloadNeutralPackage:
            return
        case .fcpxmlPreview, .fcpxmlExport:
            let missing = manualSemanticsEvidence.missingContracts(for: plan.effectID)
            guard missing.isEmpty else {
                throw CapabilityGateError.missingManualFCPXMLSemanticsEvidence(
                    capability: capability,
                    effectID: plan.effectID,
                    missing: missing
                )
            }
        }
    }
}
