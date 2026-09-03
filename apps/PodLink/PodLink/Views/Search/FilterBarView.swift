import SwiftUI

struct FilterBarView: View {
    @Binding var statusFilter: EpisodeStatusFilter
    @Binding var selectedCategory: PodcastCategory?
    @Binding var showNewOnly: Bool
    @Binding var showVideoOnly: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                statusMenuChip

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
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        }
    }

    private var statusMenuChip: some View {
        Menu {
            ForEach(EpisodeStatusFilter.allCases) { filter in
                Button {
                    statusFilter = filter
                } label: {
                    if filter == statusFilter {
                        Label(filter.rawValue, systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Text(filter.rawValue)
                    }
                }
            }
        } label: {
            filterChipLabel(
                statusFilter == .all ? "Status" : statusFilter.rawValue,
                isActive: statusFilter != .all,
                icon: statusFilter == .all ? DesignSystem.Icon.filter : statusFilter.systemImage
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(statusFilter == .all ? "Status filter" : "Status filter, \(statusFilter.rawValue)")
    }

    private func filterChip(
        _ label: String,
        isActive: Bool,
        icon: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            filterChipLabel(label, isActive: isActive, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func filterChipLabel(
        _ label: String,
        isActive: Bool,
        icon: String? = nil
    ) -> some View {
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
}
