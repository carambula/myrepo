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
    var heroID: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: configuration,
            onDismiss: onDismiss,
            onFollowingChange: onFollowingChange,
            heroID: heroID
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
        context.coordinator.heroID = heroID
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

        override func layoutSubviews() {
            super.layoutSubviews()
            coordinator?.notePossibleDismissal()
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
        var heroID: String?
        weak var probeView: ProbeView?

        private weak var containerView: UIView?
        private weak var sheetView: UIView?
        private weak var dimmingView: UIView?
        private var backdropView: SheetDismissBackdropView?
        private var lastBackdropStrength: CGFloat = 1
        private var pan: UIPanGestureRecognizer?
        private var dragView: UIView?
        private var concealedChrome: [ConcealedChrome] = []
        private var displayLink: CADisplayLink?
        private var lastTranslation: CGSize = .zero
        private var followOrigin: CGSize = .zero
        private var followActivation: EdgeSwipeToDismiss.Activation?
        private var originalDimmingAlpha: CGFloat = 1
        private var systemDimmingWasHidden = false
        private var didCaptureSystemDimmingHidden = false
        private var disabledPans: [UIPanGestureRecognizer] = []
        private var disabledScrollPans: [UIPanGestureRecognizer] = []
        private var cachedScrollViews: [UIScrollView] = []
        private var gestureBeganOnEdge = false
        private var crossedDismissThreshold = false
        private var isDismissing = false
        private var didRevealBackdrop = false
        private var didFadeBackdropOut = false
        private var didRegisterDismissHandler = false
        private var lifecycleHook: SheetPresentationLifecycleHook?
        private var haptic: UIImpactFeedbackGenerator?

        init(
            configuration: EdgeSwipeToDismissConfiguration,
            onDismiss: @escaping () -> Void,
            onFollowingChange: @escaping (Bool, EdgeSwipeToDismiss.Activation) -> Void,
            heroID: String?
        ) {
            self.configuration = configuration
            self.onDismiss = onDismiss
            self.onFollowingChange = onFollowingChange
            self.heroID = heroID
        }

        func attachIfNeeded() {
            guard let probeView, probeView.window != nil else { return }
            guard let resolved = SheetPresentationViews.resolve(from: probeView) else { return }
            if containerView === resolved.container, sheetView === resolved.sheet, pan != nil {
                ensureBackdrop()
                installLifecycleHook()
                registerDismissHandlerIfNeeded()
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
            ensureBackdrop()
            installLifecycleHook()
            registerDismissHandlerIfNeeded()
        }

        private func registerDismissHandlerIfNeeded() {
            guard !didRegisterDismissHandler else { return }
            didRegisterDismissHandler = true
            SheetHeroSession.shared.pushDismissHandler { [weak self] in
                self?.beginProgrammaticDismiss()
            }
        }

        func detach() {
            if didRegisterDismissHandler {
                SheetHeroSession.shared.popDismissHandler()
                didRegisterDismissHandler = false
            }
            stopFollowDisplayLink()
            restoreSheet(removeProxy: true, revealSheet: !isDismissing)
            removeBackdrop(restoreSystemDimming: false)
            removeLifecycleHook()
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
            if !isDismissing {
                didRevealBackdrop = false
                didFadeBackdropOut = false
            }
        }

        private func presentedController() -> UIViewController? {
            if let sheetView {
                return SheetPresentationScrim.presentedViewController(from: sheetView)
            }
            if let probeView {
                return SheetPresentationScrim.presentedViewController(from: probeView)
            }
            return nil
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
            let strength = EdgeSwipeToDismiss.backdropOpacity(progress: progress)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            moving.transform = transform
            applyBackdropStrength(strength)
            concealOriginalSheet()
            CATransaction.commit()
        }

        private func applyBackdropStrength(_ strength: CGFloat, force: Bool = false) {
            let clamped = min(1, max(0, strength))
            // Skip tiny updates — backdrop alpha changes every display tick were a
            // noticeable source of drag jitter. Always apply rest and clear so
            // the shade does not linger as a second pop after the card lands.
            if !force, abs(clamped - lastBackdropStrength) < 0.01, clamped > 0.02, clamped < 0.98 {
                return
            }
            lastBackdropStrength = clamped
            if let backdropView {
                backdropView.strength = clamped
                if force, clamped == 0 {
                    backdropView.alpha = 0
                }
                dimmingView?.alpha = 0
            } else {
                dimmingView?.alpha = originalDimmingAlpha * clamped
            }
        }

        private func ensureBackdrop() {
            guard configuration.usesDimBackdrop else { return }
            guard let container = containerView else { return }
            suppressSystemDimming()
            if let existing = container.subviews.compactMap({ $0 as? SheetDismissBackdropView }).first {
                backdropView = existing
                revealBackdropIfNeeded()
                return
            }
            if let backdropView, backdropView.superview === container {
                revealBackdropIfNeeded()
                return
            }
            backdropView?.removeFromSuperview()
            let backdrop = SheetDismissBackdropView(frame: container.bounds)
            // Stay in the presentation container under the sheet card — never
            // overlay the presenting view (that made the layer below look like
            // it was floating and hurt scroll/drag performance).
            if let dimming = dimmingView, dimming.superview === container {
                container.insertSubview(backdrop, aboveSubview: dimming)
            } else if let sheet = sheetView, sheet.superview === container {
                container.insertSubview(backdrop, belowSubview: sheet)
            } else {
                container.insertSubview(backdrop, at: 0)
            }
            backdropView = backdrop
            lastBackdropStrength = 0
            revealBackdropIfNeeded()
        }

        private func suppressSystemDimming() {
            if let presented = presentedController() {
                SheetPresentationScrim.suppressSystemDimming(for: presented)
            }
            if let container = containerView {
                SheetPresentationScrim.hideSystemSheetDimming(in: container)
            }
            hideSystemDimming()
        }

        private func hideSystemDimming() {
            guard let dimmingView else { return }
            if !didCaptureSystemDimmingHidden {
                systemDimmingWasHidden = dimmingView.isHidden
                didCaptureSystemDimmingHidden = true
            }
            dimmingView.alpha = 0
            dimmingView.isHidden = true
        }

        private func revealBackdropIfNeeded() {
            guard configuration.usesDimBackdrop, let backdropView else { return }
            suppressSystemDimming()
            if backdropView.strength > 0.01 {
                didRevealBackdrop = true
                lastBackdropStrength = backdropView.strength
                return
            }
            guard !didRevealBackdrop else { return }
            didRevealBackdrop = true
            let presented = presentedController()
            let coordinator = presented?.transitionCoordinator
            let animateIn = presented?.isBeingPresented == true || coordinator?.isAnimated == true
            if animateIn {
                backdropView.strength = 0
                lastBackdropStrength = 0
                let animations = {
                    backdropView.strength = 1
                    self.lastBackdropStrength = 1
                }
                if let coordinator, coordinator.isAnimated {
                    coordinator.animate(alongsideTransition: { _ in animations() })
                } else {
                    UIView.animate(
                        withDuration: SheetHeroMotion.openDuration,
                        delay: 0,
                        options: [.curveEaseOut, .beginFromCurrentState],
                        animations: animations
                    )
                }
            } else {
                backdropView.strength = 1
                lastBackdropStrength = 1
            }
        }

        func notePossibleDismissal() {
            if isDismissing { return }
            if presentedController()?.isBeingDismissed == true {
                fadeBackdropOutIfNeeded(animated: true)
            }
        }

        private func fadeBackdropOutIfNeeded(animated: Bool) {
            if isDismissing { return }
            if backdropView?.isGestureDrivenFade == true || backdropView?.isVisuallyClear == true {
                didFadeBackdropOut = true
                applyBackdropStrength(0, force: true)
                return
            }
            guard !didFadeBackdropOut else { return }
            didFadeBackdropOut = true
            suppressSystemDimming()
            let animations = {
                self.backdropView?.strength = 0
                self.backdropView?.alpha = 0
                self.lastBackdropStrength = 0
                self.dimmingView?.alpha = 0
            }
            let presented = presentedController()
            if animated,
               let coordinator = presented?.transitionCoordinator,
               coordinator.isAnimated,
               coordinator.animate(alongsideTransition: { _ in animations() }) {
                return
            }
            if animated {
                UIView.animate(
                    withDuration: SheetHeroMotion.openDuration,
                    delay: 0,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: animations
                )
            } else {
                animations()
            }
        }

        private func installLifecycleHook() {
            guard lifecycleHook == nil else { return }
            guard let presented = presentedController() else { return }
            let hook = SheetPresentationLifecycleHook()
            hook.onWillDisappear = { [weak self] animated in
                guard let self, !self.isDismissing else { return }
                self.fadeBackdropOutIfNeeded(animated: animated)
            }
            presented.addChild(hook)
            hook.view.isHidden = true
            hook.view.frame = .zero
            hook.view.isUserInteractionEnabled = false
            presented.view.insertSubview(hook.view, at: 0)
            hook.didMove(toParent: presented)
            lifecycleHook = hook
        }

        private func removeLifecycleHook() {
            guard let hook = lifecycleHook else { return }
            hook.onWillDisappear = nil
            hook.willMove(toParent: nil)
            hook.view.removeFromSuperview()
            hook.removeFromParent()
            lifecycleHook = nil
        }

        private func removeBackdrop(restoreSystemDimming: Bool) {
            backdropView?.removeFromSuperview()
            backdropView = nil
            lastBackdropStrength = 1
            defer {
                systemDimmingWasHidden = false
                didCaptureSystemDimmingHidden = false
            }
            guard restoreSystemDimming, let dimmingView else { return }
            dimmingView.isHidden = systemDimmingWasHidden
            dimmingView.alpha = originalDimmingAlpha
        }

        private struct ConcealedChrome {
            weak var view: UIView?
            let isHidden: Bool
            let alpha: CGFloat
            let opacity: Float
            let shadowOpacity: Float
            let shadowRadius: CGFloat
            let shadowPath: CGPath?
            let cornerRadius: CGFloat
            let cornerCurve: CALayerCornerCurve
            let maskedCorners: CACornerMask
            let clipsToBounds: Bool
            let masksToBounds: Bool
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
                for view in container.subviews
                where view !== dragView && view !== dimmingView && view !== backdropView {
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
                    shadowPath: view.layer.shadowPath,
                    cornerRadius: view.layer.cornerRadius,
                    cornerCurve: view.layer.cornerCurve,
                    maskedCorners: view.layer.maskedCorners,
                    clipsToBounds: view.clipsToBounds,
                    masksToBounds: view.layer.masksToBounds
                )
            )
        }

        private func concealView(_ view: UIView) {
            rememberChrome(view)
            view.layer.removeAllAnimations()
            // Park far offscreen. UIKit sometimes un-hides the platter during
            // layout; square bottom corners must not peek under the scaled,
            // all-four-corners proxy (that nesting is the dark rim in corners).
            if let container = containerView {
                let dy = container.bounds.height + view.bounds.height + 80
                view.transform = CGAffineTransform(translationX: 0, y: dy)
            } else {
                view.transform = .identity
            }
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
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            card.transform = .identity
            CATransaction.commit()

            let configured = configuration.cardCornerRadius > 0.5
                ? configuration.cardCornerRadius
                : MinCornerRadius.dismissConfiguredRadius
            let radius = EdgeSwipeToDismiss.effectiveCardCornerRadius(
                configured: configured,
                platter: Self.platterCornerRadius(for: card)
            )
            // Round all four corners on the live platter before capture so the
            // bitmap itself has one continuous radius — no square bottoms that
            // can nest under a second clip.
            Self.applyFloatingCardCorners(to: card, radius: radius)
            Self.stripPlatterShadow(from: card)
            card.layoutIfNeeded()
            CATransaction.flush()

            let frameInContainer = card.convert(card.bounds, to: container)
            guard let proxy = Self.makeDragProxy(
                from: card,
                frameInContainer: frameInContainer,
                radius: radius
            ) else { return }

            container.addSubview(proxy)
            container.bringSubviewToFront(proxy)
            dragView = proxy
            concealOriginalSheet()
        }

        /// Single flat image (or fallback snapshot) clipped once — avoids nested
        /// UIVisualEffect / hierarchical snapshot radii fighting each other.
        private static func makeDragProxy(
            from card: UIView,
            frameInContainer: CGRect,
            radius: CGFloat
        ) -> UIView? {
            let proxy: UIView
            if let image = flatSnapshotImage(of: card) {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleToFill
                proxy = imageView
            } else if let snapshot = card.resizableSnapshotView(
                from: card.bounds,
                afterScreenUpdates: true,
                withCapInsets: .zero
            ) ?? card.snapshotView(afterScreenUpdates: true) {
                proxy = snapshot
            } else {
                return nil
            }

            proxy.frame = frameInContainer
            proxy.isUserInteractionEnabled = false
            proxy.backgroundColor = .clear
            applyFloatingCardCorners(to: proxy, radius: radius)
            proxy.layer.shadowOpacity = 0
            proxy.layer.shadowRadius = 0
            proxy.layer.shadowPath = nil
            return proxy
        }

        private static func flatSnapshotImage(of view: UIView) -> UIImage? {
            let size = view.bounds.size
            guard size.width > 1, size.height > 1 else { return nil }
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = view.traitCollection.displayScale
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { _ in
                let drawn = view.drawHierarchy(
                    in: CGRect(origin: .zero, size: size),
                    afterScreenUpdates: true
                )
                if !drawn, let ctx = UIGraphicsGetCurrentContext() {
                    view.layer.render(in: ctx)
                }
            }
            guard image.size.width > 1, image.size.height > 1 else { return nil }
            return image
        }

        private static func applyFloatingCardCorners(to view: UIView, radius: CGFloat) {
            view.layer.cornerRadius = radius
            view.layer.cornerCurve = .continuous
            view.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            view.clipsToBounds = true
            view.layer.masksToBounds = true
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
                self.applyBackdropStrength(1, force: true)
            } completion: { _ in
                self.restoreSheet(removeProxy: true)
                self.endFollowing()
            }
        }

        private func isNestedSheet() -> Bool {
            guard let presented = presentedController() else { return false }
            return presented.presentingViewController?.presentingViewController != nil
        }

        private func beginProgrammaticDismiss() {
            guard !isDismissing else { return }
            if followActivation == nil {
                followActivation = .edge
                onFollowingChange(true, .edge)
                startProxyIfNeeded()
            }
            if movingView == nil {
                isDismissing = true
                beginGestureDrivenFade()
                applyBackdropStrength(0, force: true)
                if let sheetView {
                    finishDismiss(sheet: sheetView)
                } else {
                    onDismiss()
                }
                return
            }
            flingAway(from: lastTranslation, velocity: .zero)
        }

        private func beginGestureDrivenFade() {
            backdropView?.isGestureDrivenFade = true
            didFadeBackdropOut = true
        }

        private func flingAway(from translation: CGSize, velocity: CGSize) {
            guard movingView != nil, !isDismissing else { return }
            // A sheet sitting on another sheet uses ordinary dismiss, not zoom.
            if !isNestedSheet(),
               let heroID,
               let source = SheetHeroGeometry.frame(for: heroID),
               source.width > 2,
               source.height > 2 {
                flingToHero(
                    sourceInWindow: source,
                    radius: SheetHeroGeometry.cornerRadius(for: heroID),
                    velocity: velocity
                )
                return
            }
            flingOffscreen(from: translation, velocity: velocity)
        }

        /// Shrink the floating card onto the source image so the key art looks
        /// like it is flying back into its thumbnail.
        private func flingToHero(sourceInWindow: CGRect, radius: CGFloat, velocity: CGSize) {
            isDismissing = true
            beginGestureDrivenFade()
            SheetHeroSession.shared.cover(heroID)
            startProxyIfNeeded()
            guard let proxy = dragView ?? movingView,
                  let sheetView,
                  let container = containerView ?? proxy.superview else {
                isDismissing = false
                flingOffscreen(from: lastTranslation, velocity: velocity)
                return
            }

            let visual = proxy.convert(proxy.bounds, to: container)
            let source = container.convert(sourceInWindow, from: nil)
            let originalSize = proxy.bounds.size
            guard visual.width > 2, source.width > 2, originalSize.width > 2 else {
                isDismissing = false
                flingOffscreen(from: lastTranslation, velocity: velocity)
                return
            }

            let clip = UIView(frame: visual)
            clip.isUserInteractionEnabled = false
            clip.clipsToBounds = true
            clip.layer.masksToBounds = true
            clip.layer.cornerCurve = .continuous
            clip.layer.cornerRadius = max(proxy.layer.cornerRadius, 1)
            clip.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            proxy.layer.removeAllAnimations()
            proxy.transform = .identity
            proxy.removeFromSuperview()
            proxy.layer.anchorPoint = CGPoint(x: 0, y: 0)
            proxy.frame = CGRect(origin: .zero, size: originalSize)
            let liveScale = visual.width / originalSize.width
            proxy.transform = CGAffineTransform(scaleX: liveScale, y: liveScale)
            clip.addSubview(proxy)
            container.addSubview(clip)
            container.bringSubviewToFront(clip)
            dragView = clip
            CATransaction.commit()

            let sourceOnScreen = heroID.map { SheetHeroGeometry.isOnScreen($0) } ?? false
            let fillImage = heroID.flatMap { SheetHeroGeometry.image(for: $0) }
            let fillView: UIImageView?
            if !sourceOnScreen, let fillImage {
                let imageView = UIImageView(image: fillImage)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.frame = clip.bounds
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.alpha = 0
                clip.addSubview(imageView)
                fillView = imageView
            } else {
                fillView = nil
            }

            let scale = EdgeSwipeToDismiss.heroReturnScale(
                currentWidth: originalSize.width,
                sourceWidth: source.width
            )
            let duration = EdgeSwipeToDismiss.heroReturnDuration(
                from: visual,
                to: source,
                velocity: velocity,
                configuration: configuration
            )

            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                clip.frame = source
                clip.layer.cornerRadius = radius
                proxy.transform = CGAffineTransform(scaleX: scale, y: scale)
                fillView?.alpha = 1
                self.applyBackdropStrength(0, force: true)
            } completion: { _ in
                self.stopFollowDisplayLink()
                self.finishDismiss(sheet: sheetView)
            }
        }

        private func flingOffscreen(from translation: CGSize, velocity: CGSize) {
            guard let moving = movingView, let sheetView, !isDismissing else { return }
            isDismissing = true
            beginGestureDrivenFade()
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
                self.applyBackdropStrength(0, force: true)
            } completion: { _ in
                self.stopFollowDisplayLink()
                self.finishDismiss(sheet: sheetView)
            }
        }

        private func finishDismiss(sheet: UIView) {
            SheetHeroSession.shared.uncover(heroID)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            sheet.isHidden = true
            sheet.alpha = 0
            sheet.transform = .identity
            applyBackdropStrength(0, force: true)
            CATransaction.commit()
            // Let the real tile paint under the flying clip before the clip
            // is removed, so the swap is one object instead of a hole.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.restoreSheet(removeProxy: true, revealSheet: false)
                self.removeBackdrop(restoreSystemDimming: false)
                self.endFollowing()
                self.onDismiss()
            }
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
                        view.layer.cornerRadius = item.cornerRadius
                        view.layer.cornerCurve = item.cornerCurve
                        view.layer.maskedCorners = item.maskedCorners
                        view.clipsToBounds = item.clipsToBounds
                        view.layer.masksToBounds = item.masksToBounds
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
    @Environment(\.sheetHeroPresentedID) private var heroID
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
            .minSheetCornerRadius()
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
                    onFollowingChange: onFollowingChange,
                    heroID: heroID
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
