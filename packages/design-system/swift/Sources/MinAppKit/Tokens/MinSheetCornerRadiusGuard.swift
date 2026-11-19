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
        let radius = MinCornerRadius.pinnedSheetCornerRadius
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
        let nested = presentationDepth(from: window?.rootViewController) > 1
            || presentationDepth(from: rootViewController()) > 1
        // Keep pinning while sheets are stacked so the behind sheet cannot
        // morph to the device concentric corners.
        if !nested, CACurrentMediaTime() >= applyUntil {
            stopApplyLink()
        }
    }

    private func presentationDepth(from viewController: UIViewController?) -> Int {
        var depth = 0
        var current = viewController
        while let presented = current?.presentedViewController {
            depth += 1
            current = presented
        }
        return depth
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
        if viewController.isBeingPresented { return }
        if viewController.isBeingDismissed { return }
        if SheetHeroSession.isHeroMotionActive { return }
        if let sheet = viewController.sheetPresentationController,
           sheet.preferredCornerRadius != radius {
            sheet.preferredCornerRadius = radius
        }
        pinPlatterRadius(radius, on: viewController.view)
        for child in viewController.children {
            apply(radius, to: child)
        }
    }

    /// UIKit restyles the DropShadow platter of a sheet sitting behind another
    /// sheet. Keep that chrome on the same radius as the sheet in front.
    private func pinPlatterRadius(_ radius: CGFloat, on view: UIView) {
        var current: UIView? = view
        var hops = 0
        while let platter = current, hops < 12 {
            let name = NSStringFromClass(type(of: platter))
            if name.contains("DropShadow") || name.contains("Platter") {
                platter.layer.cornerCurve = .continuous
                if abs(platter.layer.cornerRadius - radius) > 0.5 {
                    platter.layer.cornerRadius = radius
                }
                return
            }
            current = platter.superview
            hops += 1
        }
    }

    deinit {
        stopApplyLink()
        clearObservations()
    }
}
#endif
