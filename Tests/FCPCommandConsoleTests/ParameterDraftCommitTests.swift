import XCTest
@testable import FCPCommandConsoleCore

final class ParameterDraftCommitTests: XCTestCase {
    func testDraftBurstProducesOneAuthoritativeCommit() {
        var state = ParameterDraftCommitState(
            authoritative: ["motionStrength": .number(0.55)]
        )
        for tick in 0...100 {
            state.updateDraft(
                name: "motionStrength",
                value: .number(Double(tick) / 100.0)
            )
        }
        XCTAssertTrue(state.hasUncommittedDraft(for: "motionStrength"))
        XCTAssertEqual(state.commit(name: "motionStrength"), ["motionStrength": .number(1)])
        XCTAssertNil(state.commit(name: "motionStrength"), "a completed gesture commits once")
        XCTAssertEqual(state.value(for: "motionStrength"), .number(1))
    }

    func testRejectedAndDiscardedDraftsRestoreAuthoritativeValues() {
        var state = ParameterDraftCommitState(
            authoritative: ["pushIn": .number(0.03), "panX": .number(0)]
        )
        state.updateDraft(name: "pushIn", value: .number(0.2))
        state.reject(name: "pushIn")
        XCTAssertEqual(state.value(for: "pushIn"), .number(0.03))

        state.updateDraft(name: "pushIn", value: .number(0.1))
        state.updateDraft(name: "panX", value: .number(0.04))
        state.discardAllDrafts()
        XCTAssertEqual(state.value(for: "pushIn"), .number(0.03))
        XCTAssertEqual(state.value(for: "panX"), .number(0))
        XCTAssertFalse(state.hasUncommittedDraft(for: "pushIn"))
    }
}
