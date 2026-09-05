import SwiftUI

/// Font style preset for custom themes.
public enum ThemeFontStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case rounded
    case serif
    case monospaced
    case condensed

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:     return "System"
        case .rounded:    return "Rounded"
        case .serif:      return "Serif"
        case .monospaced: return "Monospaced"
        case .condensed:  return "Condensed"
        }
    }

    public func headlineFont(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .system:     return .system(size: size, weight: weight, design: .default)
        case .rounded:    return .system(size: size, weight: weight, design: .rounded)
        case .serif:      return .system(size: size, weight: weight, design: .serif)
        case .monospaced: return .system(size: size, weight: weight, design: .monospaced)
        case .condensed:  return .system(size: size, weight: weight, design: .default).width(.condensed)
        }
    }

    public func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:     return .system(size: size, weight: weight, design: .default)
        case .rounded:    return .system(size: size, weight: weight, design: .rounded)
        case .serif:      return .system(size: size, weight: weight, design: .serif)
        case .monospaced: return .system(size: size, weight: weight, design: .monospaced)
        case .condensed:  return .system(size: size, weight: weight, design: .default).width(.condensed)
        }
    }
}
