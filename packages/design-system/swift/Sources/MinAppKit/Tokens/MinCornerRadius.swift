import Foundation

/// Corner radius tokens for the min apps design system.
public enum MinCornerRadius {
    /// Art tile corner radius: 8pt
    /// Used for artwork tiles in grids
    public static let artTile: CGFloat = 8
    
    /// Extra small corner radius: 4pt
    public static let xs: CGFloat = 4
    
    /// Small corner radius: 8pt
    public static let sm: CGFloat = 8
    
    /// Medium corner radius: 12pt
    public static let md: CGFloat = 12
    
    /// Large corner radius: 16pt
    public static let lg: CGFloat = 16
    
    /// Extra large corner radius: 20pt
    public static let xl: CGFloat = 20
    
    /// Round corner radius: 100pt
    /// Creates fully rounded corners (circle/pill shape)
    public static let round: CGFloat = 100
}
