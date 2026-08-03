import Foundation

/// The two closed blend modes and timing values admitted by the Phase 1
/// old-television registry.  These enums intentionally do not carry a path,
/// selector, command, or backend method.
public enum OldTelevisionBlendMode: String, Codable, CaseIterable, Sendable {
    case screen
    case overlay
    case softLight = "soft-light"
}

public enum OldTelevisionOverlayTiming: String, Codable, CaseIterable, Sendable {
    case fullClip = "full-clip"
    case boundedRange = "bounded-range"
}

public enum OldTelevisionOverlayTransform: String, Codable, CaseIterable, Sendable {
    case identity
}

public enum OldTelevisionOverlayPlacement: String, Codable, CaseIterable, Sendable {
    case connectedAboveOriginal = "connected-above-original"
}

/// Pixel content is generated and verified separately.  The composition only
/// describes the editable recipe applied to that baked content.
public enum OldTelevisionPixelClassification: String, Codable, CaseIterable, Sendable {
    case bakedGeneratedPixels = "baked-generated-pixels"
}

public struct OldTelevisionNativeLookControls: Codable, Equatable, Sendable {
    public var monochromeEnabled: Bool
    public var desaturation: Double
    public var contrast: Double
    public var grainStrength: Double

    public init(monochromeEnabled: Bool, desaturation: Double, contrast: Double, grainStrength: Double) {
        self.monochromeEnabled = monochromeEnabled
        self.desaturation = desaturation
        self.contrast = contrast
        self.grainStrength = grainStrength
    }
}

public struct OldTelevisionOverlayLayer: Codable, Equatable, Sendable {
    public var request: OverlayRequest
    /// The registry's independent static/scanline strength.  It remains a
    /// first-class editable control; it is never collapsed into overlayOpacity.
    public var strength: Double
    /// Effective editable opacity after the shared overlay opacity is applied.
    public var opacity: Double
    public var blendMode: OldTelevisionBlendMode
    public var timing: OldTelevisionOverlayTiming
    public var transform: OldTelevisionOverlayTransform
    public var enabled: Bool
    public var placement: OldTelevisionOverlayPlacement
    public let pixelClassification: OldTelevisionPixelClassification

    public init(request: OverlayRequest,
                strength: Double,
                opacity: Double,
                blendMode: OldTelevisionBlendMode,
                timing: OldTelevisionOverlayTiming,
                transform: OldTelevisionOverlayTransform,
                enabled: Bool,
                placement: OldTelevisionOverlayPlacement = .connectedAboveOriginal,
                pixelClassification: OldTelevisionPixelClassification = .bakedGeneratedPixels) {
        self.request = request
        self.strength = strength
        self.opacity = opacity
        self.blendMode = blendMode
        self.timing = timing
        self.transform = transform
        self.enabled = enabled
        self.placement = placement
        self.pixelClassification = pixelClassification
    }
}

public struct OldTelevisionKeyframeSample: Codable, Equatable, Sendable {
    public var timeSeconds: Double
    /// A bounded native flicker multiplier.  1.0 is the neutral value.
    public var flickerMultiplier: Double
    /// A bounded native instability amount centered on zero.
    public var instabilityAmount: Double

    public init(timeSeconds: Double, flickerMultiplier: Double, instabilityAmount: Double) {
        self.timeSeconds = timeSeconds
        self.flickerMultiplier = flickerMultiplier
        self.instabilityAmount = instabilityAmount
    }
}

public struct OldTelevisionInstabilityPlan: Codable, Equatable, Sendable {
    public var flickerEnabled: Bool
    public var instabilityEnabled: Bool
    public var strength: Double
    public var seed: Int
    public var samples: [OldTelevisionKeyframeSample]

    public init(flickerEnabled: Bool,
                instabilityEnabled: Bool,
                strength: Double,
                seed: Int,
                samples: [OldTelevisionKeyframeSample]) {
        self.flickerEnabled = flickerEnabled
        self.instabilityEnabled = instabilityEnabled
        self.strength = strength
        self.seed = seed
        self.samples = samples
    }
}

