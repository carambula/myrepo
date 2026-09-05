import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Resolves bundled theme preset font style strings to `Font` instances.
/// Supports `"inherit"`, `"system-default"`, `"system-rounded"`,
/// `"system-monospaced"`, `"system-condensed"`, and `"new-york"`.
public enum ThemeFontResolver {
    public static func font(for style: String, size: CGFloat, headline: Bool, fallback: Font?) -> Font {
        let normalized = style.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "inherit", "":
            return fallback ?? Font.system(size: size, weight: headline ? .bold : .regular, design: .default)
        case "system-default":
            return Font.system(size: size, weight: headline ? .bold : .regular, design: .default)
        case "system-rounded":
            return Font.system(size: size, weight: headline ? .bold : .regular, design: .rounded)
        case "system-monospaced":
            return Font.system(size: size, weight: headline ? .bold : .regular, design: .monospaced)
        case "new-york":
            return newYorkFont(size: size, headline: headline, fallback: fallback)
        case "system-condensed":
            if headline {
                return Font.system(size: size, weight: .bold, design: .default).width(.condensed)
            }
            return Font.system(size: size, weight: .regular, design: .default)
        default:
            return fallback ?? Font.system(size: size, weight: headline ? .bold : .regular, design: .default)
        }
    }

    public static func newYorkFont(size: CGFloat, headline: Bool, fallback: Font?) -> Font {
        #if canImport(UIKit)
        let candidates: [String] = headline
            ? ["NewYork-Bold", "NewYork", "New York"]
            : ["NewYork-Regular", "NewYork", "New York"]

        for name in candidates {
            if let uiFont = UIFont(name: name, size: size) {
                return Font(uiFont)
            }
        }
        #endif

        return fallback ?? Font.system(size: size, weight: headline ? .bold : .regular, design: .serif)
    }
}
