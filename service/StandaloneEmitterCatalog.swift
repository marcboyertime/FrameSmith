import Foundation

/// One source of truth for emitter availability.  Preview and export must not
/// independently guess which workflows are live.
public struct StandaloneEmitterCatalog: Sendable {
    public let emitters: [EffectID: any StandaloneEffectEmitter]

    public init(emitters: [any StandaloneEffectEmitter] = [LivingStillStandaloneEmitter(), TargetedRotateZoomStandaloneEmitter()]) {
        self.emitters = Dictionary(uniqueKeysWithValues: emitters.map { ($0.effectID, $0) })
    }

    public func emitter(for effectID: EffectID) -> (any StandaloneEffectEmitter)? { emitters[effectID] }

    public func absenceReason(for effectID: EffectID) -> String? {
        guard emitters[effectID] == nil else { return nil }
        switch effectID {
        case .naturalDissolve:
            return "the dissolve construction needs two adjacent clips and a centred transition; it has not been generalised to arbitrary plan values"
        case .oldTelevision:
            return "the connected-overlay construction is admitted, but no emitter generalises it from arbitrary plan values"
        case .livingStill, .targetedRotateZoom:
            return nil
        }
    }
}