public struct OldTelevisionWholeLookControls: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var vignetteEnabled: Bool
    public var vignetteStrength: Double

    public init(enabled: Bool, vignetteEnabled: Bool, vignetteStrength: Double) {
        self.enabled = enabled
        self.vignetteEnabled = vignetteEnabled
        self.vignetteStrength = vignetteStrength
    }
}

public struct OldTelevisionComposition: Codable, Equatable, Sendable {
    public var native: OldTelevisionNativeLookControls
    public var overlays: [OldTelevisionOverlayLayer]
    public var instability: OldTelevisionInstabilityPlan
    public var wholeLook: OldTelevisionWholeLookControls
    public var overlayOpacity: Double

    public init(native: OldTelevisionNativeLookControls,
                overlays: [OldTelevisionOverlayLayer],
                instability: OldTelevisionInstabilityPlan,
                wholeLook: OldTelevisionWholeLookControls,
                overlayOpacity: Double) {
        self.native = native
        self.overlays = overlays
        self.instability = instability
        self.wholeLook = wholeLook
        self.overlayOpacity = overlayOpacity
    }

    public var staticGrainLayer: OldTelevisionOverlayLayer? {
        overlays.first { $0.request.kind == .staticGrain }
    }

    public var scanlineLayer: OldTelevisionOverlayLayer? {
        overlays.first { $0.request.kind == .scanline }
    }
}

public enum OldTelevisionCompositionError: Error, LocalizedError, Equatable, Sendable {
    case wrongEffect(EffectID)
    case wrongRepresentation(RepresentationClass)
    case missingParameter(String)
    case wrongParameterType(String)
    case outOfRange(String)
    case nonFinite(String)
    case unknownBlendMode(String)
    case unknownTiming(String)
    case unknownTransform(String)
    case invalidKind(String)
    case invalidComposition(String)

    public var errorDescription: String? {
        switch self {
        case .wrongEffect(let id): return "Old Television composition requires look.old_television, got \(id.rawValue)"
        case .wrongRepresentation(let representation): return "Old Television composition requires layered_media, got \(representation.rawValue)"
        case .missingParameter(let name): return "Old Television composition is missing parameter \(name)"
        case .wrongParameterType(let name): return "Old Television composition parameter \(name) has the wrong type"
        case .outOfRange(let name): return "Old Television composition parameter \(name) is outside its bounded range"
        case .nonFinite(let name): return "Old Television composition parameter \(name) is not finite"
        case .unknownBlendMode(let value): return "Unknown Old Television blend mode \(value)"
        case .unknownTiming(let value): return "Unknown Old Television overlay timing \(value)"
        case .unknownTransform(let value): return "Unknown Old Television overlay transform \(value)"
        case .invalidKind(let value): return "Invalid Old Television generated-overlay kind \(value)"
        case .invalidComposition(let reason): return "Invalid Old Television composition: \(reason)"
        }
    }
}

public enum OldTelevisionCompositionBuilder {
    private static let parameterNames: Set<String> = [
        "monochromeEnabled", "desaturation", "contrast", "staticStrength", "grainStrength",
        "scanlineStrength", "instabilityStrength", "overlayOpacity", "blendMode", "overlayTiming",
        "overlayTransform", "overlayEnabled", "flickerEnabled", "instabilityEnabled", "wholeLookEnabled",
        "vignetteEnabled", "vignetteStrength", "kind", "durationSeconds", "width", "height", "fps", "seed"
    ]

