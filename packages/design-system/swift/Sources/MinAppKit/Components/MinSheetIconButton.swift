import SwiftUI

/// Icon-only toolbar chrome for account, settings, and menu sheets.
///
/// Min apps never show "Done" / "Close" / "Cancel" labels in sheet bars.
/// Use `MinSheetIconButton` for every dismiss, confirm, add, send, or delete
/// control in those toolbars, and keep accessibility labels for VoiceOver.
public struct MinSheetIconButton: View {
    public enum Kind {
        case close
        case done
        case cancel
        case add
        case send
        case delete
        case edit

        public var systemImage: String {
            switch self {
            case .close, .cancel: return MinIcon.close
            case .done: return MinIcon.checkmark
            case .add: return MinIcon.add
            case .send: return MinIcon.send
            case .delete: return MinIcon.delete
            case .edit: return MinIcon.edit
            }
        }

        public var accessibilityLabel: String {
            switch self {
            case .close: return "Close"
            case .done: return "Done"
            case .cancel: return "Cancel"
            case .add: return "Add"
            case .send: return "Send"
            case .delete: return "Delete"
            case .edit: return "Edit"
            }
        }
    }

    private let kind: Kind
    private let accessibilityLabelOverride: String?
    private let action: () -> Void

    public init(
        _ kind: Kind,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        self.accessibilityLabelOverride = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: kind.systemImage)
                .minSheetIconStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelOverride ?? kind.accessibilityLabel)
    }
}

/// Frosted circular icon button — the primary min-app control for in-sheet actions
/// (edit, delete, and other icon-only body buttons). Not for navigation-bar chrome.
public struct MinGlassIconButton: View {
    private let systemImage: String
    private let accessibilityLabel: String
    private let size: CGFloat
    private let action: () -> Void

    public init(
        _ kind: MinSheetIconButton.Kind,
        size: CGFloat = MinSpacing.TopControls.buttonSize,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = kind.systemImage
        self.accessibilityLabel = accessibilityLabel ?? kind.accessibilityLabel
        self.size = size
        self.action = action
    }

    public init(
        systemImage: String,
        accessibilityLabel: String,
        size: CGFloat = MinSpacing.TopControls.buttonSize,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .affordanceFrostedSurface(roundShape: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

extension View {
    /// 28pt semibold toolbar glyph used by every min-app sheet bar.
    public func minSheetIconStyle() -> some View {
        font(.body.weight(.semibold))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}
