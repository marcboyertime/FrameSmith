import XCTest
@testable import FCPCommandConsoleCore

final class OldTelevisionCompositionTests: XCTestCase {
    private let baseParameters: [String: ParameterValue] = [
        "monochromeEnabled": .boolean(true),
        "desaturation": .number(1),
        "contrast": .number(1.1),
        "staticStrength": .number(0.25),
        "grainStrength": .number(0.2),
        "scanlineStrength": .number(0.15),
        "instabilityStrength": .number(0.08),
        "overlayOpacity": .number(0.35),
        "blendMode": .string("screen"),
        "overlayTiming": .string("full-clip"),
        "overlayTransform": .string("identity"),
        "overlayEnabled": .boolean(true),
        "flickerEnabled": .boolean(true),
        "instabilityEnabled": .boolean(true),
        "wholeLookEnabled": .boolean(true),
        "vignetteEnabled": .boolean(false),
        "vignetteStrength": .number(0.15),
        "kind": .string("static"),
        "durationSeconds": .number(4),
        "width": .integer(320),
        "height": .integer(180),
        "fps": .integer(24),
        "seed": .integer(41)
    ]

    func testBuildsExactlyTwoIndependentEditableOverlayLayers() throws {
        let composition = try build()

        XCTAssertEqual(composition.overlays.count, 2)
        XCTAssertEqual(composition.overlays.map { $0.request.kind }, [.staticGrain, .scanline])
        XCTAssertEqual(composition.overlays.map(\.strength), [0.25, 0.15])
        XCTAssertNotEqual(composition.overlays[0].opacity, composition.overlays[1].opacity)
        XCTAssertEqual(composition.overlays.map(\.blendMode), [.screen, .screen])
        XCTAssertEqual(composition.overlays.map(\.timing), [.fullClip, .fullClip])
        XCTAssertEqual(composition.overlays.map(\.transform), [.identity, .identity])
        XCTAssertTrue(composition.overlays.allSatisfy { $0.enabled })
        XCTAssertTrue(composition.overlays.allSatisfy { $0.placement == .connectedAboveOriginal })
        XCTAssertTrue(composition.overlays.allSatisfy { $0.pixelClassification == .bakedGeneratedPixels })

        for layer in composition.overlays {
            XCTAssertEqual(layer.request.width, 320)
            XCTAssertEqual(layer.request.height, 180)
            XCTAssertEqual(layer.request.fps, 24)
            XCTAssertEqual(layer.request.durationSeconds, 4)
            XCTAssertEqual(layer.request.seed, 41)
        }
        XCTAssertEqual(composition.native.desaturation, 1)
        XCTAssertEqual(composition.native.contrast, 1.1)
        XCTAssertEqual(composition.native.grainStrength, 0.2)
        XCTAssertEqual(composition.overlayOpacity, 0.35)
    }

