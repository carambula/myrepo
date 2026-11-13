#if os(iOS)
import UIKit

/// Dim + blur plate behind a presented bottom sheet.
/// `strength` (0…1) fades both together as the sheet is dragged away —
/// matching `swipeBackdropOpacity` / the web BottomSheet backdrop.
final class SheetDismissBackdropView: UIView {
    /// Rest-state black dim over the blur (web large detent uses 0.5).
    static let restDimAlpha: CGFloat = 0.5

    private let blurView: UIVisualEffectView
    private let dimView: UIView

    var strength: CGFloat = 1 {
        didSet {
            let clamped = min(1, max(0, strength))
            if abs(clamped - oldValue) < 0.001, abs(alpha - clamped) < 0.001 { return }
            alpha = clamped
        }
    }

    override init(frame: CGRect) {
        // Dark material keeps the scrim consistent over light and dark app chrome.
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        dimView = UIView()
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        dimView.frame = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.backgroundColor = UIColor.black.withAlphaComponent(Self.restDimAlpha)
        addSubview(dimView)

        alpha = 1
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
