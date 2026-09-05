import SwiftUI

public enum MinAnimation {
    public static let quick: Animation = .easeInOut(duration: 0.15)
    public static let standard: Animation = .easeInOut(duration: 0.25)
    public static let slow: Animation = .easeInOut(duration: 0.4)

    public static let springQuick: Animation = .spring(response: 0.3, dampingFraction: 0.7)
    public static let springStandard: Animation = .spring(response: 0.4, dampingFraction: 0.75)
    public static let springSlow: Animation = .spring(response: 0.6, dampingFraction: 0.8)
}
