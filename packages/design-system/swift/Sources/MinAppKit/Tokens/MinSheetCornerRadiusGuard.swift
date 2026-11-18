#if os(iOS)
import SwiftUI
import UIKit

/// Walks presented sheet controllers and applies the Radii setting to
/// `UISheetPresentationController.preferredCornerRadius`.
struct MinSheetCornerRadiusGuard: UIViewRepresentable {
    var mode: MinRadiusStyle.Mode

    func makeUIView(context: Context) -> MinSheetCornerRadiusGuardView {
        MinSheetCornerRadiusGuardView()
    }

    func updateUIView(_ uiView: MinSheetCornerRadiusGuardView, context: Context) {
        uiView.applySheetCornerRadius()
    }
}

final class MinSheetCornerRadiusGuardView: UIView {
    private var presentedObservations: [NSKeyValueObservation] = []
    private var applyLink: CADisplayLink?
    private var applyUntil: CFTimeInterval = 0
    private lazy var applyLinkProxy = ApplyLinkProxy(owner: self)

    private final class ApplyLinkProxy: NSObject {
        weak var owner: MinSheetCornerRadiusGuardView?
        init(owner: MinSheetCornerRadiusGuardView) { self.owner = owner }
        @objc func tick() { owner?.applyTick() }
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
            stopApplyLink()
            clearObservations()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        clearObservations()
        guard window != nil else { return }
        applySheetCornerRadius()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applySheetCornerRadius()
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

    private func rootViewController() -> UIViewController? {
        var viewController = nearestViewController()
        while let parent = viewController?.parent {
            viewController = parent
        }
        return viewController
    }

    private func clearObservations() {
        presentedObservations.forEach { $0.invalidate() }
        presentedObservations.removeAll()
    }

    private func observe(_ viewController: UIViewController) {
        let observation = viewController.observe(\.presentedViewController, options: [.new]) { [weak self] _, _ in
            self?.applySheetCornerRadius()
        }
        presentedObservations.append(observation)
        if let presented = viewController.presentedViewController {
            observe(presented)
        }
    }

    func applySheetCornerRadius() {
        applyNow()
        beginApplying()
        clearObservations()
        if let root = rootViewController() {
            observe(root)
        } else if let windowRoot = window?.rootViewController {
            observe(windowRoot)
        }
    }

    private func applyNow() {
        let radius = MinCornerRadius.uiKitSheetCornerRadius
        if let root = rootViewController() {
            apply(radius, to: root)
        }
        if let window {
            apply(radius, from: window.rootViewController)
        }
    }

    private func beginApplying() {
        applyUntil = CACurrentMediaTime() + 0.6
        applyNow()
        guard applyLink == nil else { return }
        let link = CADisplayLink(target: applyLinkProxy, selector: #selector(ApplyLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        applyLink = link
    }

    fileprivate func applyTick() {
        applyNow()
        if CACurrentMediaTime() >= applyUntil {
            stopApplyLink()
        }
    }

    private func stopApplyLink() {
        applyLink?.invalidate()
        applyLink = nil
    }

    private func apply(_ radius: CGFloat, from viewController: UIViewController?) {
        guard let viewController else { return }
        apply(radius, to: viewController)
    }

    private func apply(_ radius: CGFloat, to viewController: UIViewController) {
        if let presented = viewController.presentedViewController {
            apply(radius, to: presented)
        }
        // Rewriting chrome radius during a morph snaps the platter back to
        // the sheet value and punches holes in the dim plate.
        if viewController.isBeingDismissed { return }
        if SheetHeroSession.shared.isHeroMotionActive { return }
        if let sheet = viewController.sheetPresentationController,
           sheet.preferredCornerRadius != radius {
            sheet.preferredCornerRadius = radius
        }
        for child in viewController.children {
            apply(radius, to: child)
        }
    }

    deinit {
        stopApplyLink()
        clearObservations()
    }
}
#endif
