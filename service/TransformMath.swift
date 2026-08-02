import Foundation

public struct Point2D: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// Errors raised by the checked targeted-transform helpers.
public enum TransformMathError: Error, LocalizedError, Equatable, Sendable {
    case nonFiniteInput(String)
    case invalidCenteringProgress(Double)
    case invalidScale(Double)
    case invalidRotation(Double)
    case invalidDuration(Double)
    case invalidTime(Double)
    case nonFiniteResult(String)

    public var errorDescription: String? {
        switch self {
        case .nonFiniteInput(let name):
            return "\(name) must be finite"
        case .invalidCenteringProgress(let value):
            return "centeringProgress must be finite and in [0, 1], got \(value)"
        case .invalidScale(let value):
            return "scale must be finite and positive, got \(value)"
        case .invalidRotation(let value):
            return "rotationDegrees must be finite, got \(value)"
        case .invalidDuration(let value):
            return "durationSeconds must be finite and in [0.1, 30], got \(value)"
        case .invalidTime(let value):
            return "timeSeconds must be finite and non-negative, got \(value)"
        case .nonFiniteResult(let name):
            return "\(name) produced a non-finite transform result"
        }
    }
}

/// A checked transform result for the targeted rotate/zoom workflow.
///
/// `translation` is the normalized position offset to apply after the
/// scale/rotation transform.  Its construction guarantees that applying the
/// offset to `source` places the point at `desiredPoint` (within floating
/// point tolerance).
public struct TargetedTransformCompensation: Codable, Equatable, Sendable {
    public var source: Point2D
    public var center: Point2D
    public var scale: Double
    public var rotationDegrees: Double
    public var centeringProgress: Double
    public var desiredPoint: Point2D
    public var transformedPoint: Point2D
    public var translation: Point2D

    internal init(
        source: Point2D,
        center: Point2D,
        scale: Double,
        rotationDegrees: Double,
        centeringProgress: Double,
        desiredPoint: Point2D,
        transformedPoint: Point2D,
        translation: Point2D
    ) {
        self.source = source
        self.center = center
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.centeringProgress = centeringProgress
        self.desiredPoint = desiredPoint
        self.transformedPoint = transformedPoint
        self.translation = translation
    }

}

/// A deterministic keyframe value for the targeted rotate/zoom effect.
public struct TargetedTransformKeyframe: Codable, Equatable, Sendable {
    public var timeSeconds: Double
    public var scale: Double
    public var rotationDegrees: Double
    public var centeringProgress: Double
    public var translation: Point2D

    public init(
        timeSeconds: Double,
        scale: Double,
        rotationDegrees: Double,
        centeringProgress: Double,
        translation: Point2D
    ) throws {
        guard timeSeconds.isFinite, timeSeconds >= 0 else {
            throw TransformMathError.invalidTime(timeSeconds)
        }
        guard scale.isFinite, scale > 0 else {
            throw TransformMathError.invalidScale(scale)
        }
        guard rotationDegrees.isFinite else {
            throw TransformMathError.invalidRotation(rotationDegrees)
        }
        guard centeringProgress.isFinite, (0...1).contains(centeringProgress) else {
            throw TransformMathError.invalidCenteringProgress(centeringProgress)
        }
        guard translation.x.isFinite, translation.y.isFinite else {
            throw TransformMathError.nonFiniteInput("translation")
        }
        self.timeSeconds = timeSeconds
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.centeringProgress = centeringProgress
        self.translation = translation
    }

}

/// The two deterministic keyframes required by targeted rotate/zoom.
public struct TargetedTransformKeyframeRecipe: Codable, Equatable, Sendable {
    public var source: Point2D
    public var center: Point2D
    public var durationSeconds: Double
    public var start: TargetedTransformKeyframe
    public var end: TargetedTransformKeyframe
    public var easing: Easing

