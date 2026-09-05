import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Codable RGBA color representation for persisting theme colors.
public struct ThemeColorData: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var color: SwiftUI.Color {
        SwiftUI.Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    #if canImport(UIKit)
    public static func from(_ color: SwiftUI.Color) -> ThemeColorData {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return ThemeColorData(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }
    #endif
}
