#if os(iOS)
import UIKit

/// Dark dim plate behind a presented bottom sheet (no blur).
/// `strength` (0…1) fades the dim as the sheet is dragged away —
/// matching `swipeBackdropOpacity` / the web BottomSheet backdrop.
final class SheetDismissBackdropView: UIView {
    /// Rest-state black dim. Darker than the system sheet scrim so the
    /// underlying chrome clearly recedes.
    static let restDimAlpha: CGFloat = 0.62

    var strength: CGFloat = 1 {
        didSet {
            let clamped = min(1, max(0, strength))
            alpha = Self.restDimAlpha * clamped
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .black
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = Self.restDimAlpha
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
