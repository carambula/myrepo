import SwiftUI

/// Scroll-pins home chrome (title-type mark, account / me button) and blurs it out
/// on scroll — the shared WatchedIt / PodLink / YourTube / Cyclismo / fit min pattern.
///
/// Place the view **inside** the `ScrollView` as a sibling of scrolling content.
/// This modifier applies `zIndex(-1)` so later content draws above the chrome.
public struct MinScrollPinnedChromeModifier: ViewModifier {
    let coordinateSpaceName: String

    @State private var initialY: CGFloat?

    public init(coordinateSpaceName: String) {
        self.coordinateSpaceName = coordinateSpaceName
    }

    public func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named(coordinateSpaceName)).minY
            } action: { newValue in
                if initialY == nil {
                    initialY = newValue
                }
            }
            .visualEffect { view, proxy in
                let scrollY = proxy.frame(in: .named(coordinateSpaceName)).minY
                let initial = initialY ?? scrollY
                let drift = initial - scrollY
                let progress = min(max(drift / MinSpacing.TitleType.blurDistance, 0), 1.0)
                return view
                    .offset(y: drift)
                    .blur(radius: progress * MinSpacing.TitleType.maxBlurRadius)
                    .opacity(1.0 - progress * MinSpacing.TitleType.maxOpacityReduction)
            }
            .zIndex(-1)
    }
}

extension View {
    /// Pins this view during scroll and blurs/fades it with the title-type chrome curve.
    ///
    /// Use on the brand wordmark and the top-trailing account / me button so both
    /// sit under scrolling content and dissolve together.
    public func minScrollPinnedChrome(coordinateSpace name: String) -> some View {
        modifier(MinScrollPinnedChromeModifier(coordinateSpaceName: name))
    }
}
