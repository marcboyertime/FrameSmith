import Foundation

/// Single semantic boundary for a plan paired with actual admitted media.
public struct ValidatedPlanExecution {
    public let registry: EffectRegistry
    public let catalog: StandaloneEmitterCatalog
    public init(registry: EffectRegistry, catalog: StandaloneEmitterCatalog = StandaloneEmitterCatalog()) { self.registry = registry; self.catalog = catalog }
    /// Roles an effect may accept but does not require.
    public static func optionalRoles(for effectID: EffectID) -> Set<LocalMediaRole> {
        switch effectID {
        case .oldTelevision: return [.overlay]
        case .livingStill, .targetedRotateZoom, .naturalDissolve: return []
        }
    }

    public func validate(plan: EffectPlan, media: [LocalMediaRole: LocalMediaAsset]) throws {
        try PlanValidator(registry: registry).validate(plan)
        let definition = try registry.definition(for: plan.effectID)
        let required: [LocalMediaRole]
        switch definition.inputCount {
        case 1: required = [.primary]
        case 2: required = [.outgoing, .incoming]
        default: throw PlanValidationError.invalidSelection("unsupported effect input count")
        }
        // Optional roles may be present or absent; required roles must match
        // exactly. Old Television's overlay is optional because its emitter
        // produces a valid base treatment without one.
        let optional = Self.optionalRoles(for: plan.effectID)
        let supplied = Set(media.keys)
        guard supplied.isSuperset(of: Set(required)), supplied.subtracting(Set(required)).isSubset(of: optional) else {
            throw PlanValidationError.invalidSelection("media roles do not match the effect")
        }
        guard plan.selectionToken.sourceIdentities.count == required.count else {
            throw PlanValidationError.invalidSelection("plan source identity count does not match the effect input count")
        }
        for (index, role) in required.enumerated() {
            guard media[role]?.sourceIdentity == plan.selectionToken.sourceIdentities[index] else {
                throw PlanValidationError.invalidSelection("admitted \(role.rawValue) media does not match the plan source identity")
            }
        }
        // Optional media still has to be real: an overlay that is not an
        // admitted still would otherwise reach the emitter unchecked.
        if let overlay = media[.overlay], overlay.kind != .still {
            throw PlanValidationError.invalidSelection("an overlay must be an admitted still")
        }
        // Unavailable effects are valid plans but cannot construct/export.
        if let emitter = catalog.emitter(for: plan.effectID) { _ = try emitter.channels(plan: plan, media: media) }
    }
}