    public static func build(from plan: EffectPlan) throws -> OldTelevisionComposition {
        guard plan.effectID == .oldTelevision else { throw OldTelevisionCompositionError.wrongEffect(plan.effectID) }
        try CapabilityGate().require(plan, capability: .localOnlyPreview)
        guard plan.representation == .layeredMedia else {
            throw OldTelevisionCompositionError.wrongRepresentation(plan.representation)
        }
        let unknown = plan.parameters.keys.filter { !parameterNames.contains($0) }.sorted()
        if let first = unknown.first {
            throw OldTelevisionCompositionError.invalidComposition("unknown parameter \(first)")
        }

        let parameters = plan.parameters
        let monochromeEnabled = try bool("monochromeEnabled", in: parameters)
        let desaturation = try number("desaturation", in: parameters, range: 0...1)
        let contrast = try number("contrast", in: parameters, range: 0.5...2)
        let staticStrength = try number("staticStrength", in: parameters, range: 0...1)
        let grainStrength = try number("grainStrength", in: parameters, range: 0...1)
        let scanlineStrength = try number("scanlineStrength", in: parameters, range: 0...1)
        let instabilityStrength = try number("instabilityStrength", in: parameters, range: 0...0.5)
        let overlayOpacity = try number("overlayOpacity", in: parameters, range: 0...1)
        let blendMode = try blendMode("blendMode", in: parameters)
        let timing = try timing("overlayTiming", in: parameters)
        let transform = try transform("overlayTransform", in: parameters)
        let overlayEnabled = try bool("overlayEnabled", in: parameters)
        let flickerEnabled = try bool("flickerEnabled", in: parameters)
        let instabilityEnabled = try bool("instabilityEnabled", in: parameters)
        let wholeLookEnabled = try bool("wholeLookEnabled", in: parameters)
        let vignetteEnabled = try bool("vignetteEnabled", in: parameters)
        let vignetteStrength = try number("vignetteStrength", in: parameters, range: 0...1)
        let kind = try string("kind", in: parameters)
        guard kind == "static" || kind == "scanline" else { throw OldTelevisionCompositionError.invalidKind(kind) }
        let duration = try number("durationSeconds", in: parameters, range: 0.1...30)
        let width = try integer("width", in: parameters, range: 16...1920)
        let height = try integer("height", in: parameters, range: 16...1080)
        let fps = try integer("fps", in: parameters, range: 1...60)
        let seed = try integer("seed", in: parameters, range: 0...2_147_483_647)

        let requestBase = { (kind: OverlayKind) in
            OverlayRequest(kind: kind, width: width, height: height, fps: fps, durationSeconds: duration, seed: seed)
        }
        let effectiveLookEnabled = wholeLookEnabled && overlayEnabled
        let overlays = [
            OldTelevisionOverlayLayer(request: requestBase(.staticGrain),
                                      strength: staticStrength,
                                      opacity: effectiveLookEnabled ? staticStrength * overlayOpacity : 0,
                                      blendMode: blendMode,
                                      timing: timing,
                                      transform: transform,
                                      enabled: effectiveLookEnabled),
            OldTelevisionOverlayLayer(request: requestBase(.scanline),
                                      strength: scanlineStrength,
                                      opacity: effectiveLookEnabled ? scanlineStrength * overlayOpacity : 0,
                                      blendMode: blendMode,
                                      timing: timing,
                                      transform: transform,
                                      enabled: effectiveLookEnabled)
        ]
        let instability = OldTelevisionInstabilityPlan(
            flickerEnabled: wholeLookEnabled && flickerEnabled,
            instabilityEnabled: wholeLookEnabled && instabilityEnabled,
            strength: wholeLookEnabled ? instabilityStrength : 0,
            seed: seed,
            samples: samples(duration: duration,
                             fps: fps,
                             strength: wholeLookEnabled ? instabilityStrength : 0,
                             seed: seed,
                             flickerEnabled: wholeLookEnabled && flickerEnabled,
                             instabilityEnabled: wholeLookEnabled && instabilityEnabled)
        )
        return OldTelevisionComposition(
            native: OldTelevisionNativeLookControls(monochromeEnabled: wholeLookEnabled && monochromeEnabled,
                                                    desaturation: wholeLookEnabled ? desaturation : 0,
                                                    contrast: wholeLookEnabled ? contrast : 1,
                                                    grainStrength: wholeLookEnabled ? grainStrength : 0),
            overlays: overlays,
            instability: instability,
            wholeLook: OldTelevisionWholeLookControls(enabled: wholeLookEnabled,
                                                      vignetteEnabled: wholeLookEnabled && vignetteEnabled,
                                                      vignetteStrength: wholeLookEnabled ? vignetteStrength : 0),
            overlayOpacity: overlayOpacity
        )
    }

