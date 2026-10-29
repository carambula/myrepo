import SwiftUI

// MARK: - Phase 1: Per-podcast ad settings overview

/// Lists every podcast with customized ad settings — mode changes, trims,
/// or learned ad patterns. Shows only shows where the user has made choices,
/// not the full library.
struct AdSettingsOverviewView: View {
    @State private var rows: [AdSettingsRow] = []
    @State private var selectedRow: AdSettingsRow?

    var body: some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "No custom ad settings",
                    systemImage: "speaker.slash",
                    description: Text("Per-podcast ad choices — skip mode, intro/outro trims, learned breaks — will appear here once you customize them.")
                )
            } else {
                List(rows) { row in
                    Button {
                        selectedRow = row
                    } label: {
                        AdSettingsRowView(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Ad Settings by Podcast")
        .navigationDestination(item: $selectedRow) { row in
            PerPodcastAdEditorView(row: row)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        let profiledIDs = Set(ShowAdProfileStore.shared.allProfiledPodcastIDs())
        let followed = Podcast.loadFollowedPodcasts()
        var result: [AdSettingsRow] = []
        var seen = Set<String>()

        for podcast in followed {
            for key in [podcast.id, podcast.feedURL.absoluteString] where profiledIDs.contains(key) {
                guard seen.insert(key).inserted else { continue }
                if let row = makeRow(podcastID: key, name: podcast.title) {
                    result.append(row)
                }
            }
        }

        // Profiles without a matching followed podcast (unfollowed since).
        for key in profiledIDs where !seen.contains(key) {
            if let row = makeRow(podcastID: key, name: key) {
                result.append(row)
            }
        }

        rows = result.sorted { $0.podcastName < $1.podcastName }
    }

    private func makeRow(podcastID key: String, name: String) -> AdSettingsRow? {
        let profile = ShowAdProfileStore.shared.profile(for: key)
        let isCustomized = profile.mode != .smartSkip
            || profile.introTrimSeconds > 0
            || profile.outroTrimSeconds > 0
        let learned = AdPatternLearner.learnedSegments(for: key)
        guard isCustomized || !learned.isEmpty else { return nil }
        return AdSettingsRow(
            podcastID: key,
            podcastName: name,
            profile: profile,
            learnedSegments: learned
        )
    }
}

// MARK: - Row model

struct AdSettingsRow: Identifiable, Hashable {
    let podcastID: String
    let podcastName: String
    let profile: ShowAdProfile
    let learnedSegments: [AdSegment]

    var id: String { podcastID }

    /// Human-readable summary of the choices made for this show.
    var summary: String {
        var parts: [String] = [profile.mode.displayName]
        if profile.introTrimSeconds > 0 {
            parts.append("intro \(Int(profile.introTrimSeconds))s")
        }
        if profile.outroTrimSeconds > 0 {
            parts.append("outro \(Int(profile.outroTrimSeconds))s")
        }
        if !learnedSegments.isEmpty {
            parts.append("\(learnedSegments.count) learned break\(learnedSegments.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    static func == (lhs: AdSettingsRow, rhs: AdSettingsRow) -> Bool {
        lhs.podcastID == rhs.podcastID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(podcastID)
    }
}

// MARK: - Row view

private struct AdSettingsRowView: View {
    let row: AdSettingsRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.podcastName)
                .font(.headline)
                .lineLimit(1)
            Text(row.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Per-podcast editor

/// Edit a show's ad settings: mode, trims, and learned breaks.
private struct PerPodcastAdEditorView: View {
    let row: AdSettingsRow
    @State private var mode: AdSkipMode
    @State private var introTrim: Double
    @State private var outroTrim: Double

    init(row: AdSettingsRow) {
        self.row = row
        _mode = State(initialValue: row.profile.mode)
        _introTrim = State(initialValue: row.profile.introTrimSeconds)
        _outroTrim = State(initialValue: row.profile.outroTrimSeconds)
    }

    var body: some View {
        Form {
            Section("Skip mode") {
                Picker("Mode", selection: $mode) {
                    ForEach(AdSkipMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Text(modeExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Trims") {
                Stepper("Skip first \(Int(introTrim))s", value: $introTrim, in: 0...600, step: 15)
                Stepper("Skip last \(Int(outroTrim))s", value: $outroTrim, in: 0...600, step: 15)
            }

            if !row.learnedSegments.isEmpty {
                Section("Learned breaks") {
                    ForEach(row.learnedSegments) { segment in
                        HStack {
                            Text(segment.kind.displayName)
                            Spacer()
                            Text("\(Int(segment.startTime))s – \(Int(segment.endTime))s")
                                .foregroundStyle(.secondary)
                            Text("\(Int(segment.confidence * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    Text("Learned from your skip behavior. Clear by resetting the show's settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(row.podcastName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: mode) { save() }
        .onChange(of: introTrim) { save() }
        .onChange(of: outroTrim) { save() }
    }

    private var modeExplanation: String {
        switch mode {
        case .off: return "No ad skipping for this show."
        case .smartSkip: return "The +30s button jumps whole ad breaks."
        case .auto: return "High-confidence breaks skip automatically. Tap the toast to replay."
        }
    }

    private func save() {
        var profile = ShowAdProfile()
        profile.mode = mode
        profile.introTrimSeconds = introTrim
        profile.outroTrimSeconds = outroTrim
        ShowAdProfileStore.shared.save(profile, for: row.podcastID)
    }
}

// MARK: - Display names

private extension AdSegmentKind {
    var displayName: String {
        switch self {
        case .preRoll: return "Pre-roll"
        case .midRoll: return "Mid-roll"
        case .postRoll: return "Post-roll"
        }
    }
}
