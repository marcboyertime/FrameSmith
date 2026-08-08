import XCTest
@testable import FCPCommandConsoleCore

final class Phase1RegistryContractTests: XCTestCase {
    private func registry() throws -> EffectRegistry {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try EffectRegistry.load(from: root.appendingPathComponent("registry/effects"))
    }

    private func definition(_ id: EffectID, in registry: EffectRegistry) throws -> EffectDefinition {
        try registry.definition(for: id)
    }

    private func parameter(_ name: String, in definition: EffectDefinition) throws -> ParameterDefinition {
        try XCTUnwrap(definition.parameters.first(where: { $0.name == name }), "missing parameter \(name)")
    }

    private func editableProperty(_ name: String, in definition: EffectDefinition) throws -> EditableProperty {
        try XCTUnwrap(definition.editableProperties.first(where: { $0.name == name }), "missing editable property \(name)")
    }

    func testRegistryContainsExactlyThePhase1WorkflowIDs() throws {
        let registry = try registry()
        let expected: Set<EffectID> = [
            .targetedRotateZoom,
            .oldTelevision,
            .naturalDissolve,
            .livingStill
        ]

        XCTAssertEqual(Set(registry.definitions.keys), expected)
        XCTAssertEqual(registry.all.count, expected.count)
    }

