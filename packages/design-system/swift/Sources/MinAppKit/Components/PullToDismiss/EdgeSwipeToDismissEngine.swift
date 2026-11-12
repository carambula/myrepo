#if os(iOS)
import SwiftUI
import UIKit

/// Invisible host that attaches an edge-pan recognizer to the presented
/// sheet container so the whole card can be dragged omnidirectionally.
struct EdgeSwipeToDismissHost: UIViewRepresentable {
    let configuration: EdgeSwipeToDismissConfiguration
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(configuration: configuration, onDismiss: onDismiss)
    }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.onDismiss = onDismiss
        uiView.coordinator = context.coordinator
    }

    final class ProbeView: UIView {
        var coordinator: Coordinator? {
            didSet { coordinator?.probeView = self }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        @available(*, unavailable) required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attachIfNeeded()
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.attachIfNeeded()
            }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil {
                coordinator?.detach()
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var configuration: EdgeSwipeToDismissConfiguration
        var onDismiss: () -> Void
        weak var probeView: ProbeView?

        private weak var sheetView: UIView?
        private weak var dimmingView: UIView?
        private var pan: UIPanGestureRecognizer?
        private var originalDimmingAlpha: CGFloat = 1
        private var crossedDismissThreshold = false
        private var isDismissing = false
        private var haptic: UIImpactFeedbackGenerator?

        init(configuration: EdgeSwipeToDismissConfiguration, onDismiss: @escaping () -> Void) {
            self.configuration = configuration
            self.onDismiss = onDismiss
        }

        func attachIfNeeded() {
            guard let probeView, probeView.window != nil else { return }
            guard let resolved = SheetPresentationViews.resolve(from: probeView) else { return }
            if sheetView === resolved.sheet, pan != nil { return }

            detach()
            sheetView = resolved.sheet
            dimmingView = resolved.dimming
            originalDimmingAlpha = resolved.dimming?.alpha ?? 1

            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            gesture.delegate = self
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = true
            resolved.sheet.addGestureRecognizer(gesture)
            pan = gesture
        }

        func detach() {
            if let pan, let sheetView {
                sheetView.removeGestureRecognizer(pan)
            }
            pan = nil
            sheetView = nil
            dimmingView = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !isDismissing, let sheetView else { return false }
            let location: CGPoint
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let current = pan.location(in: sheetView)
                let translation = Self.size(from: pan.translation(in: sheetView))
                location = CGPoint(x: current.x - translation.width, y: current.y - translation.height)
            } else {
                location = gestureRecognizer.location(in: sheetView)
            }
            return EdgeSwipeToDismiss.isOnSheetEdge(
                location,
                in: sheetView.bounds.size,
                configuration: configuration
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            guard other is UIPanGestureRecognizer, let sheetView else { return false }
            let location = gestureRecognizer.location(in: sheetView)
            return EdgeSwipeToDismiss.isOnSheetEdge(
                location,
                in: sheetView.bounds.size,
                configuration: configuration
            )
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sheetView else { return }
            switch gesture.state {
            case .began:
                crossedDismissThreshold = false
                originalDimmingAlpha = dimmingView?.alpha ?? 1
                prepareHaptic(style: .light)
                haptic?.impactOccurred()
                apply(translation: Self.size(from: gesture.translation(in: sheetView)), animated: false)
            case .changed:
                let translation = Self.size(from: gesture.translation(in: sheetView))
                apply(translation: translation, animated: false)
                let progress = EdgeSwipeToDismiss.progress(
                    translation,
                    dismissDistance: configuration.dismissDistance
                )
                if progress >= 1, !crossedDismissThreshold {
                    crossedDismissThreshold = true
                    prepareHaptic(style: .medium)
                    haptic?.impactOccurred()
                } else if progress < 1 {
                    crossedDismissThreshold = false
                }
            case .ended, .cancelled, .failed:
                let translation = Self.size(from: gesture.translation(in: sheetView))
                let velocity = Self.size(from: gesture.velocity(in: sheetView))
                let shouldDismiss = gesture.state == .ended && EdgeSwipeToDismiss.shouldDismiss(
                    translation: translation,
                    velocity: velocity,
                    configuration: configuration
                )
                if shouldDismiss {
                    dismiss(from: translation)
                } else {
                    snapBack()
                }
            default:
                break
            }
        }

        private func apply(translation: CGSize, animated: Bool) {
            guard let sheetView else { return }
            let progress = EdgeSwipeToDismiss.progress(
                translation,
                dismissDistance: configuration.dismissDistance
            )
            let transform = EdgeSwipeToDismiss.transform(
                translation: translation,
                progress: progress,
                configuration: configuration
            )
            let dimmingAlpha = originalDimmingAlpha * EdgeSwipeToDismiss.backdropOpacity(progress: progress)
            let updates = {
                sheetView.transform = transform
                self.dimmingView?.alpha = dimmingAlpha
            }
            if animated {
                UIView.animate(
                    withDuration: 0.35,
                    delay: 0,
                    usingSpringWithDamping: 0.86,
                    initialSpringVelocity: 0.4,
                    options: [.beginFromCurrentState, .allowUserInteraction]
                ) {
                    updates()
                }
            } else {
                updates()
            }
        }

        private func snapBack() {
            guard let sheetView else { return }
            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.6,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                sheetView.transform = .identity
                self.dimmingView?.alpha = self.originalDimmingAlpha
            }
        }

        private func dismiss(from translation: CGSize) {
            guard let sheetView, !isDismissing else { return }
            isDismissing = true
            let fly = EdgeSwipeToDismiss.dismissTranslation(translation, sheetSize: sheetView.bounds.size)
            let transform = EdgeSwipeToDismiss.transform(
                translation: translation,
                progress: 1,
                configuration: configuration,
                dismissing: true,
                dismissTranslation: fly
            )
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState]
            ) {
                sheetView.transform = transform
                sheetView.alpha = 0
                self.dimmingView?.alpha = 0
            } completion: { _ in
                self.onDismiss()
            }
        }

        /// UIKit pan translation/velocity are `CGPoint`; shared math uses `CGSize`.
        private static func size(from point: CGPoint) -> CGSize {
            CGSize(width: point.x, height: point.y)
        }

        private func prepareHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            haptic = generator
        }
    }
}

