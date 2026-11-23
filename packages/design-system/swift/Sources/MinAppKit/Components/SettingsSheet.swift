import SwiftUI

/// Shared settings/notification sheet chrome used by min apps.
///
/// Wraps content in a grouped `List` with an icon-only Done toolbar button.
/// Each app provides its own sections as content.
///
/// ```swift
/// SettingsSheet(title: "Notifications") {
///     Section("Alerts") { Toggle("Enable", isOn: $enabled) }
/// }
/// ```
public struct SettingsSheet<Content: View>: View {
    public let title: String
    @ViewBuilder public let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        List {
            content()
        }
        .listStyle(.insetGrouped)
        .minSheetCornerRadius()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                MinSheetIconButton(.done) { dismiss() }
            }
        }
    }
}
