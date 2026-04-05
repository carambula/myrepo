import SwiftUI

struct MediaLinkCardView: View {
    let link: MediaLink

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openURL) private var openURL

    @State private var resolvedImageURL: URL?

    private static let columnWidth: CGFloat = 120
    private static let imageHeight: CGFloat = 72

    private var imageURL: URL? {
        link.imageURL ?? resolvedImageURL
    }

    private var domainLine: String {
        let d = link.displayDomain
        if !d.isEmpty { return d }
        return link.destinationURL.host ?? ""
    }

    var body: some View {
        Button {
            if let appScheme = link.appSchemeURL, UIApplication.shared.canOpenURL(appScheme) {
                openURL(appScheme)
            } else {
                openURL(link.destinationURL)
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                previewImage

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(DesignSystem.Typography.labelMedium())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: Self.columnWidth, alignment: .leading)

                    if !domainLine.isEmpty {
                        Text(domainLine)
                            .font(DesignSystem.Typography.captionSmall())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: Self.columnWidth, alignment: .leading)
                    }
                }
            }
            .frame(width: Self.columnWidth, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .task(id: link.id) {
            guard link.imageURL == nil else { return }
            let url = await LinkPreviewImageResolver.shared.imageURL(for: link.destinationURL)
            await MainActor.run {
                resolvedImageURL = url
            }
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        Group {
            if let imageURL {
                AsyncCachedImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    iconPlaceholder
                }
            } else {
                iconPlaceholder
            }
        }
        .frame(width: Self.columnWidth, height: Self.imageHeight, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }

    private var iconPlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
            .fill(themeManager.currentTheme.accentColor.opacity(0.15))
            .overlay {
                Image(systemName: link.type.systemImage)
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.currentTheme.accentColor)
            }
    }
}
