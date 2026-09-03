import SwiftUI
import UIKit
import Speech

/// Inline transcript preview + full `TranscriptView` sheet, shared by episode detail and the player sheet.
struct EpisodeTranscriptDetailSection: View {
    enum PresentationContext {
        case detail
        case player
    }

    let episode: Episode
    let isLoading: Bool
    let fullTranscript: FullTranscript?
    let onSeekFromTranscript: (TimeInterval) -> Void
    let onReloadTranscript: () async -> Void
    var onRequestDownloadForTranscription: (() -> Void)? = nil
    var isDownloadForTranscriptionInProgress = false
    var isDownloadForTranscriptionEnabled = true
    var presentationContext: PresentationContext = .detail

    @Environment(ThemeManager.self) private var themeManager

    // On-device transcription state is owned by the global manager so it survives navigation.
    private let transcriptionManager = BackgroundTranscriptionManager.shared
    private var isTranscribingOnDevice: Bool { transcriptionManager.isRunning(for: episode.id) }
    private var onDeviceProgress: String?   { transcriptionManager.progress(for: episode.id) }
    private var transcriptionError: String? { transcriptionManager.error(for: episode.id) }

    @State private var showFullTranscript = false
    @State private var showTranscriptViewer = false
    @State private var showImporter = false
    @State private var isGeneratingCloud = false
    @State private var actionError: String?
    @State private var analysis: TranscriptAnalysis?

    private var horizontalSectionPadding: CGFloat {
        presentationContext == .player ? 0 : DesignSystem.Spacing.lg
    }

    private var transcriptBodyFont: Font {
        presentationContext == .player
            ? DesignSystem.Typography.bodyMedium()
            : DesignSystem.Typography.bodySmall()
    }

    private var transcriptBodyColor: Color {
        presentationContext == .player
            ? DesignSystem.Colors.textPrimary
            : DesignSystem.Colors.textSecondary
    }

    private var metadataFont: Font {
        presentationContext == .player
            ? DesignSystem.Typography.captionMedium()
            : DesignSystem.Typography.caption()
    }

    private var downloadActionLabel: String {
        isDownloadForTranscriptionInProgress ? "Downloading episode..." : "Download episode to transcribe"
    }

    var body: some View {
        Group {
            if isLoading {
                loadingBlock
            } else if let fullTranscript, !fullTranscript.text.isEmpty {
                transcriptContent(fullTranscript)
            } else {
                emptyState
            }
        }
        .task(id: fullTranscript?.metadata.fetchedAt) {
            guard let fullTranscript else { return }
            analysis = await TranscriptAnalysisService.shared.analyze(fullTranscript, episodeID: episode.id)
        }
        .onChange(of: transcriptionManager.jobs[episode.id]?.status) { _, newStatus in
            if newStatus == .completed {
                Task { await onReloadTranscript() }
            }
        }
    }

    // MARK: - Loading

    private var loadingBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Transcript")
                .font(DesignSystem.Typography.headlineMedium())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            HStack {
                ProgressView()
                Text("Looking for transcript…")
                    .font(transcriptBodyFont)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSectionPadding)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Transcript content

    private func transcriptContent(_ fullTranscript: FullTranscript) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Transcript")
                    .font(DesignSystem.Typography.headlineMedium())
                    .foregroundColor(DesignSystem.Colors.headlineColor)

                Spacer()

