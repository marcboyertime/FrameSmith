import Foundation

/// One source of truth for emitter availability.  Preview and export must not
/// independently guess which workflows are live.
public struct StandaloneEmitterCatalog: Sendable {
    public let emitters: [EffectID: any StandaloneEffectEmitter]

    public init(emitters: [any StandaloneEffectEmitter] = [LivingStillStandaloneEmitter(), TargetedRotateZoomStandaloneEmitter(), NaturalDissolveStandaloneEmitter(), OldTelevisionStandaloneEmitter()]) {
        self.emitters = Dictionary(uniqueKeysWithValues: emitters.map { ($0.effectID, $0) })
    }

    public func emitter(for effectID: EffectID) -> (any StandaloneEffectEmitter)? { emitters[effectID] }

    public func absenceReason(for effectID: EffectID) -> String? {
        guard emitters[effectID] == nil else { return nil }
        switch effectID {
        // Every effect has a production emitter as of 2026-08-07. These reasons
        // are reachable only when a caller constructs a catalog that omits one,
        // so they describe registration rather than a missing capability.
        case .naturalDissolve:
            return "no dissolve emitter is registered in this catalog; a dissolve also needs two admitted clips with sufficient handle on both sides"
        case .oldTelevision:
            return "no old television emitter is registered in this catalog"
        case .livingStill, .targetedRotateZoom:
            return "no emitter is registered in this catalog for \(effectID.rawValue)"
        }
    }
}
