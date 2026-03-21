import SwiftUI

struct TranscriptView: View {
    let fullTranscript: FullTranscript
    let onSeek: ((TimeInterval) -> Void)?
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingMetadata = false
    
    init(fullTranscript: FullTranscript, onSeek: ((TimeInterval) -> Void)? = nil) {
        self.fullTranscript = fullTranscript
        self.onSeek = onSeek
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let segments = fullTranscript.segments, !segments.isEmpty {
                    segmentedTranscriptList(segments: segments)
                } else {
                    plainTranscriptView
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = fullTranscript.text
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            showingMetadata.toggle()
                        } label: {
                            Label("Info", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search transcript")
            .sheet(isPresented: $showingMetadata) {
                metadataSheet
            }
        }
    }
    
    private func segmentedTranscriptList(segments: [TranscriptSegment]) -> some View {
        List {
            ForEach(filteredSegments(segments), id: \.text) { segment in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if let speaker = segment.speaker {
                            Text(speaker)
                                .font(DesignSystem.Typography.caption().weight(.semibold))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        }
                        
                        if let startTime = segment.startTime {
                            Button {
                                onSeek?(startTime)
                                dismiss()
                            } label: {
                                Text(formatTime(startTime))
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    
                    Text(highlightedText(segment.text))
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .textSelection(.enabled)
                }
                .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.sm, 
                                         leading: DesignSystem.Spacing.lg, 
                                         bottom: DesignSystem.Spacing.sm, 
                                         trailing: DesignSystem.Spacing.lg))
            }
        }
        .listStyle(.plain)
    }
    
    private var plainTranscriptView: some View {
        ScrollView {
            Text(highlightedText(fullTranscript.text))
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .textSelection(.enabled)
                .padding(DesignSystem.Spacing.lg)
        }
    }
    
    private var metadataSheet: some View {
        NavigationStack {
            List {
                Section("Source") {
                    LabeledContent("Type", value: fullTranscript.metadata.source.rawValue)
                    LabeledContent("Format", value: fullTranscript.metadata.format.rawValue)
                    LabeledContent("Fetched", value: fullTranscript.metadata.fetchedAt.formatted())
                }
                
                Section("Content") {
                    LabeledContent("Word Count", value: "\(fullTranscript.metadata.wordCount)")
                    LabeledContent("Speaker Labels", value: fullTranscript.metadata.hasSpeakerLabels ? "Yes" : "No")
                    LabeledContent("Timestamps", value: fullTranscript.metadata.hasTimestamps ? "Yes" : "No")
                    
                    if let segments = fullTranscript.segments {
                        LabeledContent("Segments", value: "\(segments.count)")
                    }
                }
            }
            .navigationTitle("Transcript Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingMetadata = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func filteredSegments(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        if searchText.isEmpty {
            return segments
        }
        
        return segments.filter { segment in
            segment.text.localizedCaseInsensitiveContains(searchText) ||
            segment.speaker?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if !searchText.isEmpty {
            let lowercasedText = text.lowercased()
            let lowercasedSearch = searchText.lowercased()
            var searchStartIndex = lowercasedText.startIndex
            
            while let range = lowercasedText.range(of: lowercasedSearch, range: searchStartIndex..<lowercasedText.endIndex) {
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                    attributedString[attributedRange].foregroundColor = .primary
                }
                searchStartIndex = range.upperBound
            }
        }
        
        return attributedString
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
