import Foundation

struct FeedRefreshState {
    private(set) var pullDistance: CGFloat = 0
    private(set) var isDragging = false
    private(set) var requestID: UUID?
    var recoveryFade: CGFloat = 0

    var headerOffset: CGFloat { pullDistance * 0.5 }
    var titleFade: CGFloat { max(HomeRefreshMotion.titleFade(for: pullDistance), recoveryFade) }

    mutating func updatePull(_ distance: CGFloat) {
        pullDistance = max(0, distance)
    }

    mutating func setDragging(_ dragging: Bool) {
        guard isDragging != dragging else { return }
        isDragging = dragging
        guard !dragging, pullDistance >= 84, requestID == nil else { return }
        requestID = UUID()
        recoveryFade = HomeRefreshMotion.titleFade(for: pullDistance)
    }

    mutating func finish(_ id: UUID) {
        guard requestID == id else { return }
        requestID = nil
        recoveryFade = 0
    }

    mutating func cancel() {
        pullDistance = 0
        isDragging = false
        requestID = nil
        recoveryFade = 0
    }
}
