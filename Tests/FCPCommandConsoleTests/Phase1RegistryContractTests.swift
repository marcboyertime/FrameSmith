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

    func testOldTelevisionDeclaresChecksumBoundRenderedCRTConstruction() throws {
        let definition = try definition(.oldTelevision, in: registry())

        XCTAssertEqual(definition.representation, .layeredMedia)
        XCTAssertEqual(definition.requiredSelection, .singleClip)
        XCTAssertEqual(definition.inputCount, 1)
        XCTAssertEqual(definition.backend, .ffmpeg)
        XCTAssertEqual(definition.preview, "checksum-bound-rendered-movie")
        XCTAssertEqual(definition.fallback, "refuse-if-crt-renderer-unavailable")
        XCTAssertEqual(definition.generatedAssets, [
            GeneratedAssetDefinition(
                kind: "crt-treatment-movie",
                format: "prores-422-10bit",
                alpha: false,
                deterministic: true
            )
        ])
        XCTAssertEqual(Set(definition.editableProperties.map(\.name)), [
            "durationSeconds", "profile", "intensity", "scanlineStrength",
            "noiseStrength", "syncInstability", "chromaSeparation",
            "bloomStrength", "vignetteStrength", "ghostingStrength",
            "flickerStrength", "seed"
        ])
        XCTAssertEqual(Set(definition.parameters.map(\.name)), [
            "durationSeconds", "profile", "intensity", "scanlineStrength",
            "noiseStrength", "syncInstability", "chromaSeparation",
            "bloomStrength", "vignetteStrength", "ghostingStrength",
            "flickerStrength", "seed", "outputLongEdge", "fps",
            "renderMethod", "preserveOriginal"
        ])
        XCTAssertEqual(try parameter("durationSeconds", in: definition).defaultValue?.numberValue, 4)
        XCTAssertEqual(try parameter("profile", in: definition).defaultValue, .string("broadcast-mono"))
        XCTAssertEqual(try parameter("intensity", in: definition).defaultValue?.numberValue, 0.68)
        XCTAssertEqual(try parameter("flickerStrength", in: definition).defaultValue?.numberValue, 0.12)
        XCTAssertEqual(try parameter("seed", in: definition).defaultValue, .integer(7341))
        XCTAssertEqual(try parameter("outputLongEdge", in: definition).minimum, 1920)
        XCTAssertEqual(try parameter("outputLongEdge", in: definition).maximum, 1920)
        XCTAssertEqual(try parameter("fps", in: definition).defaultValue, .integer(30))
        XCTAssertEqual(try parameter("renderMethod", in: definition).defaultValue, .string("ffmpeg-crt-v2"))
        XCTAssertEqual(try parameter("preserveOriginal", in: definition).defaultValue, .boolean(true))
        XCTAssertTrue(definition.verification.contains { $0.contains("no opacity fade") })
        XCTAssertTrue(definition.verification.contains { $0.contains("same SHA-256-identified movie") })
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

    func testLivingStillDeclaresPinnedChecksumBoundDepthRenderContract() throws {
        let definition = try definition(.livingStill, in: registry())

        XCTAssertEqual(definition.representation, .layeredMedia)
        XCTAssertEqual(definition.requiredSelection, .singleClip)
        XCTAssertEqual(definition.inputCount, 1)
        XCTAssertEqual(definition.backend, .local)
        XCTAssertEqual(definition.preview, "checksum-bound-rendered-movie")
        XCTAssertEqual(definition.fallback, "refuse-if-depth-render-unavailable")
        XCTAssertEqual(definition.generatedAssets, [
            GeneratedAssetDefinition(
                kind: "depth-warp-treatment-movie",
                format: "prores-422-10bit",
                alpha: false,
                deterministic: false
            )
        ])

        XCTAssertEqual(Set(definition.parameters.map(\.name)), [
            "durationSeconds", "motionStrength", "pushIn", "panX", "panY",
            "depthSmoothing", "outputLongEdge", "fps", "modelID",
            "motionMethod", "preserveOriginal"
        ])
        XCTAssertEqual(try parameter("durationSeconds", in: definition).defaultValue?.numberValue, 4.0)
        XCTAssertEqual(try parameter("motionStrength", in: definition).defaultValue?.numberValue, 0.9)
        XCTAssertEqual(try parameter("pushIn", in: definition).defaultValue?.numberValue, 0.03)
        XCTAssertEqual(try parameter("panX", in: definition).defaultValue?.numberValue, 0.012)
        XCTAssertEqual(try parameter("panY", in: definition).defaultValue?.numberValue, -0.006)
        XCTAssertEqual(try parameter("depthSmoothing", in: definition).defaultValue?.numberValue, 0.35)
        XCTAssertEqual(try parameter("outputLongEdge", in: definition).defaultValue, .integer(1920))
        XCTAssertEqual(try parameter("outputLongEdge", in: definition).minimum, 1920)
        XCTAssertEqual(try parameter("outputLongEdge", in: definition).maximum, 1920)
        XCTAssertEqual(try parameter("fps", in: definition).defaultValue, .integer(30))
        XCTAssertEqual(
            try parameter("modelID", in: definition).defaultValue,
            .string("apple.coreml.depth-anything-v2-small-f16@cfef6f6f2a70783dedc0bfae40cecbc2052285d3")
        )
        XCTAssertEqual(try parameter("motionMethod", in: definition).defaultValue, .string("coreml-continuous-depth-warp-v2"))
        XCTAssertEqual(try parameter("preserveOriginal", in: definition).defaultValue, .boolean(true))

        let editableNames = Set(definition.editableProperties.map(\.name))
        XCTAssertEqual(editableNames, [
            "durationSeconds", "motionStrength", "pushIn", "panX", "panY", "depthSmoothing"
        ])
        for name in editableNames {
            XCTAssertFalse(try editableProperty(name, in: definition).keyframeable, name)
        }
        XCTAssertTrue(definition.verification.contains { $0.contains("unchanged spine source") })
        XCTAssertTrue(definition.verification.contains { $0.contains("exact duration") })
        XCTAssertTrue(definition.verification.contains { $0.contains("same SHA-256-identified movie") })
        XCTAssertTrue(definition.verification.contains { $0.contains("model, depth field, recipe") })
        XCTAssertTrue(definition.verification.contains { $0.contains("no fade") })
    }
}
