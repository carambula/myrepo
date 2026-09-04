import MinAppKit
import SwiftData
import SwiftUI

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Bindable private var affordanceStyle = MinAffordanceStyle.shared

    @AppStorage(TimerSoundSettingsKey.enabled) private var timerSoundsEnabled = true
    @AppStorage(TimerSoundSettingsKey.volume) private var timerSoundVolumeRawValue = TimerSoundVolume.standard.rawValue
    @AppStorage(TimerSoundSettingsKey.tone) private var timerSoundToneRawValue = TimerSoundTone.balanced.rawValue
    @AppStorage(TimerSoundSettingsKey.celebrationSound) private var celebrationSoundRawValue = TimerCelebrationSound.threeBeeps.rawValue
    @AppStorage("fitMin.clockDisplayMode") private var clockDisplayModeRawValue = ClockDisplayMode.repsOnly.rawValue
    @AppStorage("fitMin.timingDisplayMode") private var timingDisplayModeRawValue = TimingDisplayMode.inclusive.rawValue
    @AppStorage("fitMin.celebrationAnimation") private var celebrationAnimationRawValue = TimerCelebrationAnimation.clockWave.rawValue
    @AppStorage("fitMin.detailEditButtonPlacement") private var detailEditButtonPlacementRawValue = TimerDetailEditButtonPlacement.bottomRight.rawValue
    @AppStorage("fitMin.detailControlsPlacement") private var detailControlsPlacementRawValue = TimerDetailControlsPlacement.belowMetadata.rawValue
    @AppStorage("fitMin.bouncesFinalIntervalTicks") private var bouncesFinalIntervalTicks = false
    @AppStorage("fitMin.readySetGoEnabled") private var readySetGoEnabled = false
    @State private var showsThemes = false
    @State private var showsFonts = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Button {
                        showsThemes = true
                    } label: {
                        HStack {
                            Label("Themes", systemImage: DesignSystem.Icon.themes)
                            Spacer()
                            Text(themeManager.currentTheme.name)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Toggle("Affordance border", isOn: $affordanceStyle.borderEnabled)

                    Picker("Affordance shape", selection: $affordanceStyle.shape) {
                        ForEach(MinAffordanceStyle.Shape.allCases, id: \.self) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        showsFonts = true
                    } label: {
                        Label("Fonts", systemImage: DesignSystem.Icon.fonts)
                    }

                    Picker("Clock Display", selection: $clockDisplayModeRawValue) {
                        ForEach(ClockDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Timing", selection: $timingDisplayModeRawValue) {
                        ForEach(TimingDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Celebration Animation", selection: $celebrationAnimationRawValue) {
                        ForEach(TimerCelebrationAnimation.allCases) { animation in
                            Text(animation.title).tag(animation.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Edit Button", selection: $detailEditButtonPlacementRawValue) {
                        ForEach(TimerDetailEditButtonPlacement.allCases) { placement in
                            Text(placement.title).tag(placement.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Timer Controls", selection: $detailControlsPlacementRawValue) {
                        ForEach(TimerDetailControlsPlacement.allCases) { placement in
                            Text(placement.title).tag(placement.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Bounce final interval ticks", isOn: $bouncesFinalIntervalTicks)
                }
                .designSystemGroupedListRow()

                Section("Timer") {
                    Toggle("Ready set go", isOn: $readySetGoEnabled)

                    Toggle(isOn: $timerSoundsEnabled) {
                        Label("Tick and boop sounds", systemImage: DesignSystem.Icon.sound)
                    }

                    Picker("Sound volume", selection: $timerSoundVolumeRawValue) {
                        ForEach(TimerSoundVolume.allCases) { volume in
                            Text(volume.title).tag(volume.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!timerSoundsEnabled)

                    Picker("Sound tone", selection: $timerSoundToneRawValue) {
                        ForEach(TimerSoundTone.allCases) { tone in
                            Text(tone.title).tag(tone.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!timerSoundsEnabled)

                    Picker("Celebration sound", selection: $celebrationSoundRawValue) {
                        ForEach(TimerCelebrationSound.allCases) { sound in
                            Text(sound.title).tag(sound.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!timerSoundsEnabled)

                    Button {
                        TimerSoundService.shared.play(.tick)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 130_000_000)
                            TimerSoundService.shared.play(.boop)
                        }
                    } label: {
                        Label("Preview sound", systemImage: "speaker.wave.2.circle")
                    }
                    .disabled(!timerSoundsEnabled)

                    Button {
                        TimerSoundService.shared.playCompletion()
                    } label: {
                        Label("Preview celebration", systemImage: "party.popper")
                    }
                    .disabled(!timerSoundsEnabled)
                }
                .designSystemGroupedListRow()

                Section("iCloud") {
                    Label("Timers sync with iCloud when available.", systemImage: "icloud")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .designSystemGroupedListRow()

                Section("Feedback") {
                    FeedbackSettingsLink(app: .fit)
                }
                .designSystemGroupedListRow()

                Section("Agents") {
                    AgentSettingsLink(app: .fit, exporter: TimerAgentExportAdapter(context: modelContext))
                }
                .designSystemGroupedListRow()

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.close)
                            .viewControlIconStyle()
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showsThemes) {
                NavigationStack {
                    ThemeSelectionView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .bottomSheetPullToDismiss()
            }
            .sheet(isPresented: $showsFonts) {
                NavigationStack {
                    FontOverrideSettingsView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .bottomSheetPullToDismiss()
    }
}

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        List {
            Section("Sport Themes") {
                ForEach(themeManager.availableThemes) { theme in
                    Button {
                        themeManager.select(themeID: theme.id)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            themeSwatch(theme)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(theme.name)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(theme.isDark ? "Dark" : "Light")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if themeManager.selectedThemeID == theme.id {
                                Image(systemName: DesignSystem.Icon.check)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.check)
                        .viewControlIconStyle()
                }
                .accessibilityLabel("Done")
            }
        }
    }

    private func themeSwatch(_ theme: FitTheme) -> some View {
        ZStack {
            Circle()
                .fill(theme.background)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(theme.accent)
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(theme.highlight)
                .rotationEffect(.degrees(180))
        }
        .frame(width: 36, height: 36)
        .overlay(Circle().stroke(theme.divider, lineWidth: 1))
    }
}

struct FontOverrideSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fitMin.usesRoundedTimerDigits") private var usesRoundedTimerDigits = true

    var body: some View {
        SettingsSheet(title: "Fonts") {
            Section("Timer") {
                Toggle("Rounded timer digits", isOn: $usesRoundedTimerDigits)
                Text("Sport themes define the primary type style. This preference is reserved for expanding fit min font controls alongside the other min apps.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .designSystemGroupedListStyle()
    }
}

#Preview {
    AccountSheetView()
        .environment(ThemeManager.shared)
}
