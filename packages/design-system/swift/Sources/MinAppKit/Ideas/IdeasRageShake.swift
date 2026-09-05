import SwiftUI

#if os(iOS)

/// Opens Ideas & bugs when the phone is shaken side-to-side (~two back-and-forths).
public struct IdeasRageShakeModifier: ViewModifier {
    public let app: AgentAppID
    @State private var showIdeas = false
    @State private var handlerID: UUID?

    public init(app: AgentAppID) {
        self.app = app
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                guard handlerID == nil else { return }
                handlerID = RageShakeDetector.shared.addHandler {
                    showIdeas = true
                }
            }
            .onDisappear {
                if let handlerID {
                    RageShakeDetector.shared.remove(handlerID)
                    self.handlerID = nil
                }
            }
            .sheet(isPresented: $showIdeas) {
                NavigationStack {
                    IdeasListView(app: app)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showIdeas = false }
                            }
                        }
                }
            }
    }
}

/// Generic shake → callback modifier for apps that own their own sheet.
public struct RageShakeModifier: ViewModifier {
    public let enabled: Bool
    public let action: () -> Void
    @State private var handlerID: UUID?

    public init(enabled: Bool = true, action: @escaping () -> Void) {
        self.enabled = enabled
        self.action = action
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: enabled) { _, isOn in
                sync(isOn)
            }
            .onAppear { sync(enabled) }
            .onDisappear {
                if let handlerID {
                    RageShakeDetector.shared.remove(handlerID)
                    self.handlerID = nil
                }
            }
    }

    private func sync(_ isOn: Bool) {
        if isOn {
            guard handlerID == nil else { return }
            handlerID = RageShakeDetector.shared.addHandler(action)
        } else if let handlerID {
            RageShakeDetector.shared.remove(handlerID)
            self.handlerID = nil
        }
    }
}

public extension View {
    /// Shake the phone to open Ideas & bugs for this min app.
    func ideasRageShake(app: AgentAppID) -> some View {
        modifier(IdeasRageShakeModifier(app: app))
    }

    /// Shake the phone to run a custom action (e.g. Cadence feedback sheet).
    func onRageShake(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        modifier(RageShakeModifier(enabled: enabled, action: action))
    }
}

#else

public extension View {
    func ideasRageShake(app: AgentAppID) -> some View { self }
    func onRageShake(enabled: Bool = true, perform action: @escaping () -> Void) -> some View { self }
}

#endif
