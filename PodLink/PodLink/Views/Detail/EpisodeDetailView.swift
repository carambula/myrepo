import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    @State private var mediaLinks: [MediaLink] = []
    @State private var isLoadingLinks = false
    @State private var showFullNotes = false
    @State private var transcript: String?
    @State private var fullTranscript: FullTranscript?
    @State private var isLoadingTranscript = false
    @State private var showFullTranscript = false
    @State private var transcriptSearchText = ""
    @State private var showTranscriptViewer = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 5)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.lg)

                header
                playControls
                mediaLinksSection
                showNotesSection
                chaptersSection
                transcriptSection
            }
            .padding(.bottom, 80)
        }
        .background(themeManager.currentTheme.backgroundTint.opacity(0.3))
        .bottomSheetPullToDismiss()
        .sheet(isPresented: $showTranscriptViewer) {
            if let fullTranscript {
                TranscriptView(fullTranscript: fullTranscript) { timestamp in
                    playbackService.seek(to: timestamp)
                }
            }
        }
        .task {
            await loadMediaLinks()
            await loadTranscript()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            AsyncCachedImage(url: episode.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            Text(episode.title)
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(episode.publishDate, style: .date)
                if episode.duration > 0 {
                    Text("·")
                    Text(episode.formattedDuration)
                }
                if episode.hasVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
            .font(DesignSystem.Typography.bodySmall())
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Play Controls

    private var playControls: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            Button {
                Task { await playbackService.play(episode: episode) }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(themeManager.currentTheme.accentColor)
                    .clipShape(Capsule())
            }

            Button {
                playbackService.addToQueue(episode)
            } label: {
                Image(systemName: "text.append")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle())

            Button {
                // Toggle bookmark
            } label: {
                Image(systemName: episode.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(episode.isBookmarked ? themeManager.currentTheme.accentColor : DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    // MARK: - Media Links

    private var mediaLinksSection: some View {
        Group {
            if !mediaLinks.isEmpty || isLoadingLinks {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Connected Media")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                    if isLoadingLinks {
                        HStack {
                            ProgressView()
                            Text("Analyzing episode...")
                                .font(DesignSystem.Typography.bodySmall())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(mediaLinks) { link in
                                    MediaLinkCardView(link: link)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Show Notes

    private var showNotesSection: some View {
        Group {
            if !episode.description.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Show Notes")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)

                    Button {
                        withAnimation { showFullNotes.toggle() }
                    } label: {
                        Text(episode.description.strippingHTML)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(showFullNotes ? nil : 6)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Chapters

    private var chaptersSection: some View {
        Group {
            if let chapters = episode.chapters, !chapters.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Chapters")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)

                    ForEach(chapters) { chapter in
                        Button {
                            playbackService.seek(to: chapter.startTime)
                        } label: {
                            HStack {
                                Text(formatTime(chapter.startTime))
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                    .frame(width: 50, alignment: .leading)

                                Text(chapter.title)
                                    .font(DesignSystem.Typography.bodyMedium())
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        Group {
            if isLoadingTranscript {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Transcript")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)
                    
                    HStack {
                        ProgressView()
                        Text("Loading transcript...")
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
            } else if let fullTranscript, !fullTranscript.text.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Transcript")
                            .font(DesignSystem.Typography.headlineMedium())
                            .foregroundColor(DesignSystem.Colors.headlineColor)
                        
                        Spacer()
                        
                        HStack(spacing: DesignSystem.Spacing.xs) {
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
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    
                    if let metadata = fullTranscript.metadata {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Label(metadata.source.rawValue, systemImage: "text.bubble")
                            Text("•")
                            Text("\(metadata.wordCount) words")
                            
                            if metadata.hasSpeakerLabels {
                                Text("•")
                                Label("Speakers", systemImage: "person.2")
                            }
                        }
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    if fullTranscript.segments != nil && !showFullTranscript {
                        segmentedTranscriptView
                    } else {
                        plainTranscriptView
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }
    
    private var plainTranscriptView: some View {
        Button {
            withAnimation { showFullTranscript.toggle() }
        } label: {
            Text(fullTranscript?.text ?? "")
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineLimit(showFullTranscript ? nil : 20)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
    }
    
    private var segmentedTranscriptView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let segments = fullTranscript?.segments {
                let displaySegments = showFullTranscript ? segments : Array(segments.prefix(10))
                
                ForEach(Array(displaySegments.enumerated()), id: \.offset) { index, segment in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if let speaker = segment.speaker {
                                Text(speaker)
                                    .font(DesignSystem.Typography.caption().weight(.semibold))
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                            
                            if let startTime = segment.startTime {
                                Text(formatTime(startTime))
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        Text(segment.text)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
                
                if !showFullTranscript && segments.count > 10 {
                    Button {
                        withAnimation { showFullTranscript = true }
                    } label: {
                        Text("Show \(segments.count - 10) more segments...")
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadMediaLinks() async {
        isLoadingLinks = true
        mediaLinks = await MediaLinkingService.shared.extractMediaLinks(from: episode)
        isLoadingLinks = false
    }

    private func loadTranscript() async {
        isLoadingTranscript = true
        fullTranscript = await TranscriptService.shared.getFullTranscript(for: episode)
        transcript = fullTranscript?.text
        isLoadingTranscript = false
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
