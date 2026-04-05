import SwiftUI

/// Add a member or private RSS feed. Most platforms give you a unique URL (often with a token) and/or HTTP auth.
struct AddPrivateFeedView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    enum AuthMode: String, CaseIterable {
        case urlOnly = "Secret link only"
        case bearer = "Bearer token"
        case basic = "Username & password"
    }

    @State private var feedURLString = ""
    @State private var authMode: AuthMode = .urlOnly
    @State private var bearerToken = ""
    @State private var basicUser = ""
    @State private var basicPassword = ""

    @State private var isWorking = false
    @State private var errorMessage: String?

    private let initialURLString: String?
    var onAdded: ((Podcast) -> Void)?

    init(initialURLString: String? = nil, onAdded: ((Podcast) -> Void)? = nil) {
        self.initialURLString = initialURLString
        self.onAdded = onAdded
        _feedURLString = State(initialValue: initialURLString ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Feed URL", text: $feedURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("RSS address")
            } footer: {
                Text("Paste the private RSS link from Patreon, Memberful, Supercast, your podcast host, or email.")
            }

            Section {
                Picker("Authentication", selection: $authMode) {
                    ForEach(AuthMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.inline)

                switch authMode {
                case .urlOnly:
                    EmptyView()
                case .bearer:
                    SecureField("Bearer token", text: $bearerToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .basic:
                    TextField("Username", text: $basicUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $basicPassword)
                }
            } footer: {
                Text("Use Bearer or Basic only if your provider says the feed needs HTTP authentication. Otherwise choose “Secret link only.”")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.bodySmall())
                        .foregroundColor(DesignSystem.Colors.error)
                }
            }

            Section {
                Button {
                    Task { await addFeed() }
                } label: {
                    if isWorking {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Verify & add to library")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isWorking || normalizedURL == nil)
            }
        }
        .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        .navigationTitle("Private RSS")
        .navigationBarTitleDisplayMode(.inline)
        .bottomSheetPullToDismiss()
    }

    private var normalizedURL: URL? {
        let trimmed = feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return PrivateFeedAuthStore.canonicalFeedURL(url)
    }

    private func provisionalAuth() -> FeedHTTPAuth? {
        switch authMode {
        case .urlOnly:
            return nil
        case .bearer:
            let t = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : .bearer(t)
        case .basic:
            let u = basicUser.trimmingCharacters(in: .whitespacesAndNewlines)
            let p = basicPassword
            if u.isEmpty && p.isEmpty { return nil }
            return .basic(username: u, password: p)
        }
    }

    private func addFeed() async {
        errorMessage = nil
        guard let url = normalizedURL else {
            errorMessage = "Enter a valid http or https URL."
            return
        }

        isWorking = true
        defer { isWorking = false }

        let auth = provisionalAuth()

        do {
            guard let podcast = try await RSSFeedService.shared.fetchPodcastMetadata(
                feedURL: url,
                provisionalAuth: auth
            ) else {
                errorMessage = "Could not read a podcast feed from that URL."
                return
            }

            if let auth {
                try await PrivateFeedAuthStore.shared.saveCredential(auth, for: url)
            } else {
                await PrivateFeedAuthStore.shared.removeCredential(for: url)
            }

            await RSSFeedService.shared.invalidateFeedCache(feedURL: url)

            var podcasts = Podcast.loadFollowedPodcasts()
            var toSave = podcast
            toSave.isFollowed = true
            let feedStr = toSave.feedURL.absoluteString
            if let index = podcasts.firstIndex(where: { $0.feedURL.absoluteString == feedStr }) {
                podcasts[index] = toSave
            } else if let index = podcasts.firstIndex(where: { $0.id == toSave.id }) {
                podcasts[index] = toSave
            } else {
                podcasts.append(toSave)
            }
            Podcast.saveFollowedPodcasts(podcasts)

            onAdded?(toSave)
            dismiss()
        } catch RSSFeedError.authenticationRequired {
            errorMessage = "The server rejected this request (login or token required). Check the URL and authentication settings."
        } catch RSSFeedError.httpFailure(let code) {
            errorMessage = "The server returned an error (HTTP \(code))."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