    public init(
        source: Point2D,
        durationSeconds: Double,
        scaleStart: Double,
        scaleEnd: Double,
        rotationStartDegrees: Double,
        rotationEndDegrees: Double,
        easing: Easing = .easeInOut,
        center: Point2D = Point2D(x: 0.5, y: 0.5)
    ) throws {
        try SpatialTransformMath.validateRecipeInputs(
            source: source,
            center: center,
            durationSeconds: durationSeconds,
            scaleStart: scaleStart,
            scaleEnd: scaleEnd,
            rotationStartDegrees: rotationStartDegrees,
            rotationEndDegrees: rotationEndDegrees
        )

        let startCompensation = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: scaleStart,
            rotationDegrees: rotationStartDegrees,
            centeringProgress: 0,
            center: center
        )
        let endCompensation = try SpatialTransformMath.targetedCompensation(
            source: source,
            scale: scaleEnd,
            rotationDegrees: rotationEndDegrees,
            centeringProgress: 1,
            center: center
        )
        self.source = source
        self.center = center
        self.durationSeconds = durationSeconds
        self.start = try TargetedTransformKeyframe(
            timeSeconds: 0,
            scale: scaleStart,
            rotationDegrees: rotationStartDegrees,
            centeringProgress: 0,
            translation: startCompensation.translation
        )
        self.end = try TargetedTransformKeyframe(
            timeSeconds: durationSeconds,
            scale: scaleEnd,
            rotationDegrees: rotationEndDegrees,
            centeringProgress: 1,
            translation: endCompensation.translation
        )
        self.easing = easing
    }

}

/// Deterministic normalized-frame transform equations used by the native
/// spatial-conform/crop planner.
public enum SpatialTransformMath {
    /// Raw transform helper preserved for existing callers.  Checked
    /// targeted workflows should use `targetedCompensation` so invalid input
    /// cannot silently produce NaN or infinity.
    public static func transformedPoint(
        _ source: Point2D,
        scale: Double,
        rotationDegrees: Double,
        center: Point2D = Point2D(x: 0.5, y: 0.5)
    ) -> Point2D {
        let radians = normalizedRadians(rotationDegrees)
        let dx = source.x - center.x
        let dy = source.y - center.y
        let rotatedX = dx * cos(radians) - dy * sin(radians)
        let rotatedY = dx * sin(radians) + dy * cos(radians)
        return Point2D(x: center.x + rotatedX * scale, y: center.y + rotatedY * scale)
    }

    /// Checked compensation implementing the centerward target invariant.
    ///
    /// For source `S`, frame center `C`, scale `s`, rotation `r`, and progress
    /// `p`, the desired point is `D = S + p * (C - S)`.  The returned
    /// translation is `D - T`, where `T = C + s * R(r) * (S - C)`.
    public static func targetedCompensation(
        source: Point2D,
        scale: Double,
        rotationDegrees: Double,
        centeringProgress: Double,
        center: Point2D = Point2D(x: 0.5, y: 0.5)
    ) throws -> TargetedTransformCompensation {
        try validatePoint(source, name: "source")
        try validatePoint(center, name: "center")
        try validateScale(scale)
        try validateRotation(rotationDegrees)
        try validateProgress(centeringProgress)

        // This weighted form avoids an intermediate overflow for opposite
        // extreme finite coordinates while preserving both exact endpoints.
        let desired = Point2D(
            x: source.x * (1 - centeringProgress) + center.x * centeringProgress,
            y: source.y * (1 - centeringProgress) + center.y * centeringProgress
        )
        let transformed = transformedPoint(source, scale: scale, rotationDegrees: rotationDegrees, center: center)
        let translation = Point2D(x: desired.x - transformed.x, y: desired.y - transformed.y)
        try validateResultPoint(desired, name: "desiredPoint")
        try validateResultPoint(transformed, name: "transformedPoint")
        try validateResultPoint(translation, name: "translation")
        return TargetedTransformCompensation(
            source: source,
            center: center,
            scale: scale,
            rotationDegrees: rotationDegrees,
            centeringProgress: centeringProgress,
            desiredPoint: desired,
            transformedPoint: transformed,
            translation: translation
        )
    }

