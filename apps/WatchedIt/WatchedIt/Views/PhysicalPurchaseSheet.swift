//
//  PhysicalPurchaseSheet.swift
//  WatchedIt
//

import SwiftUI

struct PhysicalPurchaseSheet: View {
    let movieTitle: String
    let year: Int?
    let media: PhysicalMedia

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var groups: [PhysicalPurchaseEditionGroup] {
        PhysicalPurchaseLinkBuilder.groups(for: media, title: movieTitle, year: year)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                    header
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text(group.headline)
                                .labelMedium()
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Color.textSecondary)

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(group.offers) { offer in
                                    Button {
                                        openURL(offer.url)
                                    } label: {
                                        offerRow(offer)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Search \(offer.title) for \(movieTitle)")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.Color.background.ignoresSafeArea())
            .navigationTitle("Buy disc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(movieTitle)
                .titleLarge()
                .foregroundHeadline()
            let meta = metadataLine
            if !meta.isEmpty {
                Text(meta)
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
        }
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let year {
            parts.append(String(year))
        }
        parts.append(contentsOf: media.badgeLabels)
        return parts.joined(separator: "   ")
    }

    private func offerRow(_ offer: PhysicalPurchaseOffer) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(offer.title)
                .bodyMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            Spacer(minLength: DesignSystem.Spacing.sm)
            Text("Search")
                .captionMedium()
                .foregroundColor(DesignSystem.Color.textSecondary)
            Image(systemName: DesignSystem.Icon.forward)
                .font(.system(size: DesignSystem.IconSize.sm))
                .foregroundColor(DesignSystem.Color.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.backgroundSecondary)
        )
    }
}
