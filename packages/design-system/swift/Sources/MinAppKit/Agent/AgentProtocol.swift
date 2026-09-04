import CommonCrypto
import Foundation
import Security

/// Min apps that expose an agent surface.
public enum AgentAppID: String, CaseIterable, Codable, Sendable {
    case mov
    case pod
    case vid
    case cyc
    case spin
    case fit

    public var displayName: String {
        switch self {
        case .mov: return "mov min"
        case .pod: return "pod min"
        case .vid: return "vid min"
        case .cyc: return "cyc min"
        case .spin: return "spin min"
        case .fit: return "fit min"
        }
    }

    public var productName: String {
        switch self {
        case .mov: return "WatchedIt"
        case .pod: return "PodLink"
        case .vid: return "YourTube"
        case .cyc: return "Cyclismo"
        case .spin: return "SpinMin"
        case .fit: return "fit min"
        }
    }

    public var readScope: String { "\(rawValue).read" }
    public var writeScope: String { "\(rawValue).write" }
}

public enum AgentScope {
    public static let undo = "undo"
    public static let audit = "audit"

    public static func all(write: Bool = true) -> [String] {
        var scopes = [undo, audit]
        for app in AgentAppID.allCases {
            scopes.append(app.readScope)
            if write { scopes.append(app.writeScope) }
        }
        return expand(scopes)
    }

    public static func expand(_ scopes: [String]) -> [String] {
        var set = Set(scopes)
        for app in AgentAppID.allCases where set.contains(app.writeScope) {
            set.insert(app.readScope)
        }
        return set.sorted()
    }
}

public struct AgentConnection: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var tokenHash: String
    public var scopes: [String]
    public var createdAt: Date
    public var lastUsedAt: Date?
    public var revokedAt: Date?

    public var isRevoked: Bool { revokedAt != nil }
    public var canWrite: Bool { scopes.contains(where: { $0.hasSuffix(".write") }) }

    public var permissionLabel: String {
        canWrite ? "Read and write" : "Read only"
    }
}

public struct AgentUndoRecord: Codable, Identifiable, Sendable {
    public let id: String
    public let connectionId: String
    public let app: String
    public let tool: String
    public let summary: String
    public let payload: Data
    public let createdAt: Date
    public let expiresAt: Date
    public var undoneAt: Date?

    public var isUsable: Bool {
        undoneAt == nil && expiresAt > Date()
    }
}

public struct AgentAuditEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let at: Date
    public let connectionId: String
    public let connectionName: String
    public let app: String
    public let tool: String
    public let summary: String
    public let ok: Bool
    public let undoId: String?
}

public enum AgentKitError: LocalizedError, Sendable {
    case unauthorized
    case revoked
    case forbidden(scope: String)
    case notFound(String)
    case ambiguous(String)
    case confirmationRequired(String)
    case nothingToUndo
    case undoExpired
    case alreadyUndone

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Missing or invalid agent token."
        case .revoked: return "This agent connection has been revoked."
        case .forbidden(let scope): return "This connection is missing permission: \(scope)."
        case .notFound(let message): return message
        case .ambiguous(let message): return message
        case .confirmationRequired(let message): return message
        case .nothingToUndo: return "There is nothing left to undo."
        case .undoExpired: return "That undo window has expired."
        case .alreadyUndone: return "That change was already undone."
        }
    }
}

public enum AgentSecurity {
    public static let tokenPrefix = "minagt_"
    public static let undoTTL: TimeInterval = 7 * 24 * 60 * 60
    public static let metadataSeparator = "   "

    public static func hashToken(_ token: String) -> String {
        sha256Hex(token)
    }

    public static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let encoded = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return tokenPrefix + encoded
    }

    public static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
