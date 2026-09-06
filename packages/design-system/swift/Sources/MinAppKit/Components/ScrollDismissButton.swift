import SwiftUI

/// Floating dismiss button that appears when the user scrolls past a threshold.
/// Tapping dismisses the current view. Near-bottom only expands the button.
///
/// Used in all 4 min apps for detail/show views.
///
/// ```swift
/// ScrollView {
///     content
///         .scrollOffset($scrollOffset)
/// }
/// .coordinateSpace(name: "scroll")
/// .overlay(alignment: .bottomLeading) {
///     ScrollDismissButton(scrollOffset: scrollOffset, isNearBottom: isNearBottom)
///         .padding(.leading, MinSpacing.Page.marginLeftMobile)
///         .padding(.bottom, MinSpacing.lg)
/// }
/// ```
public struct ScrollDismissButton: View {
    @Environment(\.dismiss) private var dismiss

    public let scrollOffset: CGFloat
    public let isNearBottom: Bool
    public var material: Material
    public var borderColor: Color
    public var borderWidth: CGFloat

    private let scrollThreshold: CGFloat = 100
    private let compactSize: CGFloat = 56
    private let expandedSize: CGFloat = 64

    private var isVisible: Bool {
        scrollOffset > scrollThreshold
    }

    private var buttonSize: CGFloat {
        isNearBottom ? expandedSize : compactSize
    }

    public init(
        scrollOffset: CGFloat,
        isNearBottom: Bool,
        material: Material = .thinMaterial,
        borderColor: Color = .secondary.opacity(0.4),
        borderWidth: CGFloat = 1
    ) {
        self.scrollOffset = scrollOffset
        self.isNearBottom = isNearBottom
        self.material = material
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }

    public var body: some View {
        let aff = MinAffordanceStyle.shared
        let shape = aff.circleShape
        Button {
            dismiss()
        } label: {
            Image(systemName: MinIcon.close)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
                .background(material)
                .clipShape(shape)
                .overlay { if aff.borderEnabled { shape.stroke(borderColor, lineWidth: borderWidth) } }
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .animation(MinAnimation.standard, value: isVisible)
        .animation(MinAnimation.quick, value: buttonSize)
    }
}
