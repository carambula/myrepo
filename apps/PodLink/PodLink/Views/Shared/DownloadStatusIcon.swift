import SwiftUI

struct DownloadStatusIcon: View {
    let iconName: String
    let iconColor: Color
    let isDownloading: Bool
    var iconSize: CGFloat = 22
    var frameSize: CGFloat = 24

    @State private var ringRotation: Double = 0

    var body: some View {
        ZStack {
            if isDownloading {
                Circle()
                    .stroke(iconColor.opacity(0.2), lineWidth: 2)
                    .frame(width: frameSize, height: frameSize)

                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(iconColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: frameSize, height: frameSize)
                    .rotationEffect(.degrees(ringRotation))
                    .onAppear {
                        ringRotation = 360
                    }
                    .onChange(of: isDownloading) { _, newValue in
                        ringRotation = newValue ? 360 : 0
                    }
                    .animation(
                        isDownloading
                            ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                            : .default,
                        value: ringRotation
                    )
            }

            Image(systemName: iconName)
                .font(.system(size: iconSize))
                .foregroundColor(iconColor)
        }
        .frame(width: frameSize + 6, height: frameSize + 6)
    }
}
