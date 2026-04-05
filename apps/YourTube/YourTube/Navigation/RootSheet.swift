import Foundation

enum RootSheet: String, Identifiable {
    case account
    case search
    case addChannel

    var id: String { rawValue }
}
