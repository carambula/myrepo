import Observation
import SwiftUI

/// Shared corner-radius preference for every min app.
///
/// Appearance sheets bind `mode`. Token reads (`MinCornerRadius.xs`, …) resolve
/// through this object so cards, tiles, and sheets follow the setting while
/// circular controls (navigation, buttons, capsules, `MinCornerRadius.round`)
/// stay round.
@Observable
public final class MinRadiusStyle {
    nonisolated(unsafe) public static let shared = MinRadiusStyle()

    /// Named ramp, smallest to largest. Universal 1/2/3 map to these points;
    /// universal 0 is 0. Reduced modes never go below `ramp[0]`.
    public static let ramp: [CGFloat] = [
        MinCornerRadius.baseXS,
        MinCornerRadius.baseSM,
        MinCornerRadius.baseMD,
        MinCornerRadius.baseLG,
        MinCornerRadius.baseXL
    ]

    /// Radii at or above this are treated as circular / pill and are not remapped.
    public static let circularThreshold: CGFloat = 50

    public enum Mode: String, CaseIterable, Identifiable, Sendable {
        case `default`
        case reduced1
        case reduced2
        case reduced3
        case universal3
        case universal2
        case universal1
        case universal0

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .default: return "Default"
            case .reduced1: return "Reduced 1"
            case .reduced2: return "Reduced 2"
            case .reduced3: return "Reduced 3"
            case .universal3: return "Universal 3"
            case .universal2: return "Universal 2"
            case .universal1: return "Universal 1"
            case .universal0: return "Universal 0"
            }
        }

        public var detail: String {
            switch self {
            case .default:
                return "Current corner radii across the app."
            case .reduced1:
                return "Each corner is one step smaller on the radius ramp, not below the smallest ramp radius."
            case .reduced2:
                return "Each corner is two steps smaller on the radius ramp, not below the smallest ramp radius."
            case .reduced3:
                return "Each corner is three steps smaller on the radius ramp, not below the smallest ramp radius."
            case .universal3:
                return "Every rounded corner uses the third ramp radius (12pt)."
            case .universal2:
                return "Every rounded corner uses the second ramp radius (8pt)."
            case .universal1:
                return "Every rounded corner uses the first ramp radius (4pt)."
            case .universal0:
                return "Every rounded corner is square (0 radius)."
            }
        }

        fileprivate var reducedSteps: Int {
            switch self {
            case .reduced1: return 1
            case .reduced2: return 2
            case .reduced3: return 3
            default: return 0
            }
        }
    }

    public var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }

    public static let sectionFooter =
        "Scales rounded corners on cards, tiles, and sheets. Circular buttons and navigation stay round."

    private static let modeKey = "min.radius.mode"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.modeKey),
           let stored = Mode(rawValue: raw) {
            mode = stored
        } else {
            mode = .default
        }
    }

    /// Maps a default (canonical) radius through the current mode.
    public func resolve(_ base: CGFloat) -> CGFloat {
        Self.resolve(base, mode: mode)
    }

    /// System sheet chrome (38pt) through the current mode.
    /// Reduced 1/2/3 step onto the named ramp from `xl` (20 → 16 → 12).
    public func resolveSheet() -> CGFloat {
        Self.resolveSheet(mode: mode)
    }

    public var presentationSheetRadius: CGFloat? {
        switch mode {
        case .default: return nil
        default: return resolveSheet()
        }
    }

    public var uiKitSheetCornerRadius: CGFloat {
        switch mode {
        case .default: return -1
        default: return resolveSheet()
        }
    }

    public var dismissConfiguredRadius: CGFloat {
        switch mode {
        case .default: return -1
        default: return resolveSheet()
        }
    }

    public nonisolated static func resolveSheet(mode: Mode) -> CGFloat {
        switch mode {
        case .default:
            return MinCornerRadius.baseSheet
        case .reduced1, .reduced2, .reduced3:
            return slide(MinCornerRadius.baseXL, steps: mode.reducedSteps - 1)
        case .universal3:
            return ramp[2]
        case .universal2:
            return ramp[1]
        case .universal1:
            return ramp[0]
        case .universal0:
            return 0
        }
    }

    public nonisolated static func resolve(_ base: CGFloat, mode: Mode) -> CGFloat {
        if base >= circularThreshold { return base }
        if base <= 0 { return 0 }

        switch mode {
        case .default:
            return base
        case .reduced1, .reduced2, .reduced3:
            return slide(base, steps: mode.reducedSteps)
        case .universal3:
            return ramp[2]
        case .universal2:
            return ramp[1]
        case .universal1:
            return ramp[0]
        case .universal0:
            return 0
        }
    }

    /// Slide `base` down `steps` positions on the ramp, clamped at the smallest ramp radius.
    public nonisolated static func slide(_ base: CGFloat, steps: Int) -> CGFloat {
        let ramp = Self.ramp
        guard steps > 0 else { return base }
        guard let index = rampIndex(for: base) else { return base }
        let next = max(0, index - steps)
        if next < ramp.count {
            return ramp[next]
        }
        let last = ramp[ramp.count - 1]
        let stepSize = ramp[1] - ramp[0]
        return last + CGFloat(next - (ramp.count - 1)) * stepSize
    }

    /// Index on the ramp, or `nil` when the value is below the smallest ramp radius
    /// (those stay as-is under reduced modes instead of going to 0).
    nonisolated static func rampIndex(for value: CGFloat) -> Int? {
        let ramp = Self.ramp
        if let exact = ramp.firstIndex(of: value) {
            return exact
        }
        if value < ramp[0] {
            return nil
        }
        if value > ramp[ramp.count - 1] {
            let stepSize = ramp[1] - ramp[0]
            let extra = Int(((value - ramp[ramp.count - 1]) / stepSize).rounded())
            return ramp.count - 1 + max(0, extra)
        }
        return ramp.lastIndex(where: { $0 <= value })
    }
}

public extension View {
    /// Observes the shared radii setting so token-backed corners refresh live.
    func minRadiusStyle() -> some View {
        modifier(MinRadiusEnvironmentModifier())
    }
}

struct MinRadiusEnvironmentModifier: ViewModifier {
    @Bindable var style = MinRadiusStyle.shared

    func body(content: Content) -> some View {
        content
            .environment(style)
            .animation(.easeInOut(duration: 0.2), value: style.mode)
            #if os(iOS)
            .background(
                MinSheetCornerRadiusGuard(mode: style.mode)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            )
            #endif
    }
}

public extension View {
    /// Applies the Radii setting to this presented sheet's chrome.
    func minSheetCornerRadius() -> some View {
        modifier(MinSheetCornerRadiusModifier())
    }
}

struct MinSheetCornerRadiusModifier: ViewModifier {
    @Bindable var style = MinRadiusStyle.shared

    func body(content: Content) -> some View {
        #if os(iOS) || os(macOS)
        // Always pin a numeric radius so a sheet behind another sheet does
        // not morph to the device concentric corners.
        content.presentationCornerRadius(
            style.presentationSheetRadius ?? MinCornerRadius.baseSheet
        )
        #else
        content
        #endif
    }
}

/// Menu picker for appearance sheets.
public struct MinRadiusSettingsPicker: View {
    @Bindable private var radiusStyle = MinRadiusStyle.shared
    private let title: String

    public init(_ title: String = "Radii") {
        self.title = title
    }

    public var body: some View {
        Picker(title, selection: $radiusStyle.mode) {
            ForEach(MinRadiusStyle.Mode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(title)
    }
}