    private static func value(_ name: String, in parameters: [String: ParameterValue]) throws -> ParameterValue {
        guard let value = parameters[name] else { throw OldTelevisionCompositionError.missingParameter(name) }
        return value
    }

    private static func bool(_ name: String, in parameters: [String: ParameterValue]) throws -> Bool {
        guard case .boolean(let value) = try value(name, in: parameters) else {
            throw OldTelevisionCompositionError.wrongParameterType(name)
        }
        return value
    }

    private static func string(_ name: String, in parameters: [String: ParameterValue]) throws -> String {
        guard case .string(let value) = try value(name, in: parameters) else {
            throw OldTelevisionCompositionError.wrongParameterType(name)
        }
        return value
    }

    private static func number(_ name: String, in parameters: [String: ParameterValue], range: ClosedRange<Double>) throws -> Double {
        let value = try value(name, in: parameters)
        let number: Double
        switch value {
        case .number(let candidate): number = candidate
        case .integer(let candidate): number = Double(candidate)
        default: throw OldTelevisionCompositionError.wrongParameterType(name)
        }
        guard number.isFinite else { throw OldTelevisionCompositionError.nonFinite(name) }
        guard range.contains(number) else { throw OldTelevisionCompositionError.outOfRange(name) }
        return number
    }

    private static func integer(_ name: String, in parameters: [String: ParameterValue], range: ClosedRange<Int>) throws -> Int {
        guard case .integer(let value) = try value(name, in: parameters) else {
            throw OldTelevisionCompositionError.wrongParameterType(name)
        }
        guard range.contains(value) else { throw OldTelevisionCompositionError.outOfRange(name) }
        return value
    }

    private static func blendMode(_ name: String, in parameters: [String: ParameterValue]) throws -> OldTelevisionBlendMode {
        let value = try string(name, in: parameters)
        guard let mode = OldTelevisionBlendMode(rawValue: value) else { throw OldTelevisionCompositionError.unknownBlendMode(value) }
        return mode
    }

    private static func timing(_ name: String, in parameters: [String: ParameterValue]) throws -> OldTelevisionOverlayTiming {
        let value = try string(name, in: parameters)
        guard let timing = OldTelevisionOverlayTiming(rawValue: value) else { throw OldTelevisionCompositionError.unknownTiming(value) }
        return timing
    }

    private static func transform(_ name: String, in parameters: [String: ParameterValue]) throws -> OldTelevisionOverlayTransform {
        let value = try string(name, in: parameters)
        guard let transform = OldTelevisionOverlayTransform(rawValue: value) else { throw OldTelevisionCompositionError.unknownTransform(value) }
        return transform
    }

    private static func samples(duration: Double,
                                fps: Int,
                                strength: Double,
                                seed: Int,
                                flickerEnabled: Bool,
                                instabilityEnabled: Bool) -> [OldTelevisionKeyframeSample] {
        let count = min(24, max(2, Int(ceil(duration * Double(fps) / 6))))
        var state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
        var previousFlicker = 1.0
        var previousInstability = 0.0
        return (0..<count).map { index in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double((state >> 11) & 0x1FFFFF) / Double(0x1FFFFF)
            let signed = unit * 2 - 1
            let flickerTarget = flickerEnabled ? 1 + signed * min(0.2, strength * 0.5) : 1
            let instabilityTarget = instabilityEnabled ? signed * strength : 0
            previousFlicker += (flickerTarget - previousFlicker) * 0.25
            previousInstability += (instabilityTarget - previousInstability) * 0.25
            let time = duration * Double(index) / Double(count - 1)
            return OldTelevisionKeyframeSample(timeSeconds: time,
                                               flickerMultiplier: previousFlicker,
                                               instabilityAmount: previousInstability)
        }
    }
}
