import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var searchPlacement: NavigationSearchPlacement
    @Bindable var themeManager: ThemeManager
    @Bindable var authService: GoogleOAuthService
    var onConnectGoogle: () async throws -> Void

    @State private var isSigningIn = false
    @State private var signInError: String?

    var body: some View {
        OnboardingPagerView(pageCount: 4, hasCompleted: $hasCompletedOnboarding) { page, advance in
            switch page {
            case 0: welcomePage(advance: advance)
            case 1: googleConnectPage(advance: advance)
            case 2: setupPage(advance: advance)
            default: finishPage(finish: advance)
            }
        }
        .themeBackground(using: themeManager.currentTheme)
        .alert("Sign-in error", isPresented: .constant(signInError != nil), actions: {
            Button("OK", role: .cancel) { signInError = nil }
        }, message: {
            Text(signInError ?? "")
        })
    }

    private func welcomePage(advance: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "play.tv.fill")
                .font(.system(size: 82))
                .foregroundStyle(themeManager.currentTheme.accent)

            Text("Welcome to YourTube")
                .font(DesignSystem.Typography.displayMedium)
                .foregroundStyle(themeManager.currentTheme.text)
                .multilineTextAlignment(.center)

            Text("Track your subscriptions, catch new uploads, and stay focused on the channels you care about.")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            Spacer()

            Button("Get Started") {
                advance()
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func googleConnectPage(advance: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: authService.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(themeManager.currentTheme.accent)

            Text("Connect Google")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(themeManager.currentTheme.text)

            Text("Sign in with Google to load your YouTube subscriptions automatically and keep your feed up to date.")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            if authService.isSignedIn {
                Label("Google account connected", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, DesignSystem.Spacing.xs)
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.sm) {
                if !authService.isSignedIn {
                    Button(isSigningIn ? "Connecting..." : "Connect Google Account") {
                        Task { await connectGoogle() }
                    }
                    .disabled(isSigningIn)
                    .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                }

                Button(authService.isSignedIn ? "Continue" : "Continue for now") {
                    advance()
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .large))
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func setupPage(advance: @escaping () -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Quick Setup")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundStyle(themeManager.currentTheme.text)
                    .padding(.top, DesignSystem.Spacing.xl)

                Text("Choose where search appears and pick your default theme.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(themeManager.currentTheme.secondaryText)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Search placement")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themeManager.currentTheme.text)
                    Picker("Search placement", selection: $searchPlacement) {
                        Text("Top leading").tag(NavigationSearchPlacement.topLeading)
                        Text("Bottom trailing").tag(NavigationSearchPlacement.bottomTrailing)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(themeManager.currentTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Theme")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themeManager.currentTheme.text)

                    ForEach(themeManager.availableThemes) { theme in
                        Button {
                            themeManager.select(themeID: theme.id)
                        } label: {
                            HStack {
                                Text(theme.name)
                                    .foregroundStyle(themeManager.currentTheme.text)
                                Spacer()
                                if theme.id == themeManager.selectedThemeID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(themeManager.currentTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(themeManager.currentTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))

                Button("Continue") {
                    advance()
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        }
    }

    private func finishPage(finish: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 66))
                .foregroundStyle(themeManager.currentTheme.accent)

            Text("You're Ready")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(themeManager.currentTheme.text)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                educationRow(icon: "play.rectangle", text: "Open any video to see details and play instantly.")
                educationRow(icon: "magnifyingglass", text: "Use search to discover channels and videos.")
                educationRow(icon: "person.crop.circle", text: "Use Account anytime to connect or switch settings.")
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            Spacer()

            Button("Start Using YourTube") {
                finish()
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func connectGoogle() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            try await onConnectGoogle()
        } catch {
            signInError = error.localizedDescription
        }
    }

    private func educationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(themeManager.currentTheme.accent)
                .frame(width: 20)
            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(themeManager.currentTheme.secondaryText)
        }
    }
}
