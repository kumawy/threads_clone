import XCTest
@testable import ThreadsClone

final class FeedRefreshStateTests: XCTestCase {
    func testPullDoesNotStartLoadingUntilDragIsReleased() throws {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(120)

        XCTAssertTrue(state.isDragging)
        XCTAssertNil(state.requestID)
        XCTAssertEqual(state.headerOffset, 60)
        XCTAssertEqual(state.recoveryFade, 0)

        state.setDragging(false)

        XCTAssertFalse(state.isDragging)
        XCTAssertNotNil(state.requestID)
        XCTAssertEqual(state.recoveryFade, 1)
    }

    func testReleaseRequiresAtLeastEightyFourPointsOfPull() {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(83.999)
        state.setDragging(false)
        XCTAssertNil(state.requestID)
        XCTAssertEqual(state.recoveryFade, 0)

        state.setDragging(true)
        state.updatePull(84)
        state.setDragging(false)
        XCTAssertNotNil(state.requestID)
    }

    func testPullUpdatesWithoutAnActiveDragCannotStartRefresh() {
        var state = FeedRefreshState()
        state.updatePull(140)
        state.setDragging(false)

        XCTAssertNil(state.requestID)
        XCTAssertFalse(state.isDragging)
    }

    func testHeaderContinuesFollowingActualBounceWhileLoading() throws {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(120)
        state.setDragging(false)
        let requestID = try XCTUnwrap(state.requestID)

        state.updatePull(80)
        XCTAssertEqual(state.headerOffset, 40)
        XCTAssertEqual(state.titleFade, 1)
        state.updatePull(0)
        XCTAssertEqual(state.headerOffset, 0)
        XCTAssertEqual(state.titleFade, 1)
        XCTAssertEqual(state.requestID, requestID)
    }

    func testRepeatedReleaseAndAnotherDragDoNotDuplicateActiveRequest() throws {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(120)
        state.setDragging(false)
        let requestID = try XCTUnwrap(state.requestID)
        state.recoveryFade = 0.4

        state.setDragging(false)
        state.setDragging(true)
        state.updatePull(180)
        state.setDragging(false)

        XCTAssertEqual(state.requestID, requestID)
        XCTAssertEqual(state.recoveryFade, 0.4)
    }

    func testFinishingPreservesGeometryAndNewDragAlreadyInProgress() throws {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(120)
        state.setDragging(false)
        let firstRequestID = try XCTUnwrap(state.requestID)

        state.setDragging(true)
        state.updatePull(150)
        state.finish(firstRequestID)

        XCTAssertNil(state.requestID)
        XCTAssertEqual(state.recoveryFade, 0)
        XCTAssertTrue(state.isDragging)
        XCTAssertEqual(state.pullDistance, 150)
        XCTAssertEqual(state.headerOffset, 75)

        state.setDragging(false)
        XCTAssertNotNil(state.requestID)
        XCTAssertNotEqual(state.requestID, firstRequestID)
    }

    func testObsoleteCompletionCannotClearANewerRequest() throws {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(120)
        state.setDragging(false)
        let obsoleteID = try XCTUnwrap(state.requestID)
        state.finish(obsoleteID)

        state.setDragging(true)
        state.updatePull(130)
        state.setDragging(false)
        let currentID = try XCTUnwrap(state.requestID)
        state.recoveryFade = 0.6
        state.finish(obsoleteID)

        XCTAssertEqual(state.requestID, currentID)
        XCTAssertEqual(state.recoveryFade, 0.6)
        XCTAssertEqual(state.pullDistance, 130)
    }

    func testCancelResetsPresentationAndRejectsStaleCompletion() throws {
        var state = FeedRefreshState()
        state.setDragging(true)
        state.updatePull(120)
        state.setDragging(false)
        let requestID = try XCTUnwrap(state.requestID)
        state.setDragging(true)
        state.updatePull(60)

        state.cancel()
        state.finish(requestID)

        XCTAssertNil(state.requestID)
        XCTAssertFalse(state.isDragging)
        XCTAssertEqual(state.pullDistance, 0)
        XCTAssertEqual(state.headerOffset, 0)
        XCTAssertEqual(state.recoveryFade, 0)
        XCTAssertEqual(state.titleFade, 0)
    }

    func testNegativePullIsClampedToRestingPosition() {
        var state = FeedRefreshState()
        state.updatePull(-45)

        XCTAssertEqual(state.pullDistance, 0)
        XCTAssertEqual(state.headerOffset, 0)
        XCTAssertEqual(state.titleFade, 0)
    }
}
