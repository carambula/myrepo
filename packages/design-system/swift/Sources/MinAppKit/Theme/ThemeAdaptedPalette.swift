import SwiftUI

/// Auto-generated color palette used by the theme builder UI.
public struct ThemeAdaptedPalette {
    public var accent: SwiftUI.Color
    public var secondaryAccent: SwiftUI.Color
    public var darkModeHeadlineColor: SwiftUI.Color
    public var lightModeHeadlineColor: SwiftUI.Color
    public var darkModeBackgroundTint: SwiftUI.Color
    public var lightModeBackgroundTint: SwiftUI.Color
    public var darkModeBackground: SwiftUI.Color
    public var lightModeBackground: SwiftUI.Color

    public init(
        accent: SwiftUI.Color,
        secondaryAccent: SwiftUI.Color,
        darkModeHeadlineColor: SwiftUI.Color,
        lightModeHeadlineColor: SwiftUI.Color,
        darkModeBackgroundTint: SwiftUI.Color,
        lightModeBackgroundTint: SwiftUI.Color,
        darkModeBackground: SwiftUI.Color,
        lightModeBackground: SwiftUI.Color
    ) {
        self.accent = accent
        self.secondaryAccent = secondaryAccent
        self.darkModeHeadlineColor = darkModeHeadlineColor
        self.lightModeHeadlineColor = lightModeHeadlineColor
        self.darkModeBackgroundTint = darkModeBackgroundTint
        self.lightModeBackgroundTint = lightModeBackgroundTint
        self.darkModeBackground = darkModeBackground
        self.lightModeBackground = lightModeBackground
    }
}

#if canImport(UIKit)
import UIKit

extension ThemeAdaptedPalette {
    /// Derives a full color palette from a single highlight color.
    public static func from(highlight: SwiftUI.Color) -> ThemeAdaptedPalette {
        let base = UIColor(highlight)
        let darkHeadline = base.adjusted(hueDelta: 0, saturationMultiplier: 1.05, brightnessMultiplier: 0.68).asColor()
        let lightHeadline = base.adjusted(hueDelta: 0, saturationMultiplier: 1.0, brightnessMultiplier: 0.54).asColor()
        let darkModeBackground = base.mix(with: .black, ratio: 0.82).asColor()
        let lightModeBackground = base.mix(with: .white, ratio: 0.9).asColor()
        return ThemeAdaptedPalette(
            accent: highlight,
            secondaryAccent: base.adjusted(hueDelta: 0.03, saturationMultiplier: 0.78, brightnessMultiplier: 0.82).asColor(),
            darkModeHeadlineColor: darkHeadline,
            lightModeHeadlineColor: lightHeadline,
            darkModeBackgroundTint: UIColor(darkModeBackground).lightened(by: 0.03).asColor(),
            lightModeBackgroundTint: UIColor(lightModeBackground).darkened(by: 0.03).asColor(),
            darkModeBackground: darkModeBackground,
            lightModeBackground: lightModeBackground
        )
    }
}
#endif
