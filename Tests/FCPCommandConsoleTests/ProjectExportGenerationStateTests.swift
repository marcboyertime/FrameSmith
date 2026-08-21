import XCTest
@testable import FCPCommandConsoleCore

final class ProjectExportGenerationStateTests: XCTestCase {
    private let preview1 = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let preview2 = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private let export1 = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    private let export2 = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!

    func testStalePreviewCompletionCannotConsumeCurrentGeneration() {
        var state = ProjectExportGenerationState()
        state.beginRenderedPreview(generation: preview1)
        state.beginRenderedPreview(generation: preview2)

        XCTAssertFalse(state.completeRenderedPreview(generation: preview1))
        XCTAssertEqual(state.activeRenderedPreviewGeneration, preview2)
        XCTAssertTrue(state.completeRenderedPreview(generation: preview2))
        XCTAssertNil(state.activeRenderedPreviewGeneration)
    }

    func testDriftCancelsPreviewAndProjectExportOwnership() {
        var state = ProjectExportGenerationState()
        state.beginRenderedPreview(generation: preview1)
        state.beginProjectExport(generation: export1, currentNotice: nil)

        state.cancelForInputDrift()

        XCTAssertNil(state.activeRenderedPreviewGeneration)
        XCTAssertNil(state.activeProjectExportGeneration)
        XCTAssertFalse(state.completeRenderedPreview(generation: preview1))
        XCTAssertEqual(
            state.completeProjectExport(
                generation: export1,
                currentNotice: "The inputs changed.",
                producedArtifact: false
            ),
            .stale(retainArtifact: false, evictOldestCount: 0)
        )
    }

    func testLatePublishedPackageIsRetainedAsStaleWithoutOwningCurrentState() {
        var state = ProjectExportGenerationState()
        state.beginProjectExport(generation: export1, currentNotice: nil)
        state.invalidateProjectExport()

        XCTAssertEqual(
            state.completeProjectExport(
                generation: export1,
                currentNotice: "Exact treatment ready.",
                producedArtifact: true
            ),
            .stale(retainArtifact: true, evictOldestCount: 0)
        )
        XCTAssertEqual(state.staleArtifactCount, 1)
        XCTAssertNil(state.activeProjectExportGeneration)
    }

    func testLateOlderCompletionDoesNotConsumeNewerExport() {
        var state = ProjectExportGenerationState()
        state.beginProjectExport(generation: export1, currentNotice: nil)
        state.beginProjectExport(generation: export2, currentNotice: nil)

        XCTAssertEqual(
            state.completeProjectExport(
                generation: export1,
                currentNotice: nil,
                producedArtifact: true
            ),
            .stale(retainArtifact: true, evictOldestCount: 0)
        )
        XCTAssertEqual(state.activeProjectExportGeneration, export2)
        XCTAssertEqual(
            state.completeProjectExport(
                generation: export2,
                currentNotice: nil,
                producedArtifact: true
            ),
            .current(mayReplaceCurrentNotice: true)
        )
    }

    func testStaleRetentionIsCappedAndReportsEviction() {
        var state = ProjectExportGenerationState(staleArtifactLimit: 2)

        for index in 0..<3 {
            let generation = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
            state.beginProjectExport(generation: generation, currentNotice: nil)
            state.invalidateProjectExport()
            let disposition = state.completeProjectExport(
                generation: generation,
                currentNotice: nil,
                producedArtifact: true
            )
            XCTAssertEqual(
                disposition,
                .stale(retainArtifact: true, evictOldestCount: index == 2 ? 1 : 0)
            )
        }

        XCTAssertEqual(state.staleArtifactCount, 2)
    }

    func testCurrentCompletionPreservesANewerNotice() {
        var state = ProjectExportGenerationState()
        state.beginProjectExport(generation: export1, currentNotice: nil)

        XCTAssertEqual(
            state.completeProjectExport(
                generation: export1,
                currentNotice: "Exact treatment ready for the current plan.",
                producedArtifact: true
            ),
            .current(mayReplaceCurrentNotice: false)
        )
    }
}
