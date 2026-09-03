//
//  SearchInputBar.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import SwiftUI

struct SearchInputBar: View {
    @Binding var committedText: String
    let placeholder: String
    let iconColor: Color
    let isFocused: FocusState<Bool>.Binding
    let controlHeight: CGFloat

    @State private var draftText: String = ""
    @State private var debounceTask: Task<Void, Never>?

    init(
        committedText: Binding<String>,
        placeholder: String,
        iconColor: Color = DesignSystem.Color.textSecondary,
        isFocused: FocusState<Bool>.Binding,
        controlHeight: CGFloat = 48
    ) {
        self._committedText = committedText
        self.placeholder = placeholder
        self.iconColor = iconColor
        self.isFocused = isFocused
        self.controlHeight = controlHeight
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            DesignSystemIcon(DesignSystem.Icon.search, size: DesignSystem.IconSize.sm, color: iconColor)

            TextField(placeholder, text: $draftText)
                .textFieldStyle(.plain)
                .foregroundColor(DesignSystem.Color.textPrimary)
                .focused(isFocused)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)

            if !draftText.isEmpty {
                Button {
                    debounceTask?.cancel()
                    draftText = ""
                    committedText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignSystem.IconSize.sm))
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .frame(height: controlHeight)
        .background(GlassControl.floatingMaterial)
        .clipShape(MinAffordanceStyle.shared.capsuleShape)
        .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.capsuleShape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }
        .onAppear {
            draftText = committedText
            Task { @MainActor in
                isFocused.wrappedValue = true
            }
        }
        .onChange(of: draftText) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 35_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    committedText = newValue
                }
            }
        }
    }
}
