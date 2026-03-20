import SwiftUI

struct MediaLinkCardView: View {
    let link: MediaLink

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let appScheme = link.appSchemeURL, UIApplication.shared.canOpenURL(appScheme) {
                openURL(appScheme)
            } else {
                openURL(link.destinationURL)
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Image or icon
                if let imageURL = link.imageURL {
                    AsyncCachedImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        iconPlaceholder
                    }
                    .frame(width: 120, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                } else {
                    iconPlaceholder
                        .frame(width: 120, height: 80)
                }

                VStack(spacing: 2) {
                    Text(link.title)
                        .font(DesignSystem.Typography.bodySmall())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: link.type.systemImage)
                            .font(.system(size: 9))
                        Text(link.type.displayName)
                            .font(DesignSystem.Typography.caption())
                    }
                    .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .frame(width: 120, alignment: .leading)
            }
            .padding(DesignSystem.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .strokeBorder(
                                themeManager.currentTheme.accentColor.opacity(0.2),
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var iconPlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
            .fill(themeManager.currentTheme.accentColor.opacity(0.15))
            .overlay {
                Image(systemName: link.type.systemImage)
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.currentTheme.accentColor)
            }
    }
}
