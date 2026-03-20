import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @Environment(ThemeManager.self) private var themeManager
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            featureHighlightPage.tag(1)
            podcastPickerPage.tag(2)
            themePickerPage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(themeManager.currentTheme.backgroundTint.opacity(0.3))
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.currentTheme.accentColor)

            Text("PodLink")
                .font(DesignSystem.Typography.displayLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            Text("Your podcasts.\nConnected to everything.")
                .font(DesignSystem.Typography.headlineMedium())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .background(themeManager.currentTheme.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - Feature Highlight

    private var featureHighlightPage: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.xxl) {
                featureRow(
                    icon: "link",
                    title: "Connected Media",
                    description: "Automatically discovers movies, shows, apps, and music mentioned in episodes."
                )

                featureRow(
                    icon: "play.rectangle.fill",
                    title: "Video & Audio",
                    description: "Stream video podcasts with Picture in Picture. Background playback for everything."
                )

                featureRow(
                    icon: "brain",
                    title: "Smart Analysis",
                    description: "On-device AI analyzes transcripts to find every media reference."
                )

                featureRow(
                    icon: "paintbrush",
                    title: "Fully Themed",
                    description: "Customize every visual element. Create your own themes."
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Continue")
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .background(themeManager.currentTheme.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(themeManager.currentTheme.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(description)
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Podcast Picker

    private var podcastPickerPage: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Follow Some Podcasts")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.top, DesignSystem.Spacing.xxl)

            Text("You can always add more later from search.")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            PodcastPickerView()

            Button {
                withAnimation { currentPage = 3 }
            } label: {
                Text("Continue")
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .background(themeManager.currentTheme.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - Theme Picker

    private var themePickerPage: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Choose Your Look")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.top, DesignSystem.Spacing.xxl)

            ThemesView(isOnboarding: true)

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Done")
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .background(themeManager.currentTheme.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }
}
