import SwiftUI

/// PreferenceKey for tracking scroll offset in a ScrollView.
///
/// Usage:
/// ```swift
/// ScrollView {
///     content
///         .scrollOffset($scrollOffset)
/// }
/// .coordinateSpace(name: "scroll")
/// ```
public struct ScrollOffsetPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0

    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Tracks the scroll offset of this view within a named "scroll" coordinate space.
    public func scrollOffset(_ offset: Binding<CGFloat>) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: -geometry.frame(in: .named("scroll")).origin.y
                )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            offset.wrappedValue = max(0, value)
        }
    }
}
