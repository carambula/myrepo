import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

@MainActor
public protocol AgentLibraryExporting: AnyObject {
    func exportLibraryJSON() throws -> Data
    func undoLastAgentWrite() throws -> String
}

/// Account-sheet entry point for connecting an agent with read or write access.
public struct AgentSettingsLink: View {
    public let app: AgentAppID
    public var exporter: AgentLibraryExporting?

    public init(app: AgentAppID, exporter: AgentLibraryExporting? = nil) {
        self.app = app
        self.exporter = exporter
    }

    public var body: some View {
        NavigationLink {
            AgentSettingsView(app: app, exporter: exporter)
        } label: {
            Label("Connected agents", systemImage: "cpu")
        }
    }
}

public struct AgentSettingsView: View {
    public let app: AgentAppID
    public var exporter: AgentLibraryExporting?

    @State private var connections: [AgentConnection] = []
    @State private var issuedToken: String?
    @State private var issuedName = "My agent"
    @State private var allowWrite = true
    @State private var errorMessage: String?
    @State private var copied = false
    @State private var exportMessage: String?
    @State private var undoMessage: String?

    public init(app: AgentAppID, exporter: AgentLibraryExporting? = nil) {
        self.app = app
        self.exporter = exporter
    }

    public var body: some View {
        List {
            // Use Section(header:footer:) { } — never Section("Title") { } footer:.
            // The titled + footer overload is missing on some MinAppKit platforms
            // (watchOS / older macOS SDKs) and the string is parsed as `content:`.
            Section {
                Text("Connect Cursor, Claude, or another agent with a scoped token. Write actions stay undoable for 7 days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(
                header: Text("New connection"),
                footer: Text(allowWrite
                     ? "Read and write. Every write creates an undo record."
                     : "Read only. The agent can look up your library but cannot change it.")
            ) {
                TextField("Agent name", text: $issuedName)
                Toggle("Allow writes", isOn: $allowWrite)
                Button("Create connection") {
                    createConnection()
                }
            }

            if let issuedToken {
                Section(
                    header: Text("Copy this token now"),
                    footer: Text("The token is stored as a hash and cannot be shown again. Revoke it any time.")
                ) {
                    Text(issuedToken)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button(copied ? "Copied" : "Copy token and MCP config") {
                        copyIssued(issuedToken)
                    }
                }
            }

            Section(header: Text("Connections")) {
                if connections.isEmpty {
                    Text("No agents connected yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(connections) { connection in
                    VStack(alignment: .leading, spacing: MinSpacing.xs) {
                        Text(connection.name)
                        Text("\(connection.permissionLabel)\(AgentSecurity.metadataSeparator)\(connection.isRevoked ? "Revoked" : "Active")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        if !connection.isRevoked {
                            Button("Revoke", role: .destructive) {
                                AgentConnectionStore.shared.revoke(id: connection.id)
                                reload()
                            }
                        }
                    }
                }
            }

            Section(header: Text("Safety"), footer: Text(safetyFooter)) {
                Button("Undo last agent write") {
                    undoLast()
                }
                if exporter != nil {
                    Button("Copy library JSON") {
                        copyLibrary()
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
        .navigationTitle("Agents")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: AgentConnectionStore.didChange)) { _ in
            reload()
        }
    }

    private var safetyFooter: String {
        let parts = [undoMessage, exportMessage].compactMap { $0 }
        if parts.isEmpty {
            return "Undo reverses the most recent agent write in \(app.displayName). Library JSON can be imported with min-agent import-library."
        }
        return parts.joined(separator: AgentSecurity.metadataSeparator)
    }

    private func reload() {
        connections = AgentConnectionStore.shared.all().reversed()
    }

    private func createConnection() {
        let issued = AgentConnectionStore.shared.create(
            name: issuedName,
            app: app,
            write: allowWrite
        )
        issuedToken = issued.token
        copied = false
        errorMessage = nil
        reload()
    }

    private func copyIssued(_ token: String) {
        copyToPasteboard(AgentConnectionStore.shared.mcpConfig(token: token).prepending("Token:\n\(token)\n\nMCP config:\n"))
        copied = true
    }

    private func copyLibrary() {
        guard let exporter else { return }
        do {
            let data = try exporter.exportLibraryJSON()
            guard let text = String(data: data, encoding: .utf8) else {
                throw AgentKitError.notFound("Could not encode library JSON.")
            }
            copyToPasteboard(text)
            exportMessage = "Library JSON copied."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func undoLast() {
        guard let exporter else {
            undoMessage = "This app has not registered an undo handler yet."
            return
        }
        do {
            undoMessage = try exporter.undoLastAgentWrite()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

private extension String {
    func prepending(_ prefix: String) -> String {
        prefix + self
    }
}
