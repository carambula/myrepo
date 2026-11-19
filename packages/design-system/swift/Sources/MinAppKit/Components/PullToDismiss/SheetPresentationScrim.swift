#if os(iOS)
import SwiftUI
import UIKit

/// Hides the system sheet dimming view so min apps can fade their own plate
/// in and out with the zoom / dismiss animation instead of popping it.
enum SheetPresentationScrim {
    static func suppressSystemDimming(
        for viewController: UIViewController,
        applyCornerRadius: Bool = true
    ) {
        if let sheet = viewController.sheetPresentationController {
            let detent = sheet.selectedDetentIdentifier ?? .large
            if sheet.largestUndimmedDetentIdentifier != detent {
                sheet.largestUndimmedDetentIdentifier = detent
            }
            let heroMotionActive = SheetHeroSession.isHeroMotionActive
            let allowRadius = applyCornerRadius
                && !viewController.isBeingDismissed
                && !heroMotionActive
            if allowRadius {
                let radius = MinCornerRadius.pinnedSheetCornerRadius
                if sheet.preferredCornerRadius != radius {
                    sheet.preferredCornerRadius = radius
                }
            }
        }
        if let container = viewController.presentationController?.containerView {
            hideSystemSheetDimming(in: container)
        }
    }

    static func hideSystemSheetDimming(in view: UIView) {
        let subs = view.subviews
        let hasSheet = subs.contains {
            NSStringFromClass(type(of: $0)).contains("DropShadow")
        }
        if hasSheet {
            for sub in subs {
                let name = NSStringFromClass(type(of: sub))
                if name.contains("Dimming"), !(sub is SheetDismissBackdropView) {
                    sub.alpha = 0
                    sub.isHidden = true
                    sub.isUserInteractionEnabled = false
                }
            }
        }
        for sub in subs {
            hideSystemSheetDimming(in: sub)
        }
    }

    static func presentedViewController(from start: UIView) -> UIViewController? {
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
            if viewController.presentingViewController != nil {
                return viewController
            }
            node = viewController.parent
        }
        return host
    }
}

/// Lives on the presenting side so system dimming can be hidden on the first
/// frame of presentation, before the sheet's dismiss host has attached.
struct SheetScrimGuard: UIViewRepresentable {
    func makeUIView(context: Context) -> SheetScrimGuardView {
        SheetScrimGuardView()
    }

    func updateUIView(_ uiView: SheetScrimGuardView, context: Context) {}
}

final class SheetScrimGuardView: UIView {
    private var presentedObservation: NSKeyValueObservation?
    private var hideLink: CADisplayLink?
    private var hideUntil: CFTimeInterval = 0
    private weak var backdropView: SheetDismissBackdropView?
    private var didAnimateBackdropIn = false
    private var didFadeBackdropOut = false
    private var lifecycleHook: SheetPresentationLifecycleHook?
    private lazy var hideLinkProxy = HideLinkProxy(owner: self)

    private final class HideLinkProxy: NSObject {
        weak var owner: SheetScrimGuardView?
        init(owner: SheetScrimGuardView) { self.owner = owner }
        @objc func tick() { owner?.hideTick() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            presentedObservation?.invalidate()
            presentedObservation = nil
            stopHideLink()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        presentedObservation?.invalidate()
        presentedObservation = nil
        stopHideLink()
        guard window != nil else { return }
        startObserving()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if presentingViewController()?.presentedViewController != nil {
            beginHidingSystemDimming()
        }
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }

    private func presentingViewController() -> UIViewController? {
        var viewController = nearestViewController()
        while let parent = viewController?.parent {
            viewController = parent
        }
        return viewController
    }

    private func startObserving() {
        guard let presenter = presentingViewController() else { return }
        presentedObservation = presenter.observe(\.presentedViewController, options: [.new]) { [weak self] _, change in
            self?.handlePresented(change.newValue ?? nil)
        }
        handlePresented(presenter.presentedViewController)
    }

