import XCTest
@testable import FCPCommandConsoleCore

final class TargetedTransformMathTests: XCTestCase {
    private let center = Point2D(x: 0.5, y: 0.5)

    func testCenterTargetRemainsAtCenterForAnyTransform() throws {
        let result = try SpatialTransformMath.targetedCompensation(
            source: center,
            scale: 2.4,
            rotationDegrees: 137,
            centeringProgress: 0.35,
            center: center
        )

        XCTAssertEqual(result.desiredPoint, center)
        XCTAssertEqual(result.transformedPoint.x, center.x, accuracy: 1e-12)
        XCTAssertEqual(result.transformedPoint.y, center.y, accuracy: 1e-12)
        XCTAssertEqual(result.translation.x, 0, accuracy: 1e-12)
        XCTAssertEqual(result.translation.y, 0, accuracy: 1e-12)
        let applied = SpatialTransformMath.apply(
            point: center,
            scale: result.scale,
            rotationDegrees: result.rotationDegrees,
            translation: result.translation,
            center: center
        )
        XCTAssertEqual(applied.x, center.x, accuracy: 1e-12)
        XCTAssertEqual(applied.y, center.y, accuracy: 1e-12)
    }

    func testOffCenterStartAndEndFollowCenterwardInvariant() throws {
        let source = Point2D(x: 0.8, y: 0.3)
        let start = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: 1,
            rotationDegrees: 0,
            centeringProgress: 0,
            center: center
        )
        XCTAssertEqual(start.desiredPoint, source)
        XCTAssertEqual(start.translation.x, 0, accuracy: 1e-12)
        XCTAssertEqual(start.translation.y, 0, accuracy: 1e-12)
        let startApplied = SpatialTransformMath.apply(
            point: source,
            scale: 1,
            rotationDegrees: 0,
            translation: start.translation,
            center: center
        )
        XCTAssertEqual(startApplied.x, source.x, accuracy: 1e-12)
        XCTAssertEqual(startApplied.y, source.y, accuracy: 1e-12)

