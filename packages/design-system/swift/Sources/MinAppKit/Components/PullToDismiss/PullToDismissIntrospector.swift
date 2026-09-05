#if os(iOS)
import SwiftUI
import UIKit

/// Invisible `UIViewRepresentable` that walks the view hierarchy to find
/// `UIScrollView` candidates, attaching a `PullToDismissScrollObserver` to them.
public struct PullToDismissIntrospector: UIViewRepresentable {
    public let observer: PullToDismissScrollObserver
    public let windowScan: Bool

    public init(observer: PullToDismissScrollObserver, windowScan: Bool = false) {
        self.observer = observer
        self.windowScan = windowScan
    }

    public func makeUIView(context: Context) -> IntrospectionView {
        IntrospectionView(observer: observer, windowScan: windowScan)
    }

    public func updateUIView(_ uiView: IntrospectionView, context: Context) {}

    public final class IntrospectionView: UIView {
        let observer: PullToDismissScrollObserver
        let windowScan: Bool

        init(observer: PullToDismissScrollObserver, windowScan: Bool) {
            self.observer = observer
            self.windowScan = windowScan
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable) required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override public func didMoveToWindow() {
            super.didMoveToWindow()
            attemptAttach(retries: 8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.attemptAttach(retries: 2)
            }
        }

        private func attemptAttach(retries: Int) {
            if attachToScrollView() { return }
            guard retries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.attemptAttach(retries: retries - 1)
            }
        }

        @discardableResult
        private func attachToScrollView() -> Bool {
            var candidates: [UIScrollView] = []
            var parent = superview
            while parent != nil {
                if let sv = parent as? UIScrollView { candidates.append(sv) }
                if let container = parent {
                    candidates.append(contentsOf: findCandidateScrollViews(in: container))
                }
                parent = parent?.superview
            }

            if windowScan, let window {
                candidates.append(contentsOf: findCandidateScrollViews(in: window))
            }

            let deduped = Array(
                Dictionary(
                    candidates.map { (ObjectIdentifier($0), $0) },
                    uniquingKeysWith: { current, _ in current }
                ).values
            )
            observer.observe(scrollViews: deduped)
            return !deduped.isEmpty
        }

        private func findCandidateScrollViews(in root: UIView) -> [UIScrollView] {
            var stack: [UIView] = [root]
            var result: [UIScrollView] = []
            while let current = stack.popLast() {
                if let sv = current as? UIScrollView,
                   sv.isScrollEnabled,
                   sv.bounds.height > 44 {
                    result.append(sv)
                }
                stack.append(contentsOf: current.subviews)
            }
            return result
        }
    }
}
#endif