    func testTargetedRotateZoomPreservesNativeEditableAnchorAndKeyframeContract() throws {
        let definition = try definition(.targetedRotateZoom, in: registry())

        XCTAssertEqual(definition.representation, .fcpxmlNative)
        XCTAssertEqual(definition.requiredSelection, .singleClip)
        XCTAssertEqual(definition.inputCount, 1)
        XCTAssertEqual(definition.backend, .native)
        XCTAssertTrue(definition.generatedAssets.isEmpty)
        XCTAssertEqual(definition.fallback, "native-targeted-rotate-zoom")

        let editableNames = Set(definition.editableProperties.map(\.name))
        XCTAssertTrue(editableNames.isSuperset(of: [
            "durationSeconds",
            "scaleStart",
            "scaleEnd",
            "rotationStartDegrees",
            "rotationEndDegrees",
            "anchorX",
            "anchorY",
            "positionX",
            "positionY",
            "keyframeTimes"
        ]))

        XCTAssertTrue(try editableProperty("scaleStart", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("scaleEnd", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("rotationStartDegrees", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("rotationEndDegrees", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("durationSeconds", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("anchorX", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("anchorY", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("positionX", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("positionY", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("keyframeTimes", in: definition).keyframeable)

        for name in ["positionX", "positionY"] {
            let property = try editableProperty(name, in: definition)
            XCTAssertEqual(property.valueType, "number")
            XCTAssertEqual(property.minimum, -4.0)
            XCTAssertEqual(property.maximum, 4.0)
            XCTAssertEqual(property.defaultValue?.numberValue, 0.0)
        }
        XCTAssertEqual(try editableProperty("keyframeTimes", in: definition).valueType, "time-range")
        XCTAssertNil(try editableProperty("keyframeTimes", in: definition).defaultValue)

        let derivedNames = Set(["positionX", "positionY", "keyframeTimes"])
        XCTAssertTrue(definition.parameters.allSatisfy { !derivedNames.contains($0.name) })

        XCTAssertEqual(try parameter("durationSeconds", in: definition).defaultValue?.numberValue, 4.0)
        XCTAssertEqual(try parameter("durationSeconds", in: definition).description, "bounded keyframe duration")
    }

    func testOldTelevisionPreservesNativeCanonicalConstruction() throws {
        let definition = try definition(.oldTelevision, in: registry())

        XCTAssertEqual(definition.representation, .layeredMedia)
        XCTAssertEqual(definition.requiredSelection, .singleClip)
        XCTAssertEqual(definition.inputCount, 1)
        XCTAssertEqual(definition.backend, .native)
        XCTAssertEqual(definition.fallback, "native-old-television-base-without-optional-overlay")
        XCTAssertTrue(definition.generatedAssets.isEmpty)
        XCTAssertTrue(definition.editableProperties.isEmpty)
        XCTAssertEqual(Set(definition.parameters.map(\.name)), [
            "durationSeconds", "saturation", "flickerFloor", "overlayOpacity",
            "overlayStartSeconds", "overlayDurationSeconds", "blendMode",
            "overlayTiming", "overlayTransform"
        ])
        XCTAssertEqual(try parameter("durationSeconds", in: definition).defaultValue?.numberValue, 4)
        XCTAssertEqual(try parameter("saturation", in: definition).defaultValue?.numberValue, 25)
        XCTAssertEqual(try parameter("flickerFloor", in: definition).defaultValue?.numberValue, 0.82)
        XCTAssertEqual(try parameter("overlayOpacity", in: definition).defaultValue?.numberValue, 0.35)
        XCTAssertEqual(try parameter("overlayStartSeconds", in: definition).defaultValue?.numberValue, 1)
        XCTAssertEqual(try parameter("overlayDurationSeconds", in: definition).defaultValue?.numberValue, 2)
        XCTAssertEqual(try parameter("blendMode", in: definition).defaultValue, .string("overlay"))
        XCTAssertEqual(try parameter("overlayTiming", in: definition).defaultValue, .string("bounded-range"))
        XCTAssertEqual(try parameter("overlayTransform", in: definition).defaultValue, .string("identity"))
    }

    func testNaturalDissolvePreservesNativeAdjacentClipAudioAndCanonicalDurationContract() throws {
        let definition = try definition(.naturalDissolve, in: registry())

        XCTAssertEqual(definition.representation, .fcpxmlNative)
        XCTAssertEqual(definition.requiredSelection, .twoAdjacentClips)
        XCTAssertEqual(definition.inputCount, 2)
        XCTAssertEqual(definition.backend, .native)
        XCTAssertTrue(definition.generatedAssets.isEmpty)
        XCTAssertEqual(definition.fallback, "native-natural-dissolve-only")

        XCTAssertTrue(definition.editableProperties.isEmpty)
        XCTAssertEqual(try parameter("durationFrames", in: definition).defaultValue?.numberValue, 12.0)
        XCTAssertEqual(try parameter("preserveAudio", in: definition).defaultValue, .boolean(true))
    }

    func testLivingStillPreservesNativeFallbackMotionColorOpacityAndDeferredDepthFlow() throws {
        let definition = try definition(.livingStill, in: registry())

        XCTAssertEqual(definition.representation, .fcpxmlNative)
        XCTAssertEqual(definition.requiredSelection, .singleClip)
        XCTAssertEqual(definition.inputCount, 1)
        XCTAssertEqual(definition.backend, .native)
        XCTAssertTrue(definition.generatedAssets.isEmpty)
        XCTAssertEqual(definition.fallback, "native-push-in-pan-color-enrichment-fade-to-black")

        XCTAssertEqual(try parameter("durationSeconds", in: definition).defaultValue?.numberValue, 4.0)
        XCTAssertEqual(try parameter("motionMethod", in: definition).defaultValue, .string("native-push-in-pan"))
        XCTAssertEqual(try parameter("depthFlowStatus", in: definition).defaultValue, .string("deferred-unavailable"))
        XCTAssertEqual(try parameter("nativeFallbackEnabled", in: definition).defaultValue, .boolean(true))

        let editableNames = Set(definition.editableProperties.map(\.name))
        XCTAssertTrue(editableNames.isSuperset(of: [
            "pushInScaleStart",
            "pushInScaleEnd",
            "panX",
            "panY",
            "colorEnrichment",
            "opacityStart",
            "opacityEnd",
            "fadeDurationSeconds"
        ]))
        XCTAssertTrue(try editableProperty("pushInScaleStart", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("pushInScaleEnd", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("panX", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("panY", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("colorEnrichment", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("opacityStart", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("opacityEnd", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("fadeDurationSeconds", in: definition).keyframeable)
    }
}
