import Foundation

public struct MediaPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct MediaSize: Codable, Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct MediaRect: Codable, Equatable, Sendable {
    public let origin: MediaPoint
    public let size: MediaSize

    public init(origin: MediaPoint, size: MediaSize) {
        self.origin = origin
        self.size = size
    }
}

public enum AspectFitPointMappingError: Error, LocalizedError, Equatable, Sendable {
    case nonFiniteCoordinates
    case invalidGeometry
    case outsideDisplayedMedia

    public var errorDescription: String? {
        switch self {
        case .nonFiniteCoordinates: return "Point-mapping coordinates must be finite"
        case .invalidGeometry: return "Point mapping requires positive finite media and container dimensions"
        case .outsideDisplayedMedia: return "Point is in letterbox space or outside displayed media"
        }
    }
}

public enum AspectFitPointMapper {
    /// The rect the media occupies, **centred** in its container.
    ///
    /// Centring is an assumption this mapper makes about the caller's layout,
    /// not something it can observe. A view that draws the media anywhere else
    /// will map every click wrong — and it fails silently in the worst
    /// direction: points over the visible image resolve to letterbox and get
    /// rejected, so the user clicks and simply nothing happens.
    ///
    /// That shipped once. SwiftUI's `GeometryReader` aligns content
    /// top-leading by default, so the target picker drew a portrait image hard
    /// left while this computed it in the middle. Callers must fill the
    /// container they measure.
    public static func displayedRect(media: MediaSize, in container: MediaSize) throws -> MediaRect {
        try validate(media: media, container: container)
        let scale = min(container.width / media.width, container.height / media.height)
        let displayed = MediaSize(width: media.width * scale, height: media.height * scale)
        return MediaRect(
            origin: MediaPoint(x: (container.width - displayed.width) / 2, y: (container.height - displayed.height) / 2),
            size: displayed
        )
    }

    public static func target(for viewPoint: MediaPoint, media: MediaSize, in container: MediaSize) throws -> Target {
        guard viewPoint.x.isFinite, viewPoint.y.isFinite else { throw AspectFitPointMappingError.nonFiniteCoordinates }
        let rect = try displayedRect(media: media, in: container)
        guard viewPoint.x >= rect.origin.x, viewPoint.x <= rect.origin.x + rect.size.width,
              viewPoint.y >= rect.origin.y, viewPoint.y <= rect.origin.y + rect.size.height else {
            throw AspectFitPointMappingError.outsideDisplayedMedia
        }
        return Target.confirmed(
            x: (viewPoint.x - rect.origin.x) / rect.size.width,
            y: (viewPoint.y - rect.origin.y) / rect.size.height
        )
    }

    public static func viewPoint(for target: Target, media: MediaSize, in container: MediaSize) throws -> MediaPoint {
        guard target.isFinite else { throw AspectFitPointMappingError.nonFiniteCoordinates }
        guard target.isInNormalizedBounds else { throw AspectFitPointMappingError.outsideDisplayedMedia }
        let rect = try displayedRect(media: media, in: container)
        return MediaPoint(x: rect.origin.x + rect.size.width * target.x, y: rect.origin.y + rect.size.height * target.y)
    }

    private static func validate(media: MediaSize, container: MediaSize) throws {
        guard media.width.isFinite, media.height.isFinite, container.width.isFinite, container.height.isFinite else {
            throw AspectFitPointMappingError.nonFiniteCoordinates
        }
        guard media.width > 0, media.height > 0, container.width > 0, container.height > 0 else {
            throw AspectFitPointMappingError.invalidGeometry
        }
    }
}
