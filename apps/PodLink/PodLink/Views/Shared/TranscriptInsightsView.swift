import SwiftUI

// MARK: - Flow layout for keyword cloud

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        layout(subviews: subviews, in: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                          proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, in maxWidth: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: y + lineHeight), origins)
    }
}

// MARK: - Keyword cloud

private struct KeywordCloudView: View {
    let keywords: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(keywords, id: \.self) { keyword in
                Text(keyword)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Insight category row

private struct InsightCategorySection: View {
    let category: TranscriptInsight.InsightCategory
    let items: [TranscriptInsight]

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Label(category.rawValue, systemImage: category.systemImage)
                .font(DesignSystem.Typography.labelMedium().weight(.semibold))
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.bottom, 2)

            ForEach(items.prefix(8)) { item in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let url = item.url {
                        Link(destination: url) {
                            Text(item.text)
                                .lineLimit(1)
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        }
                        .font(DesignSystem.Typography.bodySmall())
                    } else {
                        Text(item.text)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if item.count > 1 {
                        Text("\(item.count)×")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            if items.count > 8 {
                Text("+ \(items.count - 8) more")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Speaker name map

private struct SpeakerNamesView: View {
    let speakerNames: [String: String]

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Label("Identified speakers", systemImage: "person.2")
                .font(DesignSystem.Typography.labelMedium().weight(.semibold))
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.bottom, 2)

            ForEach(speakerNames.sorted(by: { $0.key < $1.key }), id: \.key) { label, name in
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(label)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Image(systemName: "arrow.right")
                        .imageScale(.small)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(name)
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .font(DesignSystem.Typography.bodySmall())
            }
        }
    }
}

// MARK: - Top-level insights view

struct TranscriptInsightsView: View {
    let analysis: TranscriptAnalysis

    @Environment(ThemeManager.self) private var themeManager

    private var presentableCategories: [TranscriptInsight.InsightCategory] {
        TranscriptInsight.InsightCategory.allCases.filter { cat in
            analysis.insights.contains { $0.category == cat }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Label("Insights", systemImage: "sparkles")
                .font(DesignSystem.Typography.headlineMedium())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            if !analysis.speakerNames.isEmpty {
                SpeakerNamesView(speakerNames: analysis.speakerNames)
                    .environment(themeManager)
            }

            if !analysis.keywords.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label("Keywords", systemImage: "tag")
                        .font(DesignSystem.Typography.labelMedium().weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.headlineColor)
                    KeywordCloudView(keywords: analysis.keywords)
                }
            }

            ForEach(presentableCategories, id: \.rawValue) { category in
                let items = analysis.insights.filter { $0.category == category }
                if !items.isEmpty {
                    InsightCategorySection(category: category, items: items)
                        .environment(themeManager)
                }
            }
        }
    }
}
