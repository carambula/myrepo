import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        OnboardingPagerView(pageCount: 4, hasCompleted: $hasCompletedOnboarding) { page, advance in
            switch page {
            case 0: welcomePage(advance: advance)
            case 1: featureHighlightPage(advance: advance)
            case 2: podcastPickerPage(advance: advance)
            default: themePickerPage(finish: advance)
            }
        }
        .themeBackground()
    }

    // MARK: - Welcome

    private func welcomePage(advance: @escaping () -> Void) -> some View {
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
                advance()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Feature Highlight

    private func featureHighlightPage(advance: @escaping () -> Void) -> some View {
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
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            Spacer()

            Button {
                advance()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
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

    private func podcastPickerPage(advance: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Follow Some Podcasts")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.top, DesignSystem.Spacing.xl)

            Text("You can always add more later from search.")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            PodcastPickerView()

            Button {
                advance()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Theme Picker

    private func themePickerPage(finish: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Choose Your Look")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.top, DesignSystem.Spacing.xl)

            ThemesView(isOnboarding: true)

            Button {
                finish()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}
