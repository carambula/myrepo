#if os(iOS)
import UIKit

/// Dark dim plate behind a presented bottom sheet (no blur).
/// `strength` (0…1) fades the dim as the sheet is dragged away —
/// matching `swipeBackdropOpacity` / the web BottomSheet backdrop.
final class SheetDismissBackdropView: UIView {
    /// Rest-state black dim. Darker than the system sheet scrim so the
    /// underlying chrome clearly recedes.
    static let restDimAlpha: CGFloat = MinOpacity.sheetDimRest

    /// True while an edge-swipe / hero fling is fading this plate with the
    /// card. Guard / lifecycle must not start a second fade.
    var isGestureDrivenFade = false

    var strength: CGFloat = 0 {
        didSet {
            let clamped = min(1, max(0, strength))
            alpha = Self.restDimAlpha * clamped
        }
    }

    var isVisuallyClear: Bool {
        alpha < 0.02 || strength < 0.02
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Swallow taps so `largestUndimmedDetentIdentifier` does not let
        // the presenting view receive hits through the fade plate.
        isUserInteractionEnabled = true
        isAccessibilityElement = false
        backgroundColor = .black
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        strength = 0
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
