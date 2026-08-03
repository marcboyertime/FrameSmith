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

    func testOldTelevisionPreservesGeneratedAssetsAndEditableLookControls() throws {
        let definition = try definition(.oldTelevision, in: registry())

        XCTAssertEqual(definition.representation, .layeredMedia)
        XCTAssertEqual(definition.requiredSelection, .singleClip)
        XCTAssertEqual(definition.inputCount, 1)
        XCTAssertEqual(definition.backend, .ffmpeg)
        XCTAssertEqual(definition.fallback, "native-old-television-without-generated-overlay")

        XCTAssertEqual(definition.generatedAssets.count, 2)
        XCTAssertEqual(Set(definition.generatedAssets.map(\.kind)), ["static-grain", "scanlines"])
        XCTAssertTrue(definition.generatedAssets.allSatisfy { $0.format == "mov" && $0.alpha && $0.deterministic })

        let editableNames = Set(definition.editableProperties.map(\.name))
        XCTAssertTrue(editableNames.isSuperset(of: [
            "monochromeEnabled",
            "desaturation",
            "contrast",
            "staticStrength",
            "grainStrength",
            "scanlineStrength",
            "instabilityStrength",
            "overlayOpacity",
            "blendMode",
            "overlayTiming",
            "overlayTransform",
            "overlayEnabled",
            "flickerEnabled",
            "instabilityEnabled",
            "wholeLookEnabled"
        ]))

        XCTAssertTrue(try editableProperty("desaturation", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("contrast", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("overlayOpacity", in: definition).keyframeable)
        XCTAssertTrue(try editableProperty("overlayTransform", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("monochromeEnabled", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("overlayEnabled", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("flickerEnabled", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("instabilityEnabled", in: definition).keyframeable)
        XCTAssertFalse(try editableProperty("wholeLookEnabled", in: definition).keyframeable)
    }

    func testNaturalDissolvePreservesNativeAdjacentClipAudioAndDurationContract() throws {
        let definition = try definition(.naturalDissolve, in: registry())

        XCTAssertEqual(definition.representation, .fcpxmlNative)
        XCTAssertEqual(definition.requiredSelection, .twoAdjacentClips)
        XCTAssertEqual(definition.inputCount, 2)
        XCTAssertEqual(definition.backend, .native)
        XCTAssertTrue(definition.generatedAssets.isEmpty)
        XCTAssertEqual(definition.fallback, "native-natural-dissolve-only")

        let editableNames = Set(definition.editableProperties.map(\.name))
        XCTAssertTrue(editableNames.isSuperset(of: ["durationFrames", "preserveAudio"]))
        XCTAssertEqual(try parameter("durationFrames", in: definition).defaultValue?.numberValue, 12.0)
        XCTAssertEqual(try parameter("preserveAudio", in: definition).defaultValue, .boolean(true))
        XCTAssertEqual(try editableProperty("durationFrames", in: definition).valueType, "integer")
        XCTAssertEqual(try editableProperty("preserveAudio", in: definition).valueType, "boolean")
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