    func testBuilderRejectsWrongEffectRepresentationMissingTypesBoundsAndEnums() throws {
        XCTAssertThrowsError(try build(effectID: .livingStill)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .wrongEffect(.livingStill))
        }
        XCTAssertThrowsError(try build(representation: .fcpxmlNative)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .wrongRepresentation(.fcpxmlNative))
        }

        var missing = baseParameters
        missing.removeValue(forKey: "contrast")
        XCTAssertThrowsError(try build(parameters: missing)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .missingParameter("contrast"))
        }

        var wrongType = baseParameters
        wrongType["contrast"] = .string("1.1")
        XCTAssertThrowsError(try build(parameters: wrongType)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .wrongParameterType("contrast"))
        }

        var wrongIntegerType = baseParameters
        wrongIntegerType["width"] = .number(320)
        XCTAssertThrowsError(try build(parameters: wrongIntegerType)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .wrongParameterType("width"))
        }

        for (name, value) in [
            ("desaturation", ParameterValue.number(-0.01)),
            ("contrast", .number(2.01)),
            ("staticStrength", .number(1.01)),
            ("grainStrength", .number(-0.01)),
            ("scanlineStrength", .number(1.01)),
            ("instabilityStrength", .number(0.51)),
            ("overlayOpacity", .number(-0.01)),
            ("vignetteStrength", .number(1.01)),
            ("durationSeconds", .number(30.01))
        ] {
            var parameters = baseParameters
            parameters[name] = value
            XCTAssertThrowsError(try build(parameters: parameters), "expected (name) to be bounded") { error in
                XCTAssertEqual(error as? OldTelevisionCompositionError, .outOfRange(name))
            }
        }

        var nonFinite = baseParameters
        nonFinite["contrast"] = .number(.nan)
        XCTAssertThrowsError(try build(parameters: nonFinite)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .nonFinite("contrast"))
        }

        for (name, value, expected) in [
            ("blendMode", "multiply", OldTelevisionCompositionError.unknownBlendMode("multiply")),
            ("overlayTiming", "per-frame", OldTelevisionCompositionError.unknownTiming("per-frame")),
            ("overlayTransform", "freeform", OldTelevisionCompositionError.unknownTransform("freeform")),
            ("kind", "arbitrary", OldTelevisionCompositionError.invalidKind("arbitrary"))
        ] as [(String, String, OldTelevisionCompositionError)] {
            var parameters = baseParameters
            parameters[name] = .string(value)
            XCTAssertThrowsError(try build(parameters: parameters)) { error in
                XCTAssertEqual(error as? OldTelevisionCompositionError, expected)
            }
        }

        var unknown = baseParameters
        unknown["shell"] = .string("never")
        XCTAssertThrowsError(try build(parameters: unknown)) { error in
            XCTAssertEqual(error as? OldTelevisionCompositionError, .invalidComposition("unknown parameter shell"))
        }
    }

    func testSamplesAreDeterministicTemporallyCoherentAndBounded() throws {
        let first = try build().instability
        let second = try build().instability
        XCTAssertEqual(first, second)
        XCTAssertGreaterThan(first.samples.count, 2)
        XCTAssertLessThanOrEqual(first.samples.count, 24)
        XCTAssertEqual(first.samples.first?.timeSeconds, 0)
        XCTAssertEqual(first.samples.last?.timeSeconds, 4)
        XCTAssertGreaterThan(Set(first.samples.map(\.flickerMultiplier)).count, 1)
        XCTAssertGreaterThan(Set(first.samples.map(\.instabilityAmount)).count, 1)

        for pair in zip(first.samples, first.samples.dropFirst()) {
            XCTAssertGreaterThan(pair.1.timeSeconds, pair.0.timeSeconds)
            XCTAssertLessThanOrEqual(abs(pair.1.flickerMultiplier - pair.0.flickerMultiplier), 0.1)
            XCTAssertLessThanOrEqual(abs(pair.1.instabilityAmount - pair.0.instabilityAmount), 0.1)
        }
        XCTAssertTrue(first.samples.allSatisfy { $0.timeSeconds.isFinite && $0.flickerMultiplier.isFinite && $0.instabilityAmount.isFinite })
        XCTAssertTrue(first.samples.allSatisfy { (0.8...1.2).contains($0.flickerMultiplier) && (-0.5...0.5).contains($0.instabilityAmount) })
    }

    func testDisablingFlickerInstabilityOverlayAndWholeLookIsExplicit() throws {
        var parameters = baseParameters
        parameters["flickerEnabled"] = .boolean(false)
        parameters["instabilityEnabled"] = .boolean(false)
        parameters["overlayEnabled"] = .boolean(false)
        parameters["wholeLookEnabled"] = .boolean(false)
        parameters["vignetteEnabled"] = .boolean(true)

        let composition = try build(parameters: parameters)
        XCTAssertFalse(composition.wholeLook.enabled)
        XCTAssertFalse(composition.wholeLook.vignetteEnabled)
        XCTAssertEqual(composition.wholeLook.vignetteStrength, 0)
        XCTAssertFalse(composition.native.monochromeEnabled)
        XCTAssertEqual(composition.native.desaturation, 0)
        XCTAssertEqual(composition.native.contrast, 1)
        XCTAssertEqual(composition.native.grainStrength, 0)
        XCTAssertTrue(composition.overlays.allSatisfy { !$0.enabled && $0.opacity == 0 })
        XCTAssertFalse(composition.instability.flickerEnabled)
        XCTAssertFalse(composition.instability.instabilityEnabled)
        XCTAssertEqual(composition.instability.strength, 0)
        XCTAssertTrue(composition.instability.samples.allSatisfy { $0.flickerMultiplier == 1 && $0.instabilityAmount == 0 })
    }

    private func build(effectID: EffectID = .oldTelevision,
                       representation: RepresentationClass = .layeredMedia,
                       parameters: [String: ParameterValue]? = nil) throws -> OldTelevisionComposition {
        let selection = SelectionToken(selectionType: .singleClip, clipIDs: ["clip"], revision: "revision")
        let plan = EffectPlan(originalRequest: "old tv",
                              confidence: 1,
                              effectID: effectID,
                              selectionToken: selection,
                              parameters: parameters ?? baseParameters,
                              representation: representation,
                              fallback: "fallback",
                              preconditionRevision: "revision")
        return try OldTelevisionCompositionBuilder.build(from: plan)
    }
}
