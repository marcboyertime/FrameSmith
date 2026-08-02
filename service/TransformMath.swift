import Foundation

public struct Point2D: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct AnchorCompensation: Codable, Equatable, Sendable {
    public var transformedPoint: Point2D
    public var translation: Point2D
    public var compensatedAnchor: Point2D

    public init(transformedPoint: Point2D, translation: Point2D, compensatedAnchor: Point2D) {
        self.transformedPoint = transformedPoint; self.translation = translation; self.compensatedAnchor = compensatedAnchor
    }
}

/// Deterministic normalized-frame transform equations used by the native
/// spatial-conform/crop planner:
///
/// `v = source - center`, `q = scale * R(rotation) * v`,
/// `transformed = center + q`, and `translation = source - transformed`.
/// Applying `translation` keeps the selected source point fixed while the
/// default conform/crop zooms around frame center. The project-space anchor is
/// the inverse-transformed point, `center + R(-rotation)*(source-center)/scale`;
/// this deliberately moves an off-centre point toward frame centre as zoom
/// increases while leaving the centre invariant.
public enum SpatialTransformMath {
    public static func transformedPoint(_ source: Point2D, scale: Double, rotationDegrees: Double, center: Point2D = Point2D(x: 0.5, y: 0.5)) -> Point2D {
        let radians = rotationDegrees * .pi / 180
        let dx = source.x - center.x
        let dy = source.y - center.y
        let rotatedX = dx * cos(radians) - dy * sin(radians)
        let rotatedY = dx * sin(radians) + dy * cos(radians)
        return Point2D(x: center.x + rotatedX * scale, y: center.y + rotatedY * scale)
    }

    public static func compensate(source: Point2D, scale: Double, rotationDegrees: Double, center: Point2D = Point2D(x: 0.5, y: 0.5)) -> AnchorCompensation {
        precondition(scale.isFinite && scale > 0, "scale must be finite and positive")
        let transformed = transformedPoint(source, scale: scale, rotationDegrees: rotationDegrees, center: center)
        let translation = Point2D(x: source.x - transformed.x, y: source.y - transformed.y)
        let radians = -rotationDegrees * .pi / 180
        let dx = source.x - center.x
        let dy = source.y - center.y
        let inverseX = dx * cos(radians) - dy * sin(radians)
        let inverseY = dx * sin(radians) + dy * cos(radians)
        let compensatedAnchor = Point2D(x: center.x + inverseX / scale, y: center.y + inverseY / scale)
        return AnchorCompensation(transformedPoint: transformed, translation: translation, compensatedAnchor: compensatedAnchor)
    }

    public static func apply(point: Point2D, scale: Double, rotationDegrees: Double, translation: Point2D, center: Point2D = Point2D(x: 0.5, y: 0.5)) -> Point2D {
        let transformed = transformedPoint(point, scale: scale, rotationDegrees: rotationDegrees, center: center)
        return Point2D(x: transformed.x + translation.x, y: transformed.y + translation.y)
    }
}

public typealias TransformMath = SpatialTransformMath
