import Foundation

extension URL {
    /// Extracts a query parameter value by name from this URL.
    public func queryValue(for name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == name.lowercased() })?
            .value
    }
}
