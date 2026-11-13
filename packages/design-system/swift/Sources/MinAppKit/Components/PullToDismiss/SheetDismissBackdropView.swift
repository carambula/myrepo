#if os(iOS)
import UIKit

/// Dim + blur plate behind a presented bottom sheet.
///
/// `strength` (0…1) fades blur and dim together as the sheet is dragged away —
/// matching `swipeBackdropOpacity` / the web BottomSheet backdrop.
///
/// Important: do **not** fade this view via `self.alpha`. Animating the alpha of
/// a superview that hosts `UIVisualEffectView` collapses the live blur into a
/// flat translucent fill on many iOS versions.
final class SheetDismissBackdropView: UIView {
    /// Rest-state black dim over the blur (kept light enough that blur reads).
    static let restDimAlpha: CGFloat = 0.32

    private let blurView: UIVisualEffectView
    private let dimView: UIView
    private let restEffect: UIVisualEffect

    var strength: CGFloat = 1 {
        didSet { applyStrength() }
    }

    override init(frame: CGRect) {
        // Ultra-thin keeps the underlying chrome recognizable while still frosted.
        restEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        blurView = UIVisualEffectView(effect: restEffect)
        dimView = UIView()
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        dimView.frame = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.backgroundColor = UIColor.black.withAlphaComponent(1)
        blurView.contentView.addSubview(dimView)

        applyStrength()
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyStrength() {
        let clamped = min(1, max(0, strength))
        // Fade dim directly; cross-fade the blur effect so it stays a real blur
        // at rest and clears as the sheet leaves.
        dimView.alpha = Self.restDimAlpha * clamped
        if clamped <= 0.001 {
            blurView.effect = nil
        } else if blurView.effect == nil {
            blurView.effect = restEffect
        }
        blurView.alpha = clamped
    }
}
#endif
