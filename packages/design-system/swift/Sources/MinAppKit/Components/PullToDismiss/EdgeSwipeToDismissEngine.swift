#if os(iOS)
import SwiftUI
import UIKit

/// Invisible host that attaches an edge-pan recognizer to the untransformed
/// presentation container so the sheet card can follow the finger 1:1.
///
/// UISheetPresentationController owns the presented view's transform and will
/// reset it during layout. Measuring translation in that view, or dismissing
/// while it is still on-screen, produces "nothing while dragging, then fly off,
/// snap back, and vanish." This host:
/// - pans against the container (stable coordinate space)
/// - moves a snapshot proxy under the finger
/// - flings along the drag trajectory at a clamped speed
/// - hides the card, then dismisses without animation
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

        private weak var containerView: UIView?
        private weak var sheetView: UIView?
        private weak var dimmingView: UIView?
        private var pan: UIPanGestureRecognizer?
        private var dragView: UIView?
        private var displayLink: CADisplayLink?
        private var lastTranslation: CGSize = .zero
        private var originalDimmingAlpha: CGFloat = 1
        private var disabledPans: [UIPanGestureRecognizer] = []
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
            if containerView === resolved.container, sheetView === resolved.sheet, pan != nil {
                return
            }

            detach()
            containerView = resolved.container
            sheetView = resolved.sheet
            dimmingView = resolved.dimming
            originalDimmingAlpha = resolved.dimming?.alpha ?? 1

            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            gesture.delegate = self
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = true
            resolved.container.addGestureRecognizer(gesture)
            pan = gesture
            disableCompetingPans()
        }

        func detach() {
            stopFollowDisplayLink()
            restoreSheet(removeProxy: true, revealSheet: !isDismissing)
            reenableCompetingPans()
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
            pan = nil
            containerView = nil
            sheetView = nil
            dimmingView = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !isDismissing, let sheetView, let reference = gestureReferenceView else {
                return false
            }
            let location: CGPoint
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let current = pan.location(in: sheetView)
                let translation = Self.size(from: pan.translation(in: reference))
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
            guard let reference = gestureReferenceView else { return }
            let translation = Self.size(from: gesture.translation(in: reference))
            let velocity = Self.size(from: gesture.velocity(in: reference))

            switch gesture.state {
            case .began:
                crossedDismissThreshold = false
                lastTranslation = translation
                originalDimmingAlpha = dimmingView?.alpha ?? 1
                disableCompetingPans()
                startProxyIfNeeded()
                startFollowDisplayLink()
                prepareHaptic(style: .light)
                haptic?.impactOccurred()
                applyFollow(translation)
            case .changed:
                lastTranslation = translation
                applyFollow(translation)
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
                stopFollowDisplayLink()
                let shouldDismiss = gesture.state == .ended && EdgeSwipeToDismiss.shouldDismiss(
                    translation: translation,
                    velocity: velocity,
                    configuration: configuration
                )
                if shouldDismiss {
                    flingAway(from: translation, velocity: velocity)
                } else {
                    snapBack()
                }
            default:
                break
            }
        }

        private var gestureReferenceView: UIView? {
            containerView ?? sheetView
        }

        private var movingView: UIView? {
            dragView ?? sheetView
        }

        private func applyFollow(_ translation: CGSize) {
            guard let moving = movingView else { return }
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
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            moving.transform = transform
            dimmingView?.alpha = dimmingAlpha
            CATransaction.commit()
        }

        private func startProxyIfNeeded() {
            guard dragView == nil, let sheet = sheetView, let container = containerView else { return }
            sheet.layer.removeAllAnimations()
            let frameInContainer = sheet.convert(sheet.bounds, to: container)
            guard let snapshot = sheet.snapshotView(afterScreenUpdates: false),
                  snapshot.layer.contents != nil || !snapshot.subviews.isEmpty else {
                return
            }
            snapshot.frame = frameInContainer
            snapshot.isUserInteractionEnabled = false
            snapshot.layer.cornerRadius = sheet.layer.cornerRadius
            snapshot.clipsToBounds = sheet.clipsToBounds
            container.addSubview(snapshot)
            dragView = snapshot
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            sheet.alpha = 0
            CATransaction.commit()
        }

        private func startFollowDisplayLink() {
            stopFollowDisplayLink()
            let link = CADisplayLink(target: self, selector: #selector(tickFollow))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopFollowDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func tickFollow() {
            applyFollow(lastTranslation)
        }

        private func snapBack() {
            guard let moving = movingView else {
                restoreSheet(removeProxy: true)
                return
            }
            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.6,
                options: [.beginFromCurrentState, .curveEaseOut]
            ) {
                moving.transform = .identity
                self.dimmingView?.alpha = self.originalDimmingAlpha
            } completion: { _ in
                self.restoreSheet(removeProxy: true)
            }
        }

        private func flingAway(from translation: CGSize, velocity: CGSize) {
            guard let moving = movingView, let sheetView, !isDismissing else { return }
            isDismissing = true
            let fly = EdgeSwipeToDismiss.dismissTranslation(
                translation,
                sheetSize: sheetView.bounds.size,
                velocity: velocity
            )
            let duration = EdgeSwipeToDismiss.flingDuration(
                translation: translation,
                velocity: velocity,
                sheetSize: sheetView.bounds.size,
                configuration: configuration
            )
            let transform = EdgeSwipeToDismiss.transform(
                translation: translation,
                progress: 1,
                configuration: configuration,
                dismissing: true,
                dismissTranslation: fly
            )
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                moving.transform = transform
                moving.alpha = 0
                self.dimmingView?.alpha = 0
            } completion: { _ in
                self.finishDismiss(sheet: sheetView)
            }
        }

        private func finishDismiss(sheet: UIView) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            sheet.isHidden = true
            sheet.alpha = 0
            sheet.transform = .identity
            dimmingView?.alpha = 0
            CATransaction.commit()
            restoreSheet(removeProxy: true, revealSheet: false)
            onDismiss()
        }

        private func restoreSheet(removeProxy: Bool, revealSheet: Bool = true) {
            if revealSheet, let sheet = sheetView {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                sheet.alpha = 1
                sheet.isHidden = false
                sheet.transform = .identity
                CATransaction.commit()
            }
            if removeProxy {
                dragView?.removeFromSuperview()
                dragView = nil
            }
        }

        private func disableCompetingPans() {
            reenableCompetingPans()
            var seen = Set<ObjectIdentifier>()
            func disable(on view: UIView?) {
                guard let view else { return }
                for recognizer in view.gestureRecognizers ?? [] {
                    guard let pan = recognizer as? UIPanGestureRecognizer, pan !== self.pan else { continue }
                    if pan.view is UIScrollView { continue }
                    let id = ObjectIdentifier(pan)
                    guard !seen.contains(id) else { continue }
                    seen.insert(id)
                    if pan.isEnabled {
                        pan.isEnabled = false
                        disabledPans.append(pan)
                    }
                }
            }
            disable(on: containerView)
            disable(on: sheetView)
            for subview in containerView?.subviews ?? [] {
                disable(on: subview)
            }
        }

        private func reenableCompetingPans() {
            for pan in disabledPans {
                pan.isEnabled = true
            }
            disabledPans.removeAll()
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
    static func resolve(from start: UIView) -> (container: UIView, sheet: UIView, dimming: UIView?)? {
        if let fromPresentation = resolveFromPresentation(start) {
            return fromPresentation
        }
        return resolveFromHierarchy(start)
    }

    private static func resolveFromPresentation(_ start: UIView) -> (container: UIView, sheet: UIView, dimming: UIView?)? {
        var responder: UIResponder? = start
        var host: UIViewController?
        while let current = responder {
            if let viewController = current as? UIViewController {
                host = viewController
                break
            }
            responder = current.next
        }

        var node = host
        while let viewController = node {
            if viewController.presentingViewController != nil,
               let presentation = viewController.presentationController,
               let container = presentation.containerView,
               let sheet = presentation.presentedView {
                return (container, sheet, dimming(adjacentTo: sheet, in: container))
            }
            node = viewController.parent
        }
        return nil
    }

    private static func resolveFromHierarchy(_ start: UIView) -> (container: UIView, sheet: UIView, dimming: UIView?)? {
        var current: UIView? = start
        while let view = current {
            let name = NSStringFromClass(type(of: view))
            if name.contains("DropShadow"), let container = view.superview {
                return (container, view, dimming(adjacentTo: view, in: container))
            }
            current = view.superview
        }

        current = start
        while let view = current {
            if let superview = view.superview {
                let superName = NSStringFromClass(type(of: superview))
                if superview is UIWindow || superName.contains("Transition") {
                    return (superview, view, dimming(adjacentTo: view, in: superview))
                }
            }
            current = view.superview
        }
        return nil
    }

    static func dimming(adjacentTo sheet: UIView, in container: UIView? = nil) -> UIView? {
        let siblings = (container ?? sheet.superview)?.subviews ?? []
        if let named = siblings.first(where: {
            $0 !== sheet && NSStringFromClass(type(of: $0)).contains("Dimming")
        }) {
            return named
        }
        return siblings.first { sibling in
            sibling !== sheet && sibling.bounds.size == (container ?? sheet.superview)?.bounds.size
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
        content
            .interactiveDismissDisabled(true)
            .background(
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
    /// The sheet follows the finger in realtime; release past the distance or
    /// velocity threshold flings it away along the drag, otherwise it snaps back.
    public func edgeSwipeToDismiss(
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> some View {
        modifier(EdgeSwipeToDismissModifier(configuration: configuration))
    }
}
#endif
