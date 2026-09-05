#if os(iOS)
import UIKit

/// Snapshot of the scroll observer's current state.
public struct PullToDismissScrollState {
    public var hasAttachedScrollView: Bool = false
    public var isAtBottom: Bool = false
    public var overscrollDistance: CGFloat = 0
    public var isDragging: Bool = false
}

/// KVO-based observer that tracks `contentOffset` and pan gesture state
/// across one or more `UIScrollView` instances to detect overscroll.
public final class PullToDismissScrollObserver: NSObject {
    public var onStateChange: ((PullToDismissScrollState) -> Void)?
    public private(set) var state = PullToDismissScrollState()

    private var observedScrollViews: [ObjectIdentifier: UIScrollView] = [:]
    private var contentOffsetObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var panStateObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]

    public override init() {
        super.init()
    }

    public func observe(scrollViews: [UIScrollView]) {
        let uniqueViews = Array(
            Dictionary(
                scrollViews.map { (ObjectIdentifier($0), $0) },
                uniquingKeysWith: { current, _ in current }
            ).values
        )
        let newIDs = Set(uniqueViews.map { ObjectIdentifier($0) })
        let currentIDs = Set(observedScrollViews.keys)

        if newIDs == currentIDs, !newIDs.isEmpty { return }
        teardownObservers(publishReset: false)
        guard !uniqueViews.isEmpty else { return }

        state.hasAttachedScrollView = true
        publishState()

        for scrollView in uniqueViews {
            let id = ObjectIdentifier(scrollView)
            observedScrollViews[id] = scrollView

            contentOffsetObservations[id] = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                self?.updateMetrics(for: sv)
            }

            panStateObservations[id] = scrollView.panGestureRecognizer.observe(\.state, options: [.new]) { [weak self] _, change in
                guard let gs = change.newValue else { return }
                self?.handlePanStateChange(state: gs)
            }
        }

        if let seed = uniqueViews.max(by: { Self.overflow(for: $0) < Self.overflow(for: $1) }) {
            updateMetrics(for: seed)
        }
    }

    public static func overflow(for scrollView: UIScrollView) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        let visibleHeight = max(1, scrollView.bounds.height - inset.top - inset.bottom)
        return max(0, scrollView.contentSize.height - visibleHeight)
    }

    private func updateMetrics(for scrollView: UIScrollView) {
        let inset = scrollView.adjustedContentInset
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let contentOffsetY = scrollView.contentOffset.y

        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, contentHeight - scrollViewHeight + inset.bottom)
        let distanceFromBottom = max(0, maxOffsetY - contentOffsetY)

        let visibleHeight = scrollViewHeight - inset.top - inset.bottom
        let isScrollable = contentHeight > visibleHeight + 0.5
        let nextIsAtBottom = !isScrollable || distanceFromBottom < 10
        let nextOverscroll = nextIsAtBottom ? max(0, contentOffsetY - maxOffsetY) : 0

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.state.isDragging = self.computeIsDragging()
            self.state.isAtBottom = nextIsAtBottom
            self.state.overscrollDistance = nextOverscroll
            self.publishState()
        }
    }

    private func handlePanStateChange(state: UIGestureRecognizer.State) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.state.isDragging = self.computeIsDragging()
            self.publishState()

            if state == .ended || state == .cancelled || state == .failed {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.state.isDragging = self.computeIsDragging()
                    self.publishState()
                }
            }
        }
    }

    private func computeIsDragging() -> Bool {
        observedScrollViews.values.contains { $0.isTracking }
    }

    private func publishState() {
        let snapshot = state
        let handler = onStateChange
        DispatchQueue.main.async { handler?(snapshot) }
    }

    private func teardownObservers(publishReset: Bool = true) {
        contentOffsetObservations.values.forEach { $0.invalidate() }
        contentOffsetObservations.removeAll()
        panStateObservations.values.forEach { $0.invalidate() }
        panStateObservations.removeAll()
        observedScrollViews.removeAll()

        if publishReset {
            state.hasAttachedScrollView = false
            state.isDragging = false
            publishState()
        }
    }

    deinit {
        teardownObservers(publishReset: false)
    }
}
#endif
