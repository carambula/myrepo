import SwiftUI

/// Shared theme protocol used by WatchedIt and Cyclismo.
///
/// Defines the 12 core visual properties that all themes must provide.
/// Apps can extend this protocol with additional properties
/// (e.g., Cyclismo adds duotone colors).
public protocol MinTheme {
    var name: String { get }
    var accent: SwiftUI.Color { get }
    var secondaryAccent: SwiftUI.Color? { get }
    var headlineFont: Font { get }
    var bodyFont: Font { get }
    var backgroundTint: SwiftUI.Color? { get }
    var darkModeBackground: SwiftUI.Color? { get }
    var lightModeBackground: SwiftUI.Color? { get }
    var supportsLightMode: Bool { get }
    var darkModeHeadlineColor: SwiftUI.Color? { get }
    var lightModeHeadlineColor: SwiftUI.Color? { get }
    var headlineColor: SwiftUI.Color { get }
}

#if canImport(UIKit)
import UIKit

extension MinTheme {
    public var darkModeBackgroundTint: SwiftUI.Color? {
        guard let darkModeBackground else { return nil }
        return UIColor(darkModeBackground).lightened(by: 0.03).asColor()
    }

    public var lightModeBackgroundTint: SwiftUI.Color? {
        guard let lightModeBackground else { return nil }
        return UIColor(lightModeBackground).darkened(by: 0.03).asColor()
    }

    public var darkModeBodyTextColor: SwiftUI.Color? {
        guard let darkModeBackground else { return nil }
        let background = UIColor(darkModeBackground)
        let sourceTint = UIColor(darkModeBackgroundTint ?? backgroundTint ?? accent)
        let candidate = sourceTint.mix(with: .white, ratio: 0.88)
        return candidate.adjustedForContrast(against: background, minimumRatio: 4.5).asColor()
    }

    public var lightModeBodyTextColor: SwiftUI.Color? {
        guard let lightModeBackground else { return nil }
        let background = UIColor(lightModeBackground)
        let sourceTint = UIColor(lightModeBackgroundTint ?? backgroundTint ?? accent)
        let candidate = sourceTint.mix(with: .black, ratio: 0.88)
        return candidate.adjustedForContrast(against: background, minimumRatio: 4.5).asColor()
    }

    public var darkModeListRuleColor: SwiftUI.Color? {
        guard let darkModeBackground else { return nil }
        let background = UIColor(darkModeBackground)
        let sourceTint = UIColor(darkModeBackgroundTint ?? backgroundTint ?? accent)
        let candidate = background.mix(with: sourceTint, ratio: 0.36).lightened(by: 0.14)
        return candidate.adjustedForContrast(against: background, minimumRatio: 1.4).asColor()
    }

    public var lightModeListRuleColor: SwiftUI.Color? {
        guard let lightModeBackground else { return nil }
        let background = UIColor(lightModeBackground)
        let sourceTint = UIColor(lightModeBackgroundTint ?? backgroundTint ?? accent)
        let candidate = background.mix(with: sourceTint, ratio: 0.36).darkened(by: 0.14)
        return candidate.adjustedForContrast(against: background, minimumRatio: 1.4).asColor()
    }
}
#endif
