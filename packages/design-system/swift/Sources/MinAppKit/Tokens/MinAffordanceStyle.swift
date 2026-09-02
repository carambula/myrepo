import SwiftUI

/// Affordance styling tokens for buttons and interactive elements.
/// Provides a shared style configuration for all min apps.
public struct MinAffordanceStyle {
    public static let shared = MinAffordanceStyle()
    
    private init() {}
    
    /// Whether borders are enabled on buttons (default: false)
    public var borderEnabled: Bool {
        false
    }
    
    /// Border color for buttons when enabled
    public static var borderColor: Color {
        .clear
    }
    
    /// Border line width for buttons
    public static let borderLineWidth: CGFloat = 1
    
    /// The shape used for buttons (capsule by default)
    public var capsuleShape: Capsule {
        Capsule()
    }
}
