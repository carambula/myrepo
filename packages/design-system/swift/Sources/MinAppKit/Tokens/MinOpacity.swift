import Foundation

/// Opacity tokens for the min apps design system.
public enum MinOpacity {
    /// Disabled state opacity: 0.5
    public static let disabled: Double = 0.5
    
    /// Pressed state opacity: 0.7
    public static let pressed: Double = 0.7
    
    /// Hover state opacity: 0.9
    public static let hover: Double = 0.9
    
    /// Overlay opacity: 0.3
    public static let overlay: Double = 0.3
    
    /// Light overlay opacity: 0.1
    public static let overlayLight: Double = 0.1

    /// Small-detent sheet scrim (dim only, no blur).
    public static let sheetDimSmall: Double = 0.28

    /// Medium-detent sheet scrim (dim only, no blur).
    public static let sheetDimMedium: Double = 0.45

    /// Large-detent / rest sheet scrim behind pull-to-dismiss sheets.
    /// Shared by `SheetDismissBackdropView` across all min apps.
    public static let sheetDimRest: Double = 0.62
}
