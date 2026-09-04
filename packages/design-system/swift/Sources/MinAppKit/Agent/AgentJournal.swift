import Foundation

/// Reversible agent writes and an audit trail. Records expire after 7 days.
public final class AgentJournal: @unchecked Sendable {
    public static let shared = AgentJournal()
    public static let didChange = Notification.Name("MinAgentKit.journalDidChange")

    private let defaults: UserDefaults
    private let undoKey = "min.agent.undo.v1"
    private let auditKey = "min.agent.audit.v1"
    private let lock = NSLock()
    private let maxUndo = 200
    private let maxAudit = 500

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func recordWrite(
        connectionId: String,
        app: AgentAppID,
        tool: String,
        summary: String,
        payload: some Codable,
        connectionName: String = "On-device"
    ) -> String {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(payload)) ?? Data()
        let now = Date()
        let record = AgentUndoRecord(
            id: "undo_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))",
            connectionId: connectionId,
            app: app.rawValue,
            tool: tool,
            summary: summary,
            payload: data,
            createdAt: now,
            expiresAt: now.addingTimeInterval(AgentSecurity.undoTTL),
            undoneAt: nil
        )
        lock.lock()
        var undo = loadUndoLocked()
        undo.append(record)
        if undo.count > maxUndo { undo = Array(undo.suffix(maxUndo)) }
        saveUndoLocked(undo)
        appendAuditLocked(AgentAuditEntry(
            id: "aud_\(UUID().uuidString.prefix(8))",
            at: now,
            connectionId: connectionId,
            connectionName: connectionName,
            app: app.rawValue,
            tool: tool,
            summary: summary,
            ok: true,
            undoId: record.id
        ))
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return record.id
    }

    public func recordReadFailure(app: AgentAppID, tool: String, summary: String) {
        lock.lock()
        appendAuditLocked(AgentAuditEntry(
            id: "aud_\(UUID().uuidString.prefix(8))",
            at: Date(),
            connectionId: "local",
            connectionName: "On-device",
            app: app.rawValue,
            tool: tool,
            summary: summary,
            ok: false,
            undoId: nil
        ))
        lock.unlock()
    }

    public func usable(app: AgentAppID? = nil) -> [AgentUndoRecord] {
        lock.lock()
        defer { lock.unlock() }
        return loadUndoLocked().filter { record in
            record.isUsable && (app == nil || record.app == app?.rawValue)
        }
    }

    public func latestUsable(app: AgentAppID? = nil) -> AgentUndoRecord? {
        usable(app: app).last
    }

    public func markUndone(id: String) throws -> AgentUndoRecord {
        lock.lock()
        defer { lock.unlock() }
        var items = loadUndoLocked()
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw AgentKitError.nothingToUndo
        }
        if items[index].undoneAt != nil { throw AgentKitError.alreadyUndone }
        if items[index].expiresAt <= Date() { throw AgentKitError.undoExpired }
        items[index].undoneAt = Date()
        saveUndoLocked(items)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return items[index]
    }

    public func decodePayload<T: Decodable>(_ record: AgentUndoRecord, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: record.payload)
    }

    public func audit(limit: Int = 25, app: AgentAppID? = nil) -> [AgentAuditEntry] {
        lock.lock()
        defer { lock.unlock() }
        var items = loadAuditLocked()
        if let app {
            items = items.filter { $0.app == app.rawValue }
        }
        return Array(items.suffix(limit).reversed())
    }

    private func loadUndoLocked() -> [AgentUndoRecord] {
        guard let data = defaults.data(forKey: undoKey) else { return [] }
        return (try? JSONDecoder().decode([AgentUndoRecord].self, from: data)) ?? []
    }

    private func saveUndoLocked(_ items: [AgentUndoRecord]) {
        defaults.set(try? JSONEncoder().encode(items), forKey: undoKey)
    }

    private func loadAuditLocked() -> [AgentAuditEntry] {
        guard let data = defaults.data(forKey: auditKey) else { return [] }
        return (try? JSONDecoder().decode([AgentAuditEntry].self, from: data)) ?? []
    }

    private func appendAuditLocked(_ entry: AgentAuditEntry) {
        var items = loadAuditLocked()
        items.append(entry)
        if items.count > maxAudit { items = Array(items.suffix(maxAudit)) }
        defaults.set(try? JSONEncoder().encode(items), forKey: auditKey)
    }
}