enum SheetPresentationViews {
    static func resolve(from start: UIView) -> (sheet: UIView, dimming: UIView?)? {
        var current: UIView? = start
        while let view = current {
            let name = NSStringFromClass(type(of: view))
            if name.contains("DropShadow") {
                return (view, dimming(adjacentTo: view))
            }
            current = view.superview
        }

        current = start
        while let view = current {
            if let superview = view.superview {
                let superName = NSStringFromClass(type(of: superview))
                if superview is UIWindow || superName.contains("Transition") {
                    return (view, dimming(adjacentTo: view))
                }
            }
            current = view.superview
        }
        return nil
    }

    static func dimming(adjacentTo sheet: UIView) -> UIView? {
        guard let siblings = sheet.superview?.subviews else { return nil }
        if let named = siblings.first(where: {
            $0 !== sheet && NSStringFromClass(type(of: $0)).contains("Dimming")
        }) {
            return named
        }
        return siblings.first { sibling in
            sibling !== sheet && sibling.bounds.size == sheet.superview?.bounds.size
        }
    }
}

public struct EdgeSwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    public let configuration: EdgeSwipeToDismissConfiguration

    public init(configuration: EdgeSwipeToDismissConfiguration = .default) {
        self.configuration = configuration
    }

    public func body(content: Content) -> some View {
        content.background(
            EdgeSwipeToDismissHost(
                configuration: configuration,
                onDismiss: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        dismiss()
                    }
                }
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }
}

extension View {
    /// Drag a presented bottom sheet omnidirectionally from its edges.
    /// Release past the distance/velocity threshold to dismiss, or let go to snap back.
    public func edgeSwipeToDismiss(
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> some View {
        modifier(EdgeSwipeToDismissModifier(configuration: configuration))
    }
}
#endif