        let end = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: 1.8,
            rotationDegrees: -22,
            centeringProgress: 1,
            center: center
        )
        XCTAssertEqual(end.desiredPoint, center)
        let endApplied = SpatialTransformMath.apply(
            point: source,
            scale: 1.8,
            rotationDegrees: -22,
            translation: end.translation,
            center: center
        )
        XCTAssertEqual(endApplied.x, center.x, accuracy: 1e-12)
        XCTAssertEqual(endApplied.y, center.y, accuracy: 1e-12)
    }

    func testRotatedScaledIntermediatePointIsExactSegmentFraction() throws {
        let source = Point2D(x: 0.82, y: 0.18)
        let progress = 0.4
        let result = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: 1.65,
            rotationDegrees: 47,
            centeringProgress: progress,
            center: center
        )

        let expected = Point2D(
            x: source.x + progress * (center.x - source.x),
            y: source.y + progress * (center.y - source.y)
        )
        XCTAssertEqual(result.desiredPoint.x, expected.x, accuracy: 1e-12)
        XCTAssertEqual(result.desiredPoint.y, expected.y, accuracy: 1e-12)
        let applied = SpatialTransformMath.apply(
            point: source,
            scale: 1.65,
            rotationDegrees: 47,
            translation: result.translation,
            center: center
        )
        XCTAssertEqual(applied.x, expected.x, accuracy: 1e-12)
        XCTAssertEqual(applied.y, expected.y, accuracy: 1e-12)
    }

    func testInvalidProgressScaleAndNonFiniteInputsThrowTypedErrors() {
        let source = Point2D(x: 0.8, y: 0.3)
        for progress in [-0.01, 1.01, .nan] {
            XCTAssertThrowsError(try SpatialTransformMath.targetedCompensation(
                source: source,
                scale: 1,
                rotationDegrees: 0,
                centeringProgress: progress,
                center: center
            )) { error in
                guard case TransformMathError.invalidCenteringProgress = error else {
                    return XCTFail("unexpected error: \(error)")
                }
            }
        }

        for scale in [0.0, -1.0, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try SpatialTransformMath.targetedCompensation(
                source: source,
                scale: scale,
                rotationDegrees: 0,
                centeringProgress: 0.5,
                center: center
            )) { error in
                guard case TransformMathError.invalidScale = error else {
                    return XCTFail("unexpected error: \(error)")
                }
            }
        }

        XCTAssertThrowsError(try SpatialTransformMath.targetedCompensation(
            source: Point2D(x: .nan, y: source.y),
            scale: 1,
            rotationDegrees: 0,
            centeringProgress: 0.5,
            center: center
        )) { error in
            guard case TransformMathError.nonFiniteInput("source") = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: 1,
            rotationDegrees: .infinity,
            centeringProgress: 0.5,
            center: center
        )) { error in
            guard case TransformMathError.invalidRotation = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testTwoKeyframeRecipeHasExactTimesValuesAndEasing() throws {
        let source = Point2D(x: 0.72, y: 0.22)
        let recipe = try SpatialTransformMath.targetedKeyframeRecipe(
            source: source,
            durationSeconds: 4,
            scaleStart: 1,
            scaleEnd: 1.3,
            rotationStartDegrees: 0,
            rotationEndDegrees: 12,
            easing: .easeInOut,
            center: center
        )

        XCTAssertEqual(recipe.start.timeSeconds, 0)
        XCTAssertEqual(recipe.end.timeSeconds, 4)
        XCTAssertEqual(recipe.start.scale, 1)
        XCTAssertEqual(recipe.end.scale, 1.3)
        XCTAssertEqual(recipe.start.rotationDegrees, 0)
        XCTAssertEqual(recipe.end.rotationDegrees, 12)
        XCTAssertEqual(recipe.start.centeringProgress, 0)
        XCTAssertEqual(recipe.end.centeringProgress, 1)
        XCTAssertEqual(recipe.easing, .easeInOut)

        let expectedStart = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: 1,
            rotationDegrees: 0,
            centeringProgress: 0,
            center: center
        )
        let expectedEnd = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: 1.3,
            rotationDegrees: 12,
            centeringProgress: 1,
            center: center
        )
        XCTAssertEqual(recipe.start.translation, expectedStart.translation)
        XCTAssertEqual(recipe.end.translation, expectedEnd.translation)

        let startApplied = SpatialTransformMath.apply(
            point: source,
            scale: recipe.start.scale,
            rotationDegrees: recipe.start.rotationDegrees,
            translation: recipe.start.translation,
            center: center
        )
        let endApplied = SpatialTransformMath.apply(
            point: source,
            scale: recipe.end.scale,
            rotationDegrees: recipe.end.rotationDegrees,
            translation: recipe.end.translation,
            center: center
        )
        XCTAssertEqual(startApplied.x, source.x, accuracy: 1e-12)
        XCTAssertEqual(startApplied.y, source.y, accuracy: 1e-12)
        XCTAssertEqual(endApplied.x, center.x, accuracy: 1e-12)
        XCTAssertEqual(endApplied.y, center.y, accuracy: 1e-12)
    }

    func testRecipeRejectsInvalidDurationAndNonFiniteValues() {
        let source = Point2D(x: 0.8, y: 0.3)
        for duration in [0.09, 30.01, .infinity, .nan] {
            XCTAssertThrowsError(try SpatialTransformMath.targetedKeyframeRecipe(
                source: source,
                durationSeconds: duration,
                scaleStart: 1,
                scaleEnd: 1.3,
                rotationStartDegrees: 0,
                rotationEndDegrees: 12,
                easing: .easeOut,
                center: center
            )) { error in
                guard case TransformMathError.invalidDuration = error else {
                    return XCTFail("unexpected error: \(error)")
                }
            }
        }
    }
}
