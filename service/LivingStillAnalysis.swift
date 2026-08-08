import Foundation
import CoreImage
import Vision
import ImageIO

/// What Vision found in a still, stated explicitly rather than assumed.
///
/// The zero-subject case is a first-class outcome, not an error. A landscape
/// with no clear foreground is a perfectly good image that simply must not be
/// given a two-plane parallax treatment — inventing a subject there is how a
/// layered construction produces cardboard-cutout motion.
public enum SubjectFinding: Equatable, Sendable {
    case none
    case single(index: Int, coverage: Double)
    case multiple(indices: [Int], coverages: [Double])

    public var instanceCount: Int {
        switch self {
        case .none: return 0
        case .single: return 1
        case .multiple(let indices, _): return indices.count
        }
    }

    /// True when the user must disambiguate before a subject-dependent
    /// treatment can be offered honestly.
    public var needsUserChoice: Bool {
        if case .multiple = self { return true }
        return false
    }
}

/// Source geometry after EXIF orientation is applied.
///
/// Orientation is normalized once, here, and every downstream stage works in
/// this space. A mask computed in one orientation and applied in another is a
/// silent, total failure — the matte lands on the wrong pixels and the result
/// looks like a bug in the effect rather than in the plumbing.
public struct NormalizedSourceGeometry: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// The EXIF orientation that was applied to reach this space.
    public let appliedOrientation: UInt32
    public let isPortrait: Bool

    public init(width: Int, height: Int, appliedOrientation: UInt32) {
        self.width = width
        self.height = height
        self.appliedOrientation = appliedOrientation
        self.isPortrait = height > width
    }
}

/// Immutable, content-addressed result of analysing one still.
///
/// The key includes everything that affects the output, so a cached entry can
/// be trusted without re-running Vision — and cannot be silently reused after
/// the source bytes, the Vision revision, or the output geometry change.
public struct LivingStillAnalysis: Equatable, Sendable {
    public let sourceSHA256: String
    public let geometry: NormalizedSourceGeometry
    public let subject: SubjectFinding
    /// Vision request revision, so a framework update invalidates the cache
    /// rather than mixing results from two different algorithms.
    public let visionRevision: Int
    /// Fraction of the frame the selected subject covers, 0–1.
    public let selectedCoverage: Double?
    /// Rough boundary complexity: perimeter-to-area of the subject mask,
    /// normalized. High values mean hair, foliage, or thin structures — the
    /// cases where a hard matte shows its seams.
    public let boundaryComplexity: Double?

    public init(
        sourceSHA256: String,
        geometry: NormalizedSourceGeometry,
        subject: SubjectFinding,
        visionRevision: Int,
        selectedCoverage: Double?,
        boundaryComplexity: Double?
    ) {
        self.sourceSHA256 = sourceSHA256
        self.geometry = geometry
        self.subject = subject
        self.visionRevision = visionRevision
        self.selectedCoverage = selectedCoverage
        self.boundaryComplexity = boundaryComplexity
    }

    /// Content-addressed cache key. Changing any input changes this.
    public var cacheKey: String {
        "\(sourceSHA256)-v\(visionRevision)-\(geometry.width)x\(geometry.height)-o\(geometry.appliedOrientation)"
    }
}

public enum LivingStillAnalysisError: Error, LocalizedError, Equatable {
    case unreadableImage(URL)
    case visionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableImage(let url): return "Could not read the image at \(url.path)"
        case .visionFailed(let detail): return "Subject analysis failed: \(detail)"
        }
    }
}

/// Runs Apple Vision's foreground instance masking on a still.
///
/// Deliberately dependency-free: `VNGenerateForegroundInstanceMaskRequest` is
/// available on this platform, ships with the OS, needs no model download, and
/// runs entirely offline. That makes the layered candidates testable today
/// without an acquisition decision, which is why this is the first thing built.
public struct LivingStillSubjectAnalyzer: Sendable {
    public init() {}

