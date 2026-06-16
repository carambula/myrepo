import SwiftUI

struct SetTimerConfiguratorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let timer: SetTimer?
    var onSave: (SetTimerConfiguration, String) -> Void

    @State private var configuration: SetTimerConfiguration
    @State private var customTitle: String

    init(timer: SetTimer?, onSave: @escaping (SetTimerConfiguration, String) -> Void) {
        self.timer = timer
        self.onSave = onSave
        _configuration = State(initialValue: timer?.configuration ?? SetTimerConfiguration())
        _customTitle = State(initialValue: timer?.customTitle ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Type") {
                    Picker("Interval Type", selection: $configuration.intervalType) {
                        ForEach(IntervalType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Rest Type", selection: $configuration.restType) {
                        ForEach(RestType.allCases) { type in
                            Text(type.title).tag(type)
                                .disabled(!type.isAvailable(for: configuration.intervalType))
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Reps")
                            Spacer()
                            Text("\(configuration.reps)")
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Picker("Reps", selection: $configuration.reps) {
                            ForEach(1...100, id: \.self) { rep in
                                Text("\(rep)").tag(rep)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 116)
                    }
                }
                .designSystemGroupedListRow()

                Section("Work") {
                    workInputs
                }
                .designSystemGroupedListRow()

                Section("Rest") {
                    restInputs
                }
                .designSystemGroupedListRow()

                Section("Title") {
                    TextField("Optional title", text: $customTitle)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Generated")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text(SetTimerTitleFormatter.title(for: configuration))
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .designSystemGroupedListRow()

                Section("Summary") {
                    HStack {
                        Text("Total workout")
                        Spacer()
                        Text(SetTimerTitleFormatter.clockDuration(SetTimerScheduleBuilder.totalDuration(for: configuration)))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle(timer == nil ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.close)
                            .viewControlIconStyle()
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(configuration.normalized, customTitle)
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.check)
                            .viewControlIconStyle()
                    }
                    .disabled(!canSave)
                    .accessibilityLabel("Save")
                }
            }
            .onChange(of: configuration.intervalType) { _, newValue in
                if !configuration.restType.isAvailable(for: newValue) {
                    configuration.restType = .fixed
                }
            }
        }
        .themeBackground()
    }

    @ViewBuilder
    private var workInputs: some View {
        switch configuration.intervalType {
        case .fixed:
            durationStepper("Work duration", seconds: $configuration.workSeconds)
        case .ladder:
            durationStepper("Starting work", seconds: $configuration.workSeconds)
            durationStepper("Work step", seconds: $configuration.workStepSeconds)
        case .pyramid:
            durationStepper("Base work", seconds: $configuration.workSeconds)
            durationStepper("Pyramid step", seconds: $configuration.workStepSeconds)
        case .wave:
            durationStepper("First work duration", seconds: $configuration.workSeconds)
            durationStepper("Alternating work duration", seconds: $configuration.alternateWorkSeconds)
        }
    }

    @ViewBuilder
    private var restInputs: some View {
        switch configuration.restType {
        case .fixed:
            durationStepper("Rest duration", seconds: $configuration.restSeconds)
        case .proportional:
            Stepper(value: $configuration.proportionalRestPercent, in: 1...300, step: 5) {
                HStack {
                    Text("Rest proportion")
                    Spacer()
                    Text("\(configuration.proportionalRestPercent)%")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        case .progressive:
            durationStepper("Starting rest", seconds: $configuration.restSeconds)
            durationStepper("Rest step", seconds: $configuration.restStepSeconds)
        case .regressive:
            durationStepper("Starting rest", seconds: $configuration.restSeconds)
            durationStepper("Rest step down", seconds: $configuration.restStepSeconds)
        }
    }

    private var canSave: Bool {
        !SetTimerScheduleBuilder.segments(for: configuration).isEmpty
    }

    private func durationStepper(_ title: String, seconds: Binding<Int>) -> some View {
        Stepper(value: seconds, in: 1...7200, step: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(SetTimerTitleFormatter.durationToken(seconds.wrappedValue))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    SetTimerConfiguratorSheet(timer: nil) { _, _ in }
        .environment(ThemeManager.shared)
}
