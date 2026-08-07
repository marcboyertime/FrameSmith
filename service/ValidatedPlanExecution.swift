import Foundation

/// Single semantic boundary for a plan paired with actual admitted media.
public struct ValidatedPlanExecution {
    public let registry: EffectRegistry
    public let catalog: StandaloneEmitterCatalog
    public init(registry: EffectRegistry, catalog: StandaloneEmitterCatalog = StandaloneEmitterCatalog()) { self.registry = registry; self.catalog = catalog }
    public func validate(plan: EffectPlan, media: [LocalMediaRole: LocalMediaAsset]) throws {
        try PlanValidator(registry: registry).validate(plan)
        let definition = try registry.definition(for: plan.effectID)
        let required: [LocalMediaRole]
        switch definition.inputCount {
        case 1: required = [.primary]
        case 2: required = [.outgoing, .incoming]
        default: throw PlanValidationError.invalidSelection("unsupported effect input count")
        }
        guard Set(media.keys) == Set(required), media.count == required.count else { throw PlanValidationError.invalidSelection("media roles do not match the effect") }
        guard plan.selectionToken.sourceIdentities.count == required.count else {
            throw PlanValidationError.invalidSelection("plan source identity count does not match the effect input count")
        }
        for (index, role) in required.enumerated() {
            guard media[role]?.sourceIdentity == plan.selectionToken.sourceIdentities[index] else {
                throw PlanValidationError.invalidSelection("admitted \(role.rawValue) media does not match the plan source identity")
            }
        }
        // Unavailable effects are valid plans but cannot construct/export.
        if let emitter = catalog.emitter(for: plan.effectID) { _ = try emitter.channels(plan: plan, media: media) }
    }
}