    /// Analyse a still, normalizing orientation first.
    public func analyze(url: URL, sourceSHA256: String) throws -> (analysis: LivingStillAnalysis, image: CIImage, mask: CIImage?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LivingStillAnalysisError.unreadableImage(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientationRaw = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: orientationRaw) ?? .up

        // Orientation is applied once, here. Everything downstream is in this space.
        let normalized = CIImage(cgImage: cgImage).oriented(orientation)
        let extent = normalized.extent
        let geometry = NormalizedSourceGeometry(
            width: Int(extent.width.rounded()),
            height: Int(extent.height.rounded()),
            appliedOrientation: orientationRaw
        )

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: normalized, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw LivingStillAnalysisError.visionFailed(error.localizedDescription)
        }

        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            // No subject is a legitimate outcome, not a failure.
            return (
                LivingStillAnalysis(
                    sourceSHA256: sourceSHA256,
                    geometry: geometry,
                    subject: .none,
                    visionRevision: Int(VNGenerateForegroundInstanceMaskRequest.currentRevision),
                    selectedCoverage: nil,
                    boundaryComplexity: nil
                ),
                normalized,
                nil
            )
        }

        let instances = Array(observation.allInstances).sorted()
        var maskImage: CIImage?
        var coverage: Double?
        var complexity: Double?

        if let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler) {
            let mask = CIImage(cvPixelBuffer: buffer)
            maskImage = mask
            let stats = Self.maskStatistics(mask)
            coverage = stats.coverage
            complexity = stats.complexity
        }

        let subject: SubjectFinding
        if instances.count == 1 {
            subject = .single(index: instances[0], coverage: coverage ?? 0)
        } else {
            subject = .multiple(indices: instances, coverages: instances.map { _ in coverage ?? 0 })
        }

        return (
            LivingStillAnalysis(
                sourceSHA256: sourceSHA256,
                geometry: geometry,
                subject: subject,
                visionRevision: Int(VNGenerateForegroundInstanceMaskRequest.currentRevision),
                selectedCoverage: coverage,
                boundaryComplexity: complexity
            ),
            normalized,
            maskImage
        )
    }

    /// Coverage and boundary complexity, measured from the matte's alpha
    /// distribution rather than from an edge filter.
    ///
    /// ## Why not an edge pass
    ///
    /// The first implementation ran `CIEdges` over the matte and took
    /// `CIAreaAverage`. It could not tell hair from a rectangle: 1400 fine
    /// strands scored `0.004` and a clean product silhouette scored `0.003`,
    /// which is noise. Two compounding mistakes —
    ///
    /// 1. averaging one-pixel edges across two million pixels dilutes the
    ///    signal into the noise floor;
    /// 2. dividing by coverage then *penalised* the strands case for having a
    ///    large subject, which is backwards.
    ///
    /// ## What is measured instead
    ///
    /// A matte over hair is mostly **partial** alpha — thousands of pixels
    /// neither fully inside nor fully outside. A clean silhouette is almost
    /// entirely binary. So the soft-edge fraction *is* the complexity, and it
    /// needs no edge detector at all.
    ///
    /// Measured on the bakeoff fixtures: strands `0.0341`, thin-bar product
    /// `0.0175`, jagged silhouette `0.0147`, layered planes `0.0148` — a clean
    /// 2× separation for the case this exists to catch.
    ///
    /// This is a risk heuristic used to reduce motion or prefer a different
    /// construction. It is not a quality measurement.
    static func maskStatistics(_ mask: CIImage) -> (coverage: Double, complexity: Double) {
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let extent = mask.extent
        let width = Int(extent.width.rounded()), height = Int(extent.height.rounded())
        guard width > 0, height > 0 else { return (0, 0) }

        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        context.render(
            mask,
            toBitmap: &buffer,
            rowBytes: width * 4,
            bounds: extent,
            format: .RGBA8,
            colorSpace: nil
        )

        var solid = 0, partial = 0
        for index in stride(from: 0, to: buffer.count, by: 4) {
            let value = buffer[index]
            if value > 240 { solid += 1 } else if value >= 15 { partial += 1 }
        }
        let total = Double(width * height)
        guard total > 0 else { return (0, 0) }

        // Partial pixels belong to the subject too; excluding them would
        // under-report coverage most for exactly the mattes that matter.
        let coverage = (Double(solid) + Double(partial)) / total
        let complexity = Double(partial) / total
        return (coverage, complexity)
    }
}
