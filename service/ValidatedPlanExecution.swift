import Foundation

/// Single semantic boundary for a plan paired with actual admitted media.
public struct ValidatedPlanExecution {
    public let registry: EffectRegistry
    public let catalog: StandaloneEmitterCatalog
    public init(registry: EffectRegistry, catalog: StandaloneEmitterCatalog = StandaloneEmitterCatalog()) { self.registry = registry; self.catalog = catalog }
    public func validate(plan: EffectPlan, media: [LocalMediaRole: LocalMediaAsset]) throws {
        try PlanValidator(registry: registry).validate(plan)
        let definition = try registry.definition(for: plan.effectID)
        let required: [LocalMediaRole] = definition.inputCount == 2 ? [.outgoing, .incoming] : [.primary]
        guard Set(media.keys) == Set(required), media.count == definition.inputCount else { throw PlanValidationError.invalidSelection("media roles do not match the effect") }
        guard required.allSatisfy({ role in
            guard let asset = media[role] else { return false }
            return plan.selectionToken.sourceIdentities.contains(asset.sourceIdentity)
        }) else { throw PlanValidationError.invalidSelection("admitted media does not match plan source identities") }
        // Unavailable effects are valid plans but cannot construct/export.
        if let emitter = catalog.emitter(for: plan.effectID) { _ = try emitter.channels(plan: plan, media: media) }
    }
}
