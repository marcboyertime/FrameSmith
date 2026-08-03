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

public enum ManualFCPXMLSemanticsEvidence: String, Codable, Equatable, Sendable {
    case unknown
    case verified
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
    case manualFCPXMLSemanticsUnknown(FCPCommandConsoleCapability)

    public var errorDescription: String? {
        switch self {
        case .migrationRequired: return "Legacy effect plans are quarantined and must be replanned as schema 2.0"
        case .invalidCurrentPlanSchema(let version): return "Capability requires a current schema 2.0 plan, got \(version)"
        case .manualFCPXMLSemanticsUnknown(let capability): return "\(capability.rawValue) is blocked until manual FCPXML semantics evidence is verified"
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
            guard manualSemanticsEvidence == .verified else {
                return CapabilityDecision(capability: capability, allowed: false, reason: "Manual FCPXML semantics evidence remains unknown")
            }
            return CapabilityDecision(capability: capability, allowed: true, reason: "Manual FCPXML semantics evidence is verified")
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
        guard decision(for: plan, capability: capability).allowed else {
            throw CapabilityGateError.manualFCPXMLSemanticsUnknown(capability)
        }
    }
}