                HStack(spacing: DesignSystem.Spacing.xs) {
                    if isTranscribingOnDevice {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ProgressView().scaleEffect(0.75)
                            Text(onDeviceProgress ?? "Transcribing…")
                                .font(metadataFont)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    } else {
                        Button {
                            showTranscriptViewer = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        }

                        Menu {
                            Button {
                                UIPasteboard.general.string = fullTranscript.text
                            } label: {
                                Label("Copy All", systemImage: "doc.on.doc")
                            }
                            Button {
                                showFullTranscript.toggle()
                            } label: {
                                Label(showFullTranscript ? "Show Less" : "Show More",
                                      systemImage: showFullTranscript ? "chevron.up" : "chevron.down")
                            }
                            Button {
                                showTranscriptViewer = true
                            } label: {
                                Label("Open Full View", systemImage: "arrow.up.left.and.arrow.down.right")
                            }
                            if episode.isDownloaded {
                                Divider()
                                Button {
                                    retranscribeOnDevice()
                                } label: {
                                    Label("Retranscribe on device", systemImage: "arrow.clockwise")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: sourceIcon(for: fullTranscript.metadata.source))
                    .font(metadataFont)
                Text(fullTranscript.metadata.source.rawValue)
                Text("   ")
                Text("\(fullTranscript.metadata.wordCount) words")
                if fullTranscript.metadata.hasSpeakerLabels {
                    Text("   ")
                    Label("Speakers", systemImage: "person.2")
                }
            }
            .font(metadataFont)
            .foregroundColor(DesignSystem.Colors.textSecondary)

            if fullTranscript.segments != nil {
                segmentedTranscriptView(fullTranscript: fullTranscript)
            } else {
                plainTranscriptView(fullTranscript: fullTranscript)
            }

            if let analysis, !analysis.keywords.isEmpty || !analysis.insights.isEmpty || !analysis.speakerNames.isEmpty {
                Divider()
                    .padding(.top, DesignSystem.Spacing.xs)
                TranscriptInsightsView(analysis: analysis)
                    .environment(themeManager)
            }

            if let err = actionError ?? transcriptionError {
                Text(err)
                    .font(metadataFont)
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSectionPadding)
        .padding(.vertical, DesignSystem.Spacing.md)
        .sheet(isPresented: $showTranscriptViewer) {
            TranscriptView(fullTranscript: fullTranscript, onSeek: onSeekFromTranscript)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Transcript")
                .font(DesignSystem.Typography.headlineMedium())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                if episode.isDownloaded {
                    Button {
                        runOnDeviceTranscription()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if isTranscribingOnDevice {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "waveform.badge.mic")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                            Text(isTranscribingOnDevice ? (onDeviceProgress ?? "Transcribing…") : "Transcribe now")
                                .font(transcriptBodyFont)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isTranscribingOnDevice)
                } else {
                    if let onRequestDownloadForTranscription {
                        Button {
                            onRequestDownloadForTranscription()
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                if isDownloadForTranscriptionInProgress {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(themeManager.currentTheme.accentColor)
                                }
                                Text(downloadActionLabel)
                                    .font(transcriptBodyFont)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(!isDownloadForTranscriptionEnabled || isDownloadForTranscriptionInProgress)
                    }
                }
            }

            // AssemblyAI (optional, paid)
            if TranscriptionAPIKeyStore.hasAPIKey {
                Button {
                    runCloudTranscription()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if isGeneratingCloud { ProgressView().scaleEffect(0.8) }
                        Label("Generate via AssemblyAI", systemImage: "cloud")
                            .font(transcriptBodyFont)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isGeneratingCloud)
            }

            if let err = actionError ?? transcriptionError {
                Text(err)
                    .font(metadataFont)
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSectionPadding)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Transcript body views

    private func plainTranscriptView(fullTranscript: FullTranscript) -> some View {
        Button {
            withAnimation { showFullTranscript.toggle() }
        } label: {
            Text(fullTranscript.text)
                .font(transcriptBodyFont)
                .foregroundColor(transcriptBodyColor)
                .lineLimit(showFullTranscript ? nil : 20)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
    }

    private func segmentedTranscriptView(fullTranscript: FullTranscript) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let segments = fullTranscript.segments {
                let displaySegments = showFullTranscript ? segments : Array(segments.prefix(10))

                ForEach(Array(displaySegments.enumerated()), id: \.offset) { _, segment in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if let speaker = segment.speaker {
                                Text(speaker)
                                    .font(metadataFont.weight(.semibold))
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                            if let startTime = segment.startTime {
                                Text(formatTranscriptTime(startTime))
                                    .font(metadataFont)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        Text(segment.text)
                            .font(transcriptBodyFont)
                            .foregroundColor(transcriptBodyColor)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                if !showFullTranscript && segments.count > 10 {
                    Button {
                        withAnimation { showFullTranscript = true }
                    } label: {
                        Text("Show \(segments.count - 10) more segments…")
                            .font(transcriptBodyFont)
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sourceIcon(for source: TranscriptMetadata.TranscriptSource) -> String {
        switch source {
        case .rssTag: return "antenna.radiowaves.left.and.right"
        case .showNotesLink: return "link"
        case .youtube: return "play.rectangle"
        case .manual: return "square.and.arrow.down"
        case .onDevice: return "waveform.badge.mic"
        case .generated: return "cloud"
        }
    }

    private func formatTranscriptTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    private func runOnDeviceTranscription() {
        transcriptionManager.clearError(for: episode.id)
        actionError = nil
        transcriptionManager.transcribe(episode: episode)
    }

    private func retranscribeOnDevice() {
        actionError = nil
        analysis = nil
        transcriptionManager.retranscribe(episode: episode)
    }

    private func runCloudTranscription() {
        Task {
            await MainActor.run {
                isGeneratingCloud = true
                actionError = nil
            }
            do {
                _ = try await TranscriptService.shared.requestAssemblyAITranscript(for: episode)
                await onReloadTranscript()
            } catch {
                await MainActor.run {
                    actionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
            await MainActor.run { isGeneratingCloud = false }
        }
    }
}
