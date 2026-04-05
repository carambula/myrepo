import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        OnboardingPagerView(pageCount: 3, hasCompleted: $hasCompletedOnboarding) { page, advance in
            switch page {
            case 0: welcomePage(advance: advance)
            case 1: featureHighlightPage(advance: advance)
            default: themePickerPage(finish: advance)
            }
        }
        .themeBackground()
    }

    // MARK: - Welcome

    private func welcomePage(advance: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 80))
                .foregroundStyle(DesignSystem.Color.accent)

            Text("Cyclismo")
                .displayLarge()
                .foregroundHeadline()

            Text("Your guide to\nprofessional cycling.")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textSecondary)
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

    // MARK: - Feature Highlights

    private func featureHighlightPage(advance: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.xxl) {
                featureRow(
                    icon: "calendar",
                    title: "Race Schedule",
                    description: "View upcoming races with times, routes, and streaming information."
                )

                featureRow(
                    icon: "play.rectangle.fill",
                    title: "Stream Alerts",
                    description: "Know exactly when and where to watch every race."
                )

                featureRow(
                    icon: "waveform",
                    title: "Race Recaps",
                    description: "Find podcasts and replay links after each stage."
                )

                featureRow(
                    icon: "bookmark.fill",
                    title: "Save Races",
                    description: "Mark races you care about for personalized notifications."
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
                .foregroundColor(DesignSystem.Color.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .headlineSmall()
                    .foregroundColor(DesignSystem.Color.textPrimary)
                Text(description)
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
        }
    }

    // MARK: - Theme Picker

    private func themePickerPage(finish: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Choose Your Theme")
                .headlineLarge()
                .foregroundHeadline()
                .padding(.top, DesignSystem.Spacing.xl)

            ThemesView()

            Button {
                finish()
            } label: {
                Text("View Races")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}
