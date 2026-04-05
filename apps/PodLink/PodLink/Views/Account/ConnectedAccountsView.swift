import SwiftUI

struct ConnectedAccountsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    @State private var showAddPrivateFeed = false

    var body: some View {
        List {
            Section {
                Text(
                    "Paid shows almost always use a private RSS URL (sometimes with a token in the link) or HTTP login. " +
                    "PodLink can’t sign into Apple Podcasts or Spotify for you like their own apps—use the private feed link your creator emailed or shows in Patreon, Memberful, Supercast, Glow, etc."
                )
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section("Private RSS") {
                Button {
                    showAddPrivateFeed = true
                } label: {
                    Label("Add private or member feed", systemImage: "link.badge.plus")
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section("Where to find the link") {
                guidanceRow(
                    title: "Patreon, Memberful, Supercast, Glow",
                    detail: "Open your membership benefits → podcast or audio → copy the private RSS URL."
                )
                guidanceRow(
                    title: "Apple Podcasts & Spotify",
                    detail: "Shows you pay for there usually stay in those apps unless the creator gives a separate supporter RSS URL."
                )
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Member podcasts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.checkmark)
                        .viewControlIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
        }
        .sheet(isPresented: $showAddPrivateFeed) {
            NavigationStack {
                AddPrivateFeedView()
                    .environment(themeManager)
                    .environment(playbackService)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showAddPrivateFeed = false
                            } label: {
                                Image(systemName: DesignSystem.Icon.close)
                                    .viewControlIconStyle()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cancel")
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .environment(themeManager)
            .environment(playbackService)
            .bottomSheetPullToDismiss()
            .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        }
    }

    @ViewBuilder
    private func guidanceRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.bodyMedium())
            Text(detail)
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
