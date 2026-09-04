import Foundation

/// Persists hashed agent tokens and scopes. Raw tokens are shown once and never stored.
public final class AgentConnectionStore: @unchecked Sendable {
    public static let shared = AgentConnectionStore()

    public static let didChange = Notification.Name("MinAgentKit.connectionsDidChange")

    private let defaults: UserDefaults
    private let key = "min.agent.connections.v1"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func all() -> [AgentConnection] {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    public func active() -> [AgentConnection] {
        all().filter { !$0.isRevoked }
    }

    public func create(name: String, app: AgentAppID, write: Bool) -> (connection: AgentConnection, token: String) {
        let token = AgentSecurity.generateToken()
        var scopes = [AgentScope.undo, AgentScope.audit, app.readScope]
        if write { scopes.append(app.writeScope) }
        let connection = AgentConnection(
            id: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Agent" : name,
            tokenHash: AgentSecurity.hashToken(token),
            scopes: AgentScope.expand(scopes),
            createdAt: Date(),
            lastUsedAt: nil,
            revokedAt: nil
        )
        lock.lock()
        var items = loadLocked()
        items.append(connection)
        saveLocked(items)
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return (connection, token)
    }

    public func revoke(id: String) {
        lock.lock()
        var items = loadLocked()
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].revokedAt = Date()
            saveLocked(items)
        }
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    public func validate(token: String) throws -> AgentConnection {
        let hash = AgentSecurity.hashToken(token)
        guard var connection = all().first(where: { $0.tokenHash == hash }) else {
            throw AgentKitError.unauthorized
        }
        if connection.isRevoked { throw AgentKitError.revoked }
        connection.lastUsedAt = Date()
        lock.lock()
        var items = loadLocked()
        if let index = items.firstIndex(where: { $0.id == connection.id }) {
            items[index].lastUsedAt = connection.lastUsedAt
            saveLocked(items)
        }
        lock.unlock()
        return connection
    }

    public func require(_ connection: AgentConnection, scope: String) throws {
        if !connection.scopes.contains(scope) {
            throw AgentKitError.forbidden(scope: scope)
        }
    }

    public func mcpConfig(token: String) -> String {
        let config: [String: Any] = [
            "mcpServers": [
                "min-apps": [
                    "command": "node",
                    "args": ["packages/agent-kit/src/cli.js", "mcp"],
                    "env": ["MIN_AGENT_TOKEN": token]
                ]
            ]
        ]
        let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private func loadLocked() -> [AgentConnection] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AgentConnection].self, from: data)) ?? []
    }

    private func saveLocked(_ items: [AgentConnection]) {
        defaults.set(try? JSONEncoder().encode(items), forKey: key)
    }
}
