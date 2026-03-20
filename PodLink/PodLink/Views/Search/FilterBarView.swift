import SwiftUI

struct FilterBarView: View {
    @Binding var selectedCategory: PodcastCategory?
    @Binding var showNewOnly: Bool
    @Binding var showVideoOnly: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                filterChip("New", isActive: showNewOnly) {
                    showNewOnly.toggle()
                }

                filterChip("Video", isActive: showVideoOnly, icon: "video") {
                    showVideoOnly.toggle()
                }

                Divider()
                    .frame(height: 20)

                ForEach(PodcastCategory.allCases) { category in
                    filterChip(
                        category.rawValue,
                        isActive: selectedCategory == category,
                        icon: category.systemImage
                    ) {
                        if selectedCategory == category {
                            selectedCategory = nil
                        } else {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    private func filterChip(
        _ label: String,
        isActive: Bool,
        icon: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(DesignSystem.Typography.caption())
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                Capsule()
                    .fill(isActive
                        ? themeManager.currentTheme.accentColor.opacity(0.2)
                        : Color(.tertiarySystemFill))
            }
            .overlay {
                if isActive {
                    Capsule()
                        .strokeBorder(themeManager.currentTheme.accentColor.opacity(0.5), lineWidth: 0.75)
                }
            }
            .foregroundColor(isActive
                ? themeManager.currentTheme.accentColor
                : DesignSystem.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
