import SwiftUI
import AVKit

/// Native AirPlay route picker, themed to match the player chrome. Replaces the previous
/// non-functional placeholder so AirPlay actually presents the system route menu.
struct AirPlayRoutePickerView: UIViewRepresentable {
    var activeTintColor: UIColor
    var inactiveTintColor: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.backgroundColor = .clear
        view.activeTintColor = activeTintColor
        view.tintColor = inactiveTintColor
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = activeTintColor
        uiView.tintColor = inactiveTintColor
    }
}
