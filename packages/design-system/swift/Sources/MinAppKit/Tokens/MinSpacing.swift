import Foundation

/// Spacing tokens for the min apps design system.
/// All spacing values are in points (pt) and match the design system's spacing scale.
public enum MinSpacing {
    /// Extra small spacing: 4pt
    /// Use for tight internal gaps
    public static let xs: CGFloat = 4
    
    /// Small spacing: 8pt
    /// Use for button gaps, small internal padding
    public static let sm: CGFloat = 8
    
    /// Medium spacing: 12pt
    /// Use for inter-component spacing
    public static let md: CGFloat = 12
    
    /// Large spacing: 16pt
    /// Use for toolbar/button/nav edge inset, grid gutters
    public static let lg: CGFloat = 16
    
    /// Extra large spacing: 24pt
    /// Use for screen content margins (screenHorizontalPadding)
    public static let xl: CGFloat = 24
    
    /// Extra extra large spacing: 32pt
    /// Use for section spacing
    public static let xxl: CGFloat = 32
    
    /// Extra extra extra large spacing: 48pt
    /// Use for large section gaps
    public static let xxxl: CGFloat = 48
    
    /// Screen horizontal padding: 24pt
    /// All scroll content, detail views, onboarding panels, list rows, and page-level elements
    /// use screenHorizontalPadding (24pt) from the screen edge.
    public static let screenHorizontalPadding: CGFloat = xl
    
    /// Floating controls inset: 16pt
    /// Floating toolbars, search bars, account buttons, layout-toggle FABs, and top safe-area
    /// controls sit at lg (16pt) — 8pt inside the screen edge from the content margin.
    public static let floatingControlsInset: CGFloat = lg
    
    /// Grid gutter spacing: 16pt
    /// Used for 2-column grid layouts (PodLink & YourTube pattern)
    public static let gridGutter: CGFloat = lg

    /// Extra scroll clearance above the home indicator. Safe-area insets still apply.
    public static let bottomSafeArea: CGFloat = 34

    /// Circular account / search / add / layout-toggle buttons.
    /// These overlay the home surface — do not reserve a top `safeAreaInset` band for them.
    public enum TopControls {
        /// Floating circular glass button hit target. Matches WatchedIt `GlassControl.standardHeight`.
        public static let buttonSize: CGFloat = 56
        /// Gap between top-bar icon buttons.
        public static let horizontalPadding: CGFloat = sm
        /// Padding from the top safe edge to the overlay control row.
        public static let verticalPadding: CGFloat = sm
    }

    /// Scroll-pinned brand wordmark on each min-app home screen.
    public enum TitleType {
        public static let horizontalPadding: CGFloat = screenHorizontalPadding
        public static let markOffsetY: CGFloat = 0
        /// Space above the wordmark inside the scroll view (`logo.marginTop`).
        /// `lg` optically centers the 38pt mark in the 56pt overlay button row
        /// (8pt `TopControls.verticalPadding` + 9pt leftover). Pair with overlay
        /// chrome, not `safeAreaInset(edge: .top)`, or the mark sits too low.
        public static let scrollTopPadding: CGFloat = lg
        /// Space between the wordmark and the first content row.
        public static let contentTopSpacing: CGFloat = xl
        public static let maxWidth: CGFloat = 220
        public static let maxHeight: CGFloat = 38
        public static let blurDistance: CGFloat = 80
        public static let maxBlurRadius: CGFloat = 12
        public static let maxOpacityReduction: CGFloat = 0.5
    }
}
