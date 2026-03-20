import SwiftUI

struct ConnectedAccountsView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var connectedAccounts: [UserSubscription.SubscriptionPlatform: Bool] = [:]

    var body: some View {
        List {
            Section {
                Text("Connect your premium podcast accounts to access paid content directly in PodLink.")
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Section("Premium Platforms") {
                ForEach(UserSubscription.SubscriptionPlatform.allCases, id: \.self) { platform in
                    HStack {
                        Label(platform.displayName, systemImage: platform.systemImage)

                        Spacer()

                        if connectedAccounts[platform] == true {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Text("Connected")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(themeManager.currentTheme.accentColor)

                                Button("Disconnect") {
                                    connectedAccounts[platform] = false
                                }
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.error)
                            }
                        } else {
                            Button("Connect") {
                                connectedAccounts[platform] = true
                            }
                            .foregroundColor(themeManager.currentTheme.accentColor)
                        }
                    }
                }
            }

            Section("Custom RSS") {
                Button {
                    // Add custom authenticated RSS feed
                } label: {
                    Label("Add Authenticated Feed", systemImage: "plus.circle")
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
        }
        .navigationTitle("Connected Accounts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
