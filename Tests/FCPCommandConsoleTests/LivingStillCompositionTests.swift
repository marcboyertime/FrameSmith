import Foundation
import XCTest
@testable import FCPCommandConsoleCore

final class LivingStillCompositionTests: XCTestCase {
    private let sourceHash = String(repeating: "a", count: 64)

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func registry() throws -> EffectRegistry {
        try EffectRegistry.load(from: projectRoot().appendingPathComponent("registry/effects"))
    }

    private func selection(path: String = "/tmp/living-still-source.png") -> SelectionToken {
        SelectionToken(
            tokenID: "living-still-token",
            selectionType: .singleClip,
            timelineID: "timeline",
            clipIDs: ["still-clip"],
            sourceIdentities: [SourceIdentity(itemID: "still-clip", canonicalPath: path, sha256: sourceHash)],
            revision: "revision-1",
            startFrame: 0,
            endFrame: 96,
            sourceDurationFrames: 96,
            handleBeforeFrames: 0,
            handleAfterFrames: 0,
            isSpine: true,
            adjacent: true
        )
    }

    private func plan(operationID: UUID = UUID(), selection provided: SelectionToken? = nil) throws -> EffectPlan {
        let planner = DeterministicPlanner(registry: try registry())
        let token = provided ?? selection()
        return try planner.plan(
            request: "Make this still image feel gently alive for four seconds, then fade quickly to black.",
            selection: token,
            operationID: operationID
        )
    }

    func testDefaultPlanBuildsFourSecondNativeFallbackWithoutBakedPixels() throws {
        let composition = try LivingStillCompositionBuilder.build(from: plan())

        XCTAssertEqual(composition.effectID, .livingStill)
        XCTAssertEqual(composition.representation, .fcpxmlNative)
        XCTAssertEqual(composition.fallback, "native-push-in-pan-color-enrichment-fade-to-black")
        XCTAssertTrue(composition.nativeFallbackEnabled)
        XCTAssertTrue(composition.preservesOriginal)
        XCTAssertEqual(composition.pixelClassification, .noBakedPixels)
        XCTAssertTrue(composition.noBakedPixels)
        XCTAssertEqual(composition.sourceIdentity.canonicalPath, "/tmp/living-still-source.png")
        XCTAssertEqual(composition.motionMethod, .nativePushInPan)
        XCTAssertEqual(composition.depthFlowStatus, .deferredUnavailable)
        XCTAssertEqual(composition.durationSeconds, 4, accuracy: 0.000001)

        XCTAssertEqual(composition.transformKeyframes.map(\.timeSeconds), [0, 4])
        XCTAssertEqual(composition.transformKeyframes.map(\.scale), [1, 1.08])
        let finalTransform = try XCTUnwrap(composition.transformKeyframes.last)
        XCTAssertEqual(finalTransform.panX, 0.02, accuracy: 0.000001)
        XCTAssertEqual(finalTransform.panY, 0, accuracy: 0.000001)
        XCTAssertEqual(composition.colorKeyframes.map(\.timeSeconds), [0, 4])
        XCTAssertEqual(composition.colorKeyframes.map(\.enrichment), [0, 0.12])
        XCTAssertEqual(composition.opacityKeyframes.map(\.timeSeconds), [0, 3.65, 4])
        XCTAssertEqual(composition.opacityKeyframes.map(\.opacity), [1, 1, 0])
    }

    func testNativeChannelsAreEditableAndDeterministic() throws {
        let operation = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let first = try LivingStillCompositionBuilder.build(from: plan(operationID: operation))
        let second = try LivingStillCompositionBuilder.build(from: plan(operationID: operation))
        XCTAssertEqual(first, second)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(first)
        let decoded = try JSONDecoder().decode(LivingStillComposition.self, from: encoded)
        XCTAssertEqual(decoded, first)
        XCTAssertEqual(try encoder.encode(decoded), encoded)

        XCTAssertEqual(first.transform.count, 2)
        XCTAssertEqual(first.color.count, 2)
        XCTAssertGreaterThanOrEqual(first.opacity.count, 2)
        XCTAssertTrue(first.transform.allSatisfy { $0.timeSeconds >= 0 && $0.timeSeconds <= first.durationSeconds })
        XCTAssertTrue(first.color.allSatisfy { $0.timeSeconds >= 0 && $0.timeSeconds <= first.durationSeconds })
        XCTAssertTrue(first.opacity.allSatisfy { $0.timeSeconds >= 0 && $0.timeSeconds <= first.durationSeconds })
        let finalOpacity = try XCTUnwrap(first.opacity.last)
        XCTAssertEqual(finalOpacity.timeSeconds, first.durationSeconds, accuracy: 0.000001)
        XCTAssertEqual(finalOpacity.opacity, 0, accuracy: 0.000001)
    }

    func testInvalidInputFailsClosed() throws {
        let builder = LivingStillCompositionBuilder.self

        var wrongEffect = try plan()
        wrongEffect.effectID = .oldTelevision
        XCTAssertThrowsError(try builder.build(from: wrongEffect)) { error in
            XCTAssertEqual(error as? LivingStillCompositionError, .wrongEffect(.oldTelevision))
        }

        var invalidDuration = try plan()
        invalidDuration.parameters["durationSeconds"] = .number(.nan)
        XCTAssertThrowsError(try builder.build(from: invalidDuration)) { error in
            XCTAssertEqual(error as? LivingStillCompositionError, .nonFinite("durationSeconds"))
        }

        var invalidFade = try plan()
        invalidFade.parameters["durationSeconds"] = .number(1)
        invalidFade.parameters["fadeDurationSeconds"] = .number(1.5)
        XCTAssertThrowsError(try builder.build(from: invalidFade)) { error in
            XCTAssertEqual(error as? LivingStillCompositionError, .invalidComposition("fade duration exceeds movement duration"))
        }

        var noPreservation = try plan()
        noPreservation.parameters["preserveOriginal"] = .boolean(false)
        XCTAssertThrowsError(try builder.build(from: noPreservation)) { error in
            XCTAssertEqual(error as? LivingStillCompositionError, .invalidComposition("the native fallback must preserve the original still"))
        }

        var bakedMetadata = try plan()
        bakedMetadata.generatedAssets = [GeneratedAssetDefinition(kind: "unexpected", format: "mov")]
        XCTAssertThrowsError(try builder.build(from: bakedMetadata)) { error in
            XCTAssertEqual(error as? LivingStillCompositionError, .invalidComposition("native fallback must not declare generated assets"))
        }

        var invalidSource = try plan()
        invalidSource.selectionToken.sourceIdentities[0].canonicalPath = "relative/still.png"
        XCTAssertThrowsError(try builder.build(from: invalidSource)) { error in
            guard case .invalidSource = error as? LivingStillCompositionError else {
                return XCTFail("expected invalid source, got \(error)")
            }
        }

        var unknown = try plan()
        unknown.parameters["shellCommand"] = .string("not accepted")
        XCTAssertThrowsError(try builder.build(from: unknown)) { error in
            guard case .invalidComposition = error as? LivingStillCompositionError else {
                return XCTFail("expected unknown parameter rejection, got \(error)")
            }
        }
    }
}
