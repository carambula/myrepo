import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SubscriptionOPMLView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var isImporting = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false

    var body: some View {
        List {
            Section {
                Text(
                    "OPML is the usual format for moving podcast subscriptions between apps. " +
                    "Only feed links are transferred—not playback progress, downloads, or folders. " +
                    "Import only adds new shows; nothing is removed or replaced. " +
                    "New follows are saved to iCloud so your library stays in sync across devices."
                )
                .font(DesignSystem.Typography.bodySmall())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Button {
                    exportOPML()
                } label: {
                    Label("Export subscriptions", systemImage: "square.and.arrow.up")
                        .foregroundStyle(themeManager.currentTheme.accentColor)
                }

                Button {
                    showImporter = true
                } label: {
                    Label("Import from OPML…", systemImage: "square.and.arrow.down")
                        .foregroundStyle(themeManager.currentTheme.accentColor)
                }
                .disabled(isImporting)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("OPML")
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
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: opmlImporterTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importOPML(from: url) }
            case .failure(let error):
                importAlertTitle = "Could not read file"
                importAlertMessage = error.localizedDescription
                showImportAlert = true
            }
        }
        .sheet(isPresented: $showShare, onDismiss: cleanupShareFile) {
            if let shareURL {
                ActivityViewController(items: [shareURL])
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView("Importing…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .alert(importAlertTitle, isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }

    private var opmlImporterTypes: [UTType] {
        var types: [UTType] = [.xml]
        if let opml = UTType(filenameExtension: "opml") {
            types.append(opml)
        }
        return types
    }

    private func exportOPML() {
        let podcasts = Podcast.loadFollowedPodcasts()
        guard let data = OPMLSubscriptionService.opmlData(for: podcasts) else { return }
        let name = "podcasts.opml"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            shareURL = url
            showShare = true
        } catch {
            importAlertTitle = "Export failed"
            importAlertMessage = error.localizedDescription
            showImportAlert = true
        }
    }

    private func cleanupShareFile() {
        if let shareURL {
            try? FileManager.default.removeItem(at: shareURL)
        }
        shareURL = nil
    }

    private func importOPML(from url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            await MainActor.run {
                importAlertTitle = "Could not read file"
                importAlertMessage = error.localizedDescription
                showImportAlert = true
            }
            return
        }

        let urls = OPMLSubscriptionService.feedURLs(from: data)
        await MainActor.run {
            isImporting = true
        }

        if urls.isEmpty {
            await MainActor.run {
                isImporting = false
                importAlertTitle = "No feeds found"
                importAlertMessage = "This file doesn’t contain any podcast RSS links (xmlUrl attributes)."
                showImportAlert = true
            }
            return
        }

        let (libraryBeforeDisplayCount, mergedBaselineCount, mergedLibrary) = await MainActor.run {
            let displayed = Podcast.loadFollowedPodcasts()
            let merged = Podcast.mergedFollowedPodcastsForMutation()
            return (displayed.count, merged.count, merged)
        }
        var library = mergedLibrary
        var existing = Set(library.map { PrivateFeedAuthStore.canonicalFeedURL($0.feedURL).absoluteString })
        var added = 0
        var failed = 0
        var skipped = 0

        for feedURL in urls {
            let canon = PrivateFeedAuthStore.canonicalFeedURL(feedURL).absoluteString
            if existing.contains(canon) {
                skipped += 1
                continue
            }
            do {
                if let podcast = try await RSSFeedService.shared.fetchPodcastMetadata(feedURL: feedURL) {
                    library.append(podcast)
                    existing.insert(canon)
                    added += 1
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }

        await MainActor.run {
            let hadLatentCloudSubscriptions = mergedBaselineCount > libraryBeforeDisplayCount
            let shouldPersist = added > 0 || hadLatentCloudSubscriptions
            if shouldPersist {
                Podcast.saveFollowedPodcasts(library)
            }
            isImporting = false
            importAlertTitle = "Import finished"
            var parts: [String] = []
            if hadLatentCloudSubscriptions, added == 0 {
                let n = mergedBaselineCount - libraryBeforeDisplayCount
                parts.append("Merged \(n) show\(n == 1 ? "" : "s") from iCloud into this device.")
            }
            if added > 0 {
                parts.append("Added \(added) podcast\(added == 1 ? "" : "s").")
            }
            if skipped > 0 {
                parts.append("Skipped \(skipped) already in your library.")
            }
            if failed > 0 {
                parts.append("Couldn’t load \(failed) feed\(failed == 1 ? "" : "s") (invalid URL, network, or auth).")
            }
            if parts.isEmpty {
                parts.append("No changes were made.")
            }
            importAlertMessage = parts.joined(separator: " ")
            showImportAlert = true
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
