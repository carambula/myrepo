import SwiftUI

/// Account / More entry point — Ideas list + compose sheet (no lightbulb on every page).
public struct IdeasSettingsLink: View {
    public let app: AgentAppID

    public init(app: AgentAppID) {
        self.app = app
    }

    public var body: some View {
        NavigationLink {
            IdeasListView(app: app)
        } label: {
            Label("Ideas & bugs", systemImage: "lightbulb")
        }
    }
}

public struct IdeasListView: View {
    public let app: AgentAppID

    @State private var items: [FeedbackClient.Item] = []
    @State private var errorMessage: String?
    @State private var showCompose = false
    @State private var loading = false

    public init(app: AgentAppID) {
        self.app = app
    }

    public var body: some View {
        List {
            Section {
                Text("Send a bug or an idea. You’ll see status here as it moves from received → in review → building → shipped.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    showCompose = true
                } label: {
                    Label("New idea or bug", systemImage: "plus.circle")
                }
            }

            Section(header: Text("Your submissions")) {
                if loading && items.isEmpty {
                    ProgressView()
                } else if items.isEmpty {
                    Text("Nothing yet. Tap New idea or bug to send one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: MinSpacing.xs) {
                            Text(item.title)
                            Text("\(item.kind == "bug" ? "Bug" : "Idea") · \(item.publicStatusLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Ideas & bugs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCompose) {
            FeedbackComposeSheet(app: app) {
                Task { await reload() }
            }
        }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        do {
            items = try await FeedbackClient.list(app: app)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct FeedbackComposeSheet: View {
    public let app: AgentAppID
    public var onSent: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var kind = "idea"
    @State private var title = ""
    @State private var bodyText = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var sent = false

    public init(app: AgentAppID, onSent: (() -> Void)? = nil) {
        self.app = app
        self.onSent = onSent
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Idea").tag("idea")
                        Text("Bug").tag("bug")
                    }
                    .pickerStyle(.segmented)
                    TextField("Title", text: $title)
                    TextField("Details", text: $bodyText, axis: .vertical)
                        .lineLimit(4...8)
                } footer: {
                    Text("We store your report privately. Public GitHub issues are redacted (no name or email).")
                }
                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Bug or idea")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await send() }
                    }
                    .disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if busy { ProgressView() }
            }
            .disabled(busy)
            .alert("Thanks", isPresented: $sent) {
                Button("OK") {
                    onSent?()
                    dismiss()
                }
            } message: {
                Text("We’ll show status under Ideas & bugs.")
            }
        }
    }

    private func send() async {
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await FeedbackClient.submit(
                app: app,
                kind: kind,
                title: title,
                body: bodyText,
                page: "ios/\(app.rawValue)"
            )
            sent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
