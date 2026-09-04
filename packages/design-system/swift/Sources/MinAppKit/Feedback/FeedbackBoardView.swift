import SwiftUI

/// Account-sheet entry point for the shared Ideas & Bugs board.
public struct FeedbackSettingsLink: View {
    public let app: FeedbackAppID

    public init(app: FeedbackAppID) {
        self.app = app
    }

    public init(app: AgentAppID) {
        self.app = FeedbackAppID(app)
    }

    public var body: some View {
        NavigationLink {
            FeedbackBoardView(app: app)
        } label: {
            Label("Ideas & Bugs", systemImage: "lightbulb")
        }
    }
}

public struct FeedbackBoardView: View {
    public let app: FeedbackAppID

    @State private var kind: FeedbackKind = .idea
    @State private var items: [FeedbackItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showsComposer = false

    public init(app: FeedbackAppID) {
        self.app = app
    }

    public init(app: AgentAppID) {
        self.app = FeedbackAppID(app)
    }

    public var body: some View {
        List {
            Section {
                Text("Vote on existing notes or add one. Ideas and bugs stay public so other \(app.displayName) people can pile on.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Kind", selection: $kind) {
                    ForEach(FeedbackKind.allCases, id: \.self) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: MinSpacing.sm, leading: 0, bottom: MinSpacing.sm, trailing: 0))
            }

            Section(header: Text(kind.title)) {
                if isLoading && items.isEmpty {
                    ProgressView()
                } else if items.isEmpty {
                    Text(emptyCopy)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: MinSpacing.md) {
                            Button {
                                Task { await toggleVote(item) }
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: item.voted ? "arrow.up.circle.fill" : "arrow.up.circle")
                                    Text("\(item.voteCount)")
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                }
                                .foregroundStyle(item.voted ? Color.accentColor : .secondary)
                                .frame(minWidth: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.voted ? "Remove vote" : "Vote")

                            NavigationLink {
                                FeedbackDetailView(app: app, item: item) { updated in
                                    upsert(updated)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: MinSpacing.xs) {
                                    Text(item.title)
                                    Text(item.metadataLine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, MinSpacing.xs)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Ideas & Bugs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsComposer = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add \(kind.singular.lowercased())")
            }
        }
        .refreshable {
            await load()
        }
        .task(id: kind) {
            await load()
        }
        .sheet(isPresented: $showsComposer) {
            NavigationStack {
                FeedbackComposeView(app: app, kind: kind) { created in
                    upsert(created)
                    kind = created.kind
                }
            }
        }
    }

    private var emptyCopy: String {
        switch kind {
        case .idea:
            return "No ideas yet. Add the first one."
        case .bug:
            return "No bugs reported yet."
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await FeedbackClient.shared.list(app: app, kind: kind)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleVote(_ item: FeedbackItem) async {
        do {
            let updated = try await FeedbackClient.shared.toggleVote(id: item.id)
            upsert(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(_ item: FeedbackItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            if item.kind == kind {
                items[index] = item
                items.sort { lhs, rhs in
                    if lhs.voteCount == rhs.voteCount {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return lhs.voteCount > rhs.voteCount
                }
            } else {
                items.remove(at: index)
            }
        } else if item.kind == kind {
            items.insert(item, at: 0)
            items.sort { lhs, rhs in
                if lhs.voteCount == rhs.voteCount {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.voteCount > rhs.voteCount
            }
        }
    }
}

public struct FeedbackDetailView: View {
    public let app: FeedbackAppID
    @State private var item: FeedbackItem
    var onChange: (FeedbackItem) -> Void

    @State private var isWorking = false
    @State private var errorMessage: String?

    public init(app: FeedbackAppID, item: FeedbackItem, onChange: @escaping (FeedbackItem) -> Void) {
        self.app = app
        _item = State(initialValue: item)
        self.onChange = onChange
    }

    public var body: some View {
        List {
            Section {
                Text(item.title)
                    .font(.headline)
                Text(item.metadataLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let body = item.body, !body.isEmpty {
                Section(header: Text("Details")) {
                    Text(body)
                }
            }

            Section {
                Button {
                    Task { await toggleVote() }
                } label: {
                    Label(
                        item.voted ? "Remove vote" : "Vote for this",
                        systemImage: item.voted ? "arrow.up.circle.fill" : "arrow.up.circle"
                    )
                }
                .disabled(isWorking)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(item.kind.singular)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        do {
            let latest = try await FeedbackClient.shared.item(id: item.id)
            item = latest
            onChange(latest)
        } catch {
            // Keep the list payload if the detail fetch fails.
        }
    }

    private func toggleVote() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await FeedbackClient.shared.toggleVote(id: item.id)
            item = updated
            onChange(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct FeedbackComposeView: View {
    public let app: FeedbackAppID
    @State private var kind: FeedbackKind
    var onCreated: (FeedbackItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    public init(app: FeedbackAppID, kind: FeedbackKind, onCreated: @escaping (FeedbackItem) -> Void) {
        self.app = app
        _kind = State(initialValue: kind)
        self.onCreated = onCreated
    }

    public var body: some View {
        List {
            Section {
                Picker("Kind", selection: $kind) {
                    ForEach(FeedbackKind.allCases, id: \.self) { value in
                        Text(value.singular).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                TextField(kind == .idea ? "What should we add?" : "What went wrong?", text: $title)
                TextField("More detail (optional)", text: $bodyText, axis: .vertical)
                    .lineLimit(4...10)
            } footer: {
                Text("No account needed. If you are signed into Min Cloud, your handle is attached.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(kind == .idea ? "New idea" : "New bug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    Task { await submit() }
                }
                .disabled(isWorking || title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
            }
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let created = try await FeedbackClient.shared.submit(
                app: app,
                kind: kind,
                title: title,
                body: bodyText
            )
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
