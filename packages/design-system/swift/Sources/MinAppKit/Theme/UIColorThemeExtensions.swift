#if canImport(UIKit)
import UIKit
import SwiftUI

extension UIColor {
    public func lightened(by ratio: CGFloat) -> UIColor {
        mix(with: .white, ratio: ratio)
    }

    public func darkened(by ratio: CGFloat) -> UIColor {
        mix(with: .black, ratio: ratio)
    }

    public func adjustedForContrast(against background: UIColor, minimumRatio: CGFloat) -> UIColor {
        if contrastRatio(with: background) >= minimumRatio {
            return self
        }

        let whiteContrast = UIColor.white.contrastRatio(with: background)
        let blackContrast = UIColor.black.contrastRatio(with: background)
        let target = whiteContrast >= blackContrast ? UIColor.white : UIColor.black

        var best = self
        for step in 1...24 {
            let mixed = mix(with: target, ratio: CGFloat(step) / 24.0)
            best = mixed
            if mixed.contrastRatio(with: background) >= minimumRatio {
                return mixed
            }
        }
        return best
    }

    public func contrastRatio(with other: UIColor) -> CGFloat {
        let lhs = relativeLuminance()
        let rhs = other.relativeLuminance()
        let lighter = max(lhs, rhs)
        let darker = min(lhs, rhs)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public func relativeLuminance() -> CGFloat {
        let rgba = normalizedRGBA()
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgba.red) + 0.7152 * channel(rgba.green) + 0.0722 * channel(rgba.blue)
    }

    public func normalizedRGBA() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }
        return (0, 0, 0, 1)
    }

    public func adjusted(hueDelta: CGFloat, saturationMultiplier: CGFloat, brightnessMultiplier: CGFloat) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        let h = (hue + hueDelta).truncatingRemainder(dividingBy: 1.0)
        let s = min(max(saturation * saturationMultiplier, 0), 1)
        let b = min(max(brightness * brightnessMultiplier, 0), 1)
        return UIColor(hue: h < 0 ? h + 1 : h, saturation: s, brightness: b, alpha: alpha)
    }

    public func mix(with other: UIColor, ratio: CGFloat) -> UIColor {
        let r = min(max(ratio, 0), 1)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 * (1 - r) + r2 * r,
            green: g1 * (1 - r) + g2 * r,
            blue: b1 * (1 - r) + b2 * r,
            alpha: a1 * (1 - r) + a2 * r
        )
    }

    public func asColor() -> SwiftUI.Color {
        SwiftUI.Color(self)
    }

    public var perceivedLuminance: CGFloat {
        relativeLuminance()
    }
}
#endif