    /// Deprecated compatibility wrapper.  A missing progress value means the
    /// end keyframe (progress 1), which centers the target after the transform.
    @available(*, deprecated, message: "Use targetedCompensation(..., centeringProgress:) instead")
    public static func compensate(
        source: Point2D,
        scale: Double,
        rotationDegrees: Double,
        center: Point2D = Point2D(x: 0.5, y: 0.5)
    ) throws -> TargetedTransformCompensation {
        try targetedCompensation(
            source: source,
            scale: scale,
            rotationDegrees: rotationDegrees,
            centeringProgress: 1,
            center: center
        )
    }

    /// Raw application helper preserved for existing callers.
    public static func apply(
        point: Point2D,
        scale: Double,
        rotationDegrees: Double,
        translation: Point2D,
        center: Point2D = Point2D(x: 0.5, y: 0.5)
    ) -> Point2D {
        let transformed = transformedPoint(point, scale: scale, rotationDegrees: rotationDegrees, center: center)
        return Point2D(x: transformed.x + translation.x, y: transformed.y + translation.y)
    }

    public static func targetedKeyframeRecipe(
        source: Point2D,
        durationSeconds: Double,
        scaleStart: Double,
        scaleEnd: Double,
        rotationStartDegrees: Double,
        rotationEndDegrees: Double,
        easing: Easing = .easeInOut,
        center: Point2D = Point2D(x: 0.5, y: 0.5)
    ) throws -> TargetedTransformKeyframeRecipe {
        try TargetedTransformKeyframeRecipe(
            source: source,
            durationSeconds: durationSeconds,
            scaleStart: scaleStart,
            scaleEnd: scaleEnd,
            rotationStartDegrees: rotationStartDegrees,
            rotationEndDegrees: rotationEndDegrees,
            easing: easing,
            center: center
        )
    }

    fileprivate static func validateRecipeInputs(
        source: Point2D,
        center: Point2D,
        durationSeconds: Double,
        scaleStart: Double,
        scaleEnd: Double,
        rotationStartDegrees: Double,
        rotationEndDegrees: Double
    ) throws {
        try validatePoint(source, name: "source")
        try validatePoint(center, name: "center")
        guard durationSeconds.isFinite, (0.1...30).contains(durationSeconds) else {
            throw TransformMathError.invalidDuration(durationSeconds)
        }
        try validateScale(scaleStart)
        try validateScale(scaleEnd)
        try validateRotation(rotationStartDegrees)
        try validateRotation(rotationEndDegrees)
    }

    private static func validatePoint(_ point: Point2D, name: String) throws {
        guard point.x.isFinite, point.y.isFinite else {
            throw TransformMathError.nonFiniteInput(name)
        }
    }

    private static func validateResultPoint(_ point: Point2D, name: String) throws {
        guard point.x.isFinite, point.y.isFinite else {
            throw TransformMathError.nonFiniteResult(name)
        }
    }

    private static func validateScale(_ scale: Double) throws {
        guard scale.isFinite, scale > 0 else {
            throw TransformMathError.invalidScale(scale)
        }
    }

    private static func validateRotation(_ rotationDegrees: Double) throws {
        guard rotationDegrees.isFinite else {
            throw TransformMathError.invalidRotation(rotationDegrees)
        }
    }

    private static func validateProgress(_ centeringProgress: Double) throws {
        guard centeringProgress.isFinite, (0...1).contains(centeringProgress) else {
            throw TransformMathError.invalidCenteringProgress(centeringProgress)
        }
    }

    private static func normalizedRadians(_ rotationDegrees: Double) -> Double {
        let normalizedDegrees = rotationDegrees.truncatingRemainder(dividingBy: 360)
        return normalizedDegrees * .pi / 180
    }
}

public typealias TransformMath = SpatialTransformMath