    private func handlePresented(_ presented: UIViewController?) {
        guard let presented else {
            fadeBackdropOut(with: presentingViewController())
            didAnimateBackdropIn = false
            removeLifecycleHook()
            stopHideLink()
            return
        }
        didFadeBackdropOut = false
        didAnimateBackdropIn = false
        SheetPresentationScrim.suppressSystemDimming(for: presented)
        beginHidingSystemDimming()
        installBackdrop(for: presented)
        installLifecycleHook(on: presented)
    }

    private func fadeBackdropOut(with viewController: UIViewController?) {
        guard !didFadeBackdropOut else { return }
        guard let backdrop = backdropView else { return }
        // Swipe/hero already fading this plate with the card — don't start a
        // second shade animation that pops after the sheet has landed.
        if backdrop.isGestureDrivenFade || backdrop.isVisuallyClear {
            didFadeBackdropOut = true
            return
        }
        didFadeBackdropOut = true
        let animations = {
            backdrop.strength = 0
            backdrop.alpha = 0
        }
        let coordinator = viewController?.transitionCoordinator
            ?? viewController?.presentedViewController?.transitionCoordinator
        if let coordinator, coordinator.isAnimated,
           coordinator.animate(alongsideTransition: { _ in animations() }) {
            return
        }
        UIView.animate(
            withDuration: SheetHeroMotion.openDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: animations
        )
    }

    private func installLifecycleHook(on presented: UIViewController) {
        guard lifecycleHook == nil else { return }
        let hook = SheetPresentationLifecycleHook()
        hook.onWillDisappear = { [weak self, weak presented] _ in
            self?.fadeBackdropOut(with: presented)
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

    private func installBackdrop(for presented: UIViewController) {
        guard let container = presented.presentationController?.containerView else { return }
        let backdrop: SheetDismissBackdropView
        if let existing = container.subviews.compactMap({ $0 as? SheetDismissBackdropView }).first {
            backdrop = existing
        } else {
            let created = SheetDismissBackdropView(frame: container.bounds)
            if let sheet = container.subviews.first(where: {
                NSStringFromClass(type(of: $0)).contains("DropShadow")
            }) {
                container.insertSubview(created, belowSubview: sheet)
            } else {
                container.insertSubview(created, at: 0)
            }
            backdrop = created
        }
        backdropView = backdrop
        if didFadeBackdropOut { return }
        if didAnimateBackdropIn || backdrop.strength > 0.95 { return }
        didAnimateBackdropIn = true
        let animations = { backdrop.strength = 1 }
        backdrop.strength = 0
        if let coordinator = presented.transitionCoordinator, coordinator.isAnimated,
           coordinator.animate(alongsideTransition: { _ in animations() }) {
            return
        }
        if presented.isBeingPresented {
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

    private func beginHidingSystemDimming() {
        hideUntil = CACurrentMediaTime() + SheetHeroMotion.openDuration
        hideTick()
        guard hideLink == nil else { return }
        let link = CADisplayLink(target: hideLinkProxy, selector: #selector(HideLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        hideLink = link
    }

    fileprivate func hideTick() {
        if let window {
            SheetPresentationScrim.hideSystemSheetDimming(in: window)
        }
        if let presented = presentingViewController()?.presentedViewController {
            let heroMotion = SheetHeroSession.isHeroMotionActive
                || backdropView?.isGestureDrivenFade == true
            SheetPresentationScrim.suppressSystemDimming(
                for: presented,
                applyCornerRadius: !presented.isBeingDismissed && !heroMotion
            )
            if !heroMotion {
                installBackdrop(for: presented)
            }
            if presented.isBeingDismissed {
                fadeBackdropOut(with: presented)
            }
        }
        let presented = presentingViewController()?.presentedViewController
        if presented == nil, CACurrentMediaTime() >= hideUntil {
            stopHideLink()
        }
    }

    private func stopHideLink() {
        hideLink?.invalidate()
        hideLink = nil
    }

    deinit {
        presentedObservation?.invalidate()
        hideLink?.invalidate()
        lifecycleHook?.onWillDisappear = nil
    }
}

/// Child of the presented host so dimming can fade with the dismiss animation.
final class SheetPresentationLifecycleHook: UIViewController {
    var onWillDisappear: ((Bool) -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if parent?.isBeingDismissed == true || isBeingDismissed {
            onWillDisappear?(animated)
        }
    }
}
#endif
