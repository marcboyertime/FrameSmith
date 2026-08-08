import XCTest
import CoreImage
@testable import FCPCommandConsoleCore

/// Pins the analysis behaviour that Living Still v2 routing will depend on.
///
/// The complexity assertions exist because the first implementation of this
/// metric *silently failed to discriminate* — 1400 hair-like strands and a
/// clean rectangle both scored ~0.003. A metric that returns a plausible number
/// for every input is worse than no metric, because routing built on it looks
/// principled while being random.
final class LivingStillAnalysisTests: XCTestCase {

    /// Builds a synthetic matte: `solidFraction` fully opaque, `softFraction`
    /// partial alpha, remainder transparent.
    private func matte(width: Int, height: Int, solidFraction: Double, softFraction: Double) -> CIImage {
        let total = width * height
        let solid = Int(Double(total) * solidFraction)
        let soft = Int(Double(total) * softFraction)
        var bytes = [UInt8](repeating: 0, count: total * 4)
        for index in 0..<total {
            let value: UInt8
            if index < solid { value = 255 } else if index < solid + soft { value = 128 } else { value = 0 }
            let offset = index * 4
            bytes[offset] = value; bytes[offset + 1] = value
            bytes[offset + 2] = value; bytes[offset + 3] = 255
        }
        return CIImage(
            bitmapData: Data(bytes),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: nil
        )
    }

    /// The regression that motivated the rewrite: a hair-like matte must score
    /// materially above a clean one, not within noise of it.
    func testComplexityDiscriminatesSoftEdgesFromCleanOnes() {
        let clean = LivingStillSubjectAnalyzer.maskStatistics(
            matte(width: 200, height: 200, solidFraction: 0.20, softFraction: 0.005)
        )
        let hairy = LivingStillSubjectAnalyzer.maskStatistics(
            matte(width: 200, height: 200, solidFraction: 0.20, softFraction: 0.05)
        )
        XCTAssertGreaterThan(
            hairy.complexity, clean.complexity * 3,
            "a soft-edged matte must score well above a clean one; the previous edge-average metric returned 0.004 vs 0.003 and was useless"
        )
    }

    /// Coverage must not penalise a subject for having a soft edge. Partial
    /// pixels belong to the subject; excluding them would under-report exactly
    /// the mattes that matter most.
    func testCoverageIncludesPartialPixels() {
        let stats = LivingStillSubjectAnalyzer.maskStatistics(
            matte(width: 100, height: 100, solidFraction: 0.30, softFraction: 0.10)
        )
        XCTAssertEqual(stats.coverage, 0.40, accuracy: 0.02)
    }

    func testEmptyMatteIsZeroRatherThanUndefined() {
        let stats = LivingStillSubjectAnalyzer.maskStatistics(
            matte(width: 50, height: 50, solidFraction: 0, softFraction: 0)
        )
        XCTAssertEqual(stats.coverage, 0, accuracy: 0.001)
        XCTAssertEqual(stats.complexity, 0, accuracy: 0.001)
    }

    /// A no-subject scene is a routing outcome, not an error. Architecture,
    /// text, and real landscapes all return this, and each must be kept away
    /// from any two-plane construction.
    func testNoSubjectIsRepresentableAndNeedsNoUserChoice() {
        let finding = SubjectFinding.none
        XCTAssertEqual(finding.instanceCount, 0)
        XCTAssertFalse(finding.needsUserChoice)
    }

    /// Several instances must ask rather than guess which one the user meant.
    func testMultipleSubjectsRequireDisambiguation() {
        let finding = SubjectFinding.multiple(indices: [1, 2], coverages: [0.2, 0.1])
        XCTAssertEqual(finding.instanceCount, 2)
        XCTAssertTrue(finding.needsUserChoice)
    }

    func testSingleSubjectDoesNotRequireDisambiguation() {
        let finding = SubjectFinding.single(index: 1, coverage: 0.3)
        XCTAssertEqual(finding.instanceCount, 1)
        XCTAssertFalse(finding.needsUserChoice)
    }

    /// The cache key must change when anything affecting the result changes,
    /// or a stale matte gets reused against different pixels.
    func testCacheKeyChangesWithSourceGeometryAndVisionRevision() {
        func analysis(sha: String, width: Int, revision: Int, orientation: UInt32) -> LivingStillAnalysis {
            LivingStillAnalysis(
                sourceSHA256: sha,
                geometry: NormalizedSourceGeometry(width: width, height: 1080, appliedOrientation: orientation),
                subject: .none,
                visionRevision: revision,
                selectedCoverage: nil,
                boundaryComplexity: nil
            )
        }
        let base = analysis(sha: "a", width: 1920, revision: 1, orientation: 1)
        XCTAssertNotEqual(base.cacheKey, analysis(sha: "b", width: 1920, revision: 1, orientation: 1).cacheKey)
        XCTAssertNotEqual(base.cacheKey, analysis(sha: "a", width: 1280, revision: 1, orientation: 1).cacheKey)
        XCTAssertNotEqual(base.cacheKey, analysis(sha: "a", width: 1920, revision: 2, orientation: 1).cacheKey)
        XCTAssertNotEqual(base.cacheKey, analysis(sha: "a", width: 1920, revision: 1, orientation: 6).cacheKey)
        XCTAssertEqual(base.cacheKey, analysis(sha: "a", width: 1920, revision: 1, orientation: 1).cacheKey)
    }

    func testPortraitGeometryIsRecognized() {
        let portrait = NormalizedSourceGeometry(width: 1080, height: 1920, appliedOrientation: 1)
        XCTAssertTrue(portrait.isPortrait)
        XCTAssertFalse(NormalizedSourceGeometry(width: 1920, height: 1080, appliedOrientation: 1).isPortrait)
    }
}
