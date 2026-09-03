import SwiftUI

/// Circular status-filter control for search chrome.
struct EpisodeStatusFilterButton: View {
    @Binding var statusFilter: EpisodeStatusFilter
    var size: CGFloat = 56

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Menu {
            ForEach(EpisodeStatusFilter.allCases) { filter in
                Button {
                    statusFilter = filter
                } label: {
                    if filter == statusFilter {
                        Label(filter.rawValue, systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Label(filter.rawValue, systemImage: filter.systemImage)
                    }
                }
            }
        } label: {
            Image(systemName: statusFilter == .all ? DesignSystem.Icon.filter : statusFilter.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive
                    ? themeManager.currentTheme.accentColor
                    : DesignSystem.Colors.textPrimary)
                .frame(width: size, height: size)
                .background(.thinMaterial)
                .clipShape(MinAffordanceStyle.shared.circleShape)
                .overlay {
                    if MinAffordanceStyle.shared.borderEnabled {
                        MinAffordanceStyle.shared.circleShape
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Status filter, \(statusFilter.rawValue)" : "Status filter")
    }

    private var isActive: Bool { statusFilter != .all }
}
