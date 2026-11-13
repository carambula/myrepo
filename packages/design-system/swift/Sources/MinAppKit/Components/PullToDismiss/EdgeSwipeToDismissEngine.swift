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
    let onFollowingChange: (Bool, EdgeSwipeToDismiss.Activation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: configuration,
            onDismiss: onDismiss,
            onFollowingChange: onFollowingChange
        )
    }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.onDismiss = onDismiss
        context.coordinator.onFollowingChange = onFollowingChange
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
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
        var onFollowingChange: (Bool, EdgeSwipeToDismiss.Activation) -> Void
        weak var probeView: ProbeView?

        private weak var containerView: UIView?
        private weak var sheetView: UIView?
        private weak var dimmingView: UIView?
        private var pan: UIPanGestureRecognizer?
        private var dragView: UIView?
        private var concealedChrome: [ConcealedChrome] = []
        private var displayLink: CADisplayLink?
        private var lastTranslation: CGSize = .zero
        private var followOrigin: CGSize = .zero
        private var followActivation: EdgeSwipeToDismiss.Activation?
        private var originalDimmingAlpha: CGFloat = 1
        private var disabledPans: [UIPanGestureRecognizer] = []
        private var disabledScrollPans: [UIPanGestureRecognizer] = []
        private var cachedScrollViews: [UIScrollView] = []
        private var gestureBeganOnEdge = false
        private var crossedDismissThreshold = false
        private var isDismissing = false
        private var haptic: UIImpactFeedbackGenerator?

        init(
            configuration: EdgeSwipeToDismissConfiguration,
            onDismiss: @escaping () -> Void,
            onFollowingChange: @escaping (Bool, EdgeSwipeToDismiss.Activation) -> Void
        ) {
            self.configuration = configuration
            self.onDismiss = onDismiss
            self.onFollowingChange = onFollowingChange
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
            gesture.cancelsTouchesInView = false
            gesture.delaysTouchesBegan = false
            gesture.delaysTouchesEnded = false
            resolved.container.addGestureRecognizer(gesture)
            pan = gesture
            cachedScrollViews = Self.scrollViews(in: resolved.sheet)
            disableCompetingPans()
        }

        func detach() {
            stopFollowDisplayLink()
            restoreSheet(removeProxy: true, revealSheet: !isDismissing)
            reenableScrollPans()
            reenableCompetingPans()
            if followActivation != nil, !isDismissing {
                endFollowing()
            }
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
            pan = nil
            containerView = nil
            sheetView = nil
            dimmingView = nil
            followActivation = nil
            followOrigin = .zero
            gestureBeganOnEdge = false
            cachedScrollViews = []
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let sheetView else { return true }
            let location = touch.location(in: sheetView)
            gestureBeganOnEdge = EdgeSwipeToDismiss.isOnSheetEdge(
                location,
                in: sheetView.bounds.size,
                configuration: configuration
            )
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !isDismissing, let sheetView else { return false }
            let location = startLocation(in: sheetView, gesture: gestureRecognizer)
            gestureBeganOnEdge = EdgeSwipeToDismiss.isOnSheetEdge(
                location,
                in: sheetView.bounds.size,
                configuration: configuration
            )
            (gestureRecognizer as? UIPanGestureRecognizer)?.cancelsTouchesInView = gestureBeganOnEdge
            if gestureBeganOnEdge {
                return true
            }
            if scrollView(at: location, in: sheetView) != nil {
                return true
            }
            return cachedScrollViews.isEmpty && Self.scrollViews(in: sheetView).isEmpty
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            if gestureBeganOnEdge || followActivation != nil {
                return false
            }
            return other.view is UIScrollView
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            guard other is UIPanGestureRecognizer else { return false }
            return gestureBeganOnEdge
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf other: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard !isDismissing, let reference = gestureReferenceView, let sheetView else { return }
            let translation = Self.size(from: gesture.translation(in: reference))
            let velocity = Self.size(from: gesture.velocity(in: reference))

            switch gesture.state {
            case .began:
                let location = startLocation(in: sheetView, gesture: gesture)
                if gestureBeganOnEdge || EdgeSwipeToDismiss.isOnSheetEdge(
                    location,
                    in: sheetView.bounds.size,
                    configuration: configuration
                ) {
                    followOrigin = .zero
                    beginFollow(translation: translation, activation: .edge)
                }
            case .changed:
                if followActivation != nil {
                    lockAllScrollViews()
                    updateFollow(translation)
                    return
                }
                let location = startLocation(in: sheetView, gesture: gesture)
                let scroll = scrollView(at: location, in: sheetView)
                let atTop = scroll.map(Self.isScrollAtTop) ?? true
                let atBottom = scroll.map(Self.isScrollAtBottom) ?? true
                guard let activation = EdgeSwipeToDismiss.scrollLimitActivation(
                    translation: translation,
                    atTop: atTop,
                    atBottom: atBottom
                ) else { return }
                followOrigin = translation
                lockAllScrollViews()
                beginFollow(translation: .zero, activation: activation)
            case .ended, .cancelled, .failed:
                guard followActivation != nil else {
                    gestureBeganOnEdge = false
                    return
                }
                let relative = followTranslation(translation)
                let visual = EdgeSwipeToDismiss.visualTranslation(
                    relative,
                    activation: followActivation ?? .edge,
                    configuration: configuration
                )
                let shouldDismiss = gesture.state == .ended && EdgeSwipeToDismiss.shouldDismiss(
                    translation: relative,
                    velocity: velocity,
                    configuration: configuration
                )
                if shouldDismiss {
                    flingAway(from: visual, velocity: velocity)
                } else {
                    stopFollowDisplayLink()
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
            dragView ?? visualCard ?? sheetView
        }

        private func beginFollow(
            translation: CGSize,
            activation: EdgeSwipeToDismiss.Activation
        ) {
            guard followActivation == nil else { return }
            followActivation = activation
            crossedDismissThreshold = false
            lastTranslation = translation
            originalDimmingAlpha = dimmingView?.alpha ?? 1
            disableCompetingPans()
            refreshScrollViews()
            disableScrollPans()
            lockAllScrollViews()
            onFollowingChange(true, activation)
            startProxyIfNeeded()
            startFollowDisplayLink()
            prepareHaptic(style: .light)
            haptic?.impactOccurred()
            applyFollow(translation)
        }

        private func followTranslation(_ translation: CGSize) -> CGSize {
            CGSize(
                width: translation.width - followOrigin.width,
                height: translation.height - followOrigin.height
            )
        }

        private func updateFollow(_ translation: CGSize) {
            let relative = followTranslation(translation)
            lastTranslation = relative
            applyFollow(relative)
            let progress = EdgeSwipeToDismiss.progress(
                relative,
                dismissDistance: configuration.dismissDistance
            )
            if progress >= 1, !crossedDismissThreshold {
                crossedDismissThreshold = true
                prepareHaptic(style: .medium)
                haptic?.impactOccurred()
            } else if progress < 1 {
                crossedDismissThreshold = false
            }
        }

        private func startLocation(in sheet: UIView, gesture: UIGestureRecognizer) -> CGPoint {
            let current = gesture.location(in: sheet)
            guard let pan = gesture as? UIPanGestureRecognizer, let reference = gestureReferenceView else {
                return current
            }
            let translation = Self.size(from: pan.translation(in: reference))
            return CGPoint(x: current.x - translation.width, y: current.y - translation.height)
        }

        private func scrollView(at point: CGPoint, in sheet: UIView) -> UIScrollView? {
            var hit = sheet.hitTest(point, with: nil)
            while let view = hit {
                if let scroll = view as? UIScrollView, scroll.isScrollEnabled {
                    return scroll
                }
                hit = view.superview
            }
            return cachedScrollViews.first ?? Self.scrollViews(in: sheet).first
        }

        private func refreshScrollViews() {
            guard let sheetView else {
                cachedScrollViews = []
                return
            }
            cachedScrollViews = Self.scrollViews(in: sheetView)
        }

        private func lockAllScrollViews() {
            if cachedScrollViews.isEmpty {
                refreshScrollViews()
            }
            for scroll in cachedScrollViews {
                lockScroll(scroll)
            }
        }

        private func lockScroll(_ scroll: UIScrollView) {
            let inset = scroll.adjustedContentInset
            let minY = -inset.top
            let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
            var offset = scroll.contentOffset
            offset.y = min(max(offset.y, minY), maxY)
            scroll.setContentOffset(offset, animated: false)
        }

        private func endFollowing() {
            let activation = followActivation ?? .edge
            followActivation = nil
            followOrigin = .zero
            gestureBeganOnEdge = false
            reenableScrollPans()
            onFollowingChange(false, activation)
        }

        private static func isScrollAtTop(_ scroll: UIScrollView) -> Bool {
            EdgeSwipeToDismiss.isScrollAtTop(
                scroll.contentOffset.y,
                insetTop: scroll.adjustedContentInset.top
            )
        }

        private static func isScrollAtBottom(_ scroll: UIScrollView) -> Bool {
            let inset = scroll.adjustedContentInset
            return EdgeSwipeToDismiss.isScrollAtBottom(
                offsetY: scroll.contentOffset.y,
                contentHeight: scroll.contentSize.height,
                boundsHeight: scroll.bounds.height,
                insetTop: inset.top,
                insetBottom: inset.bottom
            )
        }

        private static func scrollViews(in root: UIView) -> [UIScrollView] {
            var stack: [UIView] = [root]
            var result: [UIScrollView] = []
            while let current = stack.popLast() {
                if let scroll = current as? UIScrollView, scroll.isScrollEnabled, scroll.bounds.height > 44 {
                    result.append(scroll)
                }
                stack.append(contentsOf: current.subviews)
            }
            return result
        }

        private func applyFollow(_ translation: CGSize) {
            guard let moving = movingView else { return }
            let visual = EdgeSwipeToDismiss.visualTranslation(
                translation,
                activation: followActivation ?? .edge,
                configuration: configuration
            )
            let progress = EdgeSwipeToDismiss.progress(
                visual,
                dismissDistance: configuration.dismissDistance
            )
            let transform = EdgeSwipeToDismiss.transform(
                translation: visual,
                progress: progress,
                configuration: configuration
            )
            let dimmingAlpha = originalDimmingAlpha * EdgeSwipeToDismiss.backdropOpacity(progress: progress)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            moving.transform = transform
            dimmingView?.alpha = dimmingAlpha
            concealOriginalSheet()
            CATransaction.commit()
        }

        private struct ConcealedChrome {
            weak var view: UIView?
            let isHidden: Bool
            let alpha: CGFloat
            let opacity: Float
            let shadowOpacity: Float
            let shadowRadius: CGFloat
            let shadowPath: CGPath?
        }

        private func chromeViews() -> [UIView] {
            var views: [UIView] = []
            var current: UIView? = sheetView
            while let view = current, view !== containerView {
                views.append(view)
                if NSStringFromClass(type(of: view)).contains("DropShadow") {
                    break
                }
                current = view.superview
            }
            return views
        }

        private var visualCard: UIView? {
            chromeViews().last ?? sheetView
        }

        /// UISheetPresentationController will restore the live card's alpha/transform
        /// during layout. Keep it fully gone the entire time a proxy is on screen,
        /// including its drop shadow — that shadow is the "shade" behind the
        /// rounded corners when the sheet is lifted.
        private func concealOriginalSheet() {
            guard dragView != nil else { return }
            if let container = containerView {
                for view in container.subviews where view !== dragView && view !== dimmingView {
                    concealView(view)
                }
            }
            for view in chromeViews() {
                concealView(view)
            }
        }

        private func rememberChrome(_ view: UIView) {
            if concealedChrome.contains(where: { $0.view === view }) { return }
            concealedChrome.append(
                ConcealedChrome(
                    view: view,
                    isHidden: view.isHidden,
                    alpha: view.alpha,
                    opacity: view.layer.opacity,
                    shadowOpacity: view.layer.shadowOpacity,
                    shadowRadius: view.layer.shadowRadius,
                    shadowPath: view.layer.shadowPath
                )
            )
        }

        private func concealView(_ view: UIView) {
            rememberChrome(view)
            view.layer.removeAllAnimations()
            view.transform = .identity
            view.alpha = 0
            view.layer.opacity = 0
            view.isHidden = true
            view.layer.shadowOpacity = 0
            view.layer.shadowRadius = 0
            view.layer.shadowPath = nil
            for sub in view.subviews {
                let name = NSStringFromClass(type(of: sub)).lowercased()
                if name.contains("shadow") {
                    concealView(sub)
                }
            }
        }

        private func startProxyIfNeeded() {
            guard dragView == nil, let container = containerView, let card = visualCard else { return }
            rememberChrome(card)
            card.layer.removeAllAnimations()
            Self.stripPlatterShadow(from: card)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            card.transform = .identity
            CATransaction.commit()

            let frameInContainer = card.convert(card.bounds, to: container)
            let snapshot = card.resizableSnapshotView(
                from: card.bounds,
                afterScreenUpdates: false,
                withCapInsets: .zero
            ) ?? card.snapshotView(afterScreenUpdates: false)
            guard let snapshot, snapshot.layer.contents != nil || !snapshot.subviews.isEmpty else {
                return
            }
            let radius = EdgeSwipeToDismiss.effectiveCardCornerRadius(
                configured: configuration.cardCornerRadius,
                platter: Self.platterCornerRadius(for: card)
            )
            snapshot.frame = frameInContainer
            snapshot.isUserInteractionEnabled = false
            snapshot.backgroundColor = .clear
            snapshot.layer.cornerRadius = radius
            snapshot.layer.cornerCurve = .continuous
            snapshot.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            snapshot.clipsToBounds = true
            snapshot.layer.masksToBounds = true
            snapshot.layer.shadowOpacity = 0
            snapshot.layer.shadowRadius = 0
            snapshot.layer.shadowPath = nil
            container.addSubview(snapshot)
            container.bringSubviewToFront(snapshot)
            dragView = snapshot
            concealOriginalSheet()
        }

        /// Read the presentation platter only — never walk into scroll content,
        /// which is how player and show sheets used to pick different radii.
        private static func platterCornerRadius(for card: UIView) -> CGFloat {
            if card.layer.cornerRadius > 0.5 {
                return card.layer.cornerRadius
            }
            var current = card.superview
            var depth = 0
            while let view = current, depth < 4 {
                if view.layer.cornerRadius > 0.5 {
                    return view.layer.cornerRadius
                }
                current = view.superview
                depth += 1
            }
            return 0
        }

        /// Only the platter and its immediate shadow siblings — never walk the
        /// scroll content, which gets expensive after a long list.
        private static func stripPlatterShadow(from card: UIView) {
            card.layer.shadowOpacity = 0
            card.layer.shadowRadius = 0
            card.layer.shadowPath = nil
            for sub in card.subviews where NSStringFromClass(type(of: sub)).lowercased().contains("shadow") {
                sub.isHidden = true
                sub.alpha = 0
                sub.layer.shadowOpacity = 0
            }
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
            if isDismissing {
                concealOriginalSheet()
                return
            }
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
                self.endFollowing()
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
                self.stopFollowDisplayLink()
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
            endFollowing()
            onDismiss()
        }

        private func restoreSheet(removeProxy: Bool, revealSheet: Bool = true) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if revealSheet {
                if concealedChrome.isEmpty {
                    for view in chromeViews() {
                        view.isHidden = false
                        view.alpha = 1
                        view.layer.opacity = 1
                        view.transform = .identity
                    }
                } else {
                    for item in concealedChrome {
                        guard let view = item.view else { continue }
                        view.isHidden = item.isHidden
                        view.alpha = item.alpha
                        view.layer.opacity = item.opacity
                        view.layer.shadowOpacity = item.shadowOpacity
                        view.layer.shadowRadius = item.shadowRadius
                        view.layer.shadowPath = item.shadowPath
                        view.transform = .identity
                    }
                }
                sheetView?.isHidden = false
                sheetView?.alpha = 1
                sheetView?.layer.opacity = 1
                sheetView?.transform = .identity
            }
            concealedChrome.removeAll()
            if removeProxy {
                dragView?.removeFromSuperview()
                dragView = nil
            }
            CATransaction.commit()
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

        private func disableScrollPans() {
            reenableScrollPans()
            for scroll in cachedScrollViews {
                let pan = scroll.panGestureRecognizer
                if pan.isEnabled {
                    pan.isEnabled = false
                    disabledScrollPans.append(pan)
                }
            }
        }

        private func reenableScrollPans() {
            for pan in disabledScrollPans {
                pan.isEnabled = true
            }
            disabledScrollPans.removeAll()
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
               let presented = presentation.presentedView {
                let sheet = visualCard(from: presented, in: container)
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

    /// Prefer the drop-shadow platter so we hide the real card, not an inner host.
    static func visualCard(from presented: UIView, in container: UIView) -> UIView {
        var current: UIView? = presented
        while let view = current, view !== container {
            if NSStringFromClass(type(of: view)).contains("DropShadow") {
                return view
            }
            current = view.superview
        }
        if let child = presented.subviews.first(where: {
            NSStringFromClass(type(of: $0)).contains("DropShadow")
        }) {
            return child
        }
        return presented
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
    public let onFollowingChange: (Bool, EdgeSwipeToDismiss.Activation) -> Void

    public init(
        configuration: EdgeSwipeToDismissConfiguration = .default,
        onFollowingChange: @escaping (Bool, EdgeSwipeToDismiss.Activation) -> Void = { _, _ in }
    ) {
        self.configuration = configuration
        self.onFollowingChange = onFollowingChange
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
                    },
                    onFollowingChange: onFollowingChange
                )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            )
    }
}

extension View {
    /// Drag a presented bottom sheet from its edges, or by pulling past the
    /// scroll limit of the content. The sheet follows the finger in realtime;
    /// release past the distance or velocity threshold flings it away along
    /// the drag, otherwise it snaps back.
    public func edgeSwipeToDismiss(
        configuration: EdgeSwipeToDismissConfiguration = .default,
        onFollowingChange: @escaping (Bool, EdgeSwipeToDismiss.Activation) -> Void = { _, _ in }
    ) -> some View {
        modifier(EdgeSwipeToDismissModifier(
            configuration: configuration,
            onFollowingChange: onFollowingChange
        ))
    }
}
#endif
