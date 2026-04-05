//
//  TapInteractionBehaviors.swift
//  WatchedIt
//
//  Created by Cursor on 3/2/26.
//

import SwiftUI

// MARK: - Tap Interaction Style

enum TapInteractionStyle: String, CaseIterable {
    case classic = "Classic"
    case bounce = "Bounce"
    case ripple = "Ripple"
    case shimmer = "Shimmer"
    case glowPulse = "Glow Pulse"
    
    var description: String {
        switch self {
        case .classic:
            return "Simple press opacity fade (legacy behavior)"
        case .bounce:
            return "Recess and rebound with shake on release"
        case .ripple:
            return "Metal shader ripple effect spreading outward"
        case .shimmer:
            return "Sparkle and shimmer with particle effects"
        case .glowPulse:
            return "Glowing outline that pulses on interaction"
        }
    }
    
    var icon: String {
        switch self {
        case .classic:
            return "circle.lefthalf.filled"
        case .bounce:
            return "arrow.down.to.line.compact"
        case .ripple:
            return "wave.3.right"
        case .shimmer:
            return "sparkles"
        case .glowPulse:
            return "waveform.path.ecg"
        }
    }
}

// MARK: - Tap Interaction Parameters

struct TapInteractionParameters {
    // Bounce parameters
    var bounceScale: Double = 0.92
    var bounceShakeIntensity: Double = 0.5
    var bounceDuration: Double = 0.3
    
    // Ripple parameters
    var rippleSpeed: Double = 1.0
    var rippleAmplitude: Double = 0.5
    var rippleFrequency: Double = 1.0
    
    // Shimmer parameters
    var shimmerIntensity: Double = 0.7
    var shimmerSpeed: Double = 1.0
    var shimmerParticleCount: Double = 0.6
    
    // Glow Pulse parameters
    var glowIntensity: Double = 0.8
    var glowPulseSpeed: Double = 1.0
    var glowColorIntensity: Double = 0.7
    
    static var storageKey: String { "tapInteractionParameters" }
    
    // Encode/decode for AppStorage
    func encode() -> Data {
        let dict: [String: Double] = [
            "bounceScale": bounceScale,
            "bounceShakeIntensity": bounceShakeIntensity,
            "bounceDuration": bounceDuration,
            "rippleSpeed": rippleSpeed,
            "rippleAmplitude": rippleAmplitude,
            "rippleFrequency": rippleFrequency,
            "shimmerIntensity": shimmerIntensity,
            "shimmerSpeed": shimmerSpeed,
            "shimmerParticleCount": shimmerParticleCount,
            "glowIntensity": glowIntensity,
            "glowPulseSpeed": glowPulseSpeed,
            "glowColorIntensity": glowColorIntensity
        ]
        return (try? JSONEncoder().encode(dict)) ?? Data()
    }
    
    static func decode(from data: Data) -> TapInteractionParameters {
        guard let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return TapInteractionParameters()
        }
        
        var params = TapInteractionParameters()
        params.bounceScale = dict["bounceScale"] ?? 0.92
        params.bounceShakeIntensity = dict["bounceShakeIntensity"] ?? 0.5
        params.bounceDuration = dict["bounceDuration"] ?? 0.3
        params.rippleSpeed = dict["rippleSpeed"] ?? 1.0
        params.rippleAmplitude = dict["rippleAmplitude"] ?? 0.5
        params.rippleFrequency = dict["rippleFrequency"] ?? 1.0
        params.shimmerIntensity = dict["shimmerIntensity"] ?? 0.7
        params.shimmerSpeed = dict["shimmerSpeed"] ?? 1.0
        params.shimmerParticleCount = dict["shimmerParticleCount"] ?? 0.6
        params.glowIntensity = dict["glowIntensity"] ?? 0.8
        params.glowPulseSpeed = dict["glowPulseSpeed"] ?? 1.0
        params.glowColorIntensity = dict["glowColorIntensity"] ?? 0.7
        return params
    }
}

// MARK: - Bounce Effect View Modifier

struct BounceEffectModifier: ViewModifier {
    let isPressed: Bool
    let scale: Double
    let shakeIntensity: Double
    let duration: Double
    
    @State private var shakeOffset: CGFloat = 0
    @State private var shakeRotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .offset(x: shakeOffset)
            .rotationEffect(.degrees(shakeRotation))
            .animation(.spring(response: duration, dampingFraction: 0.6), value: isPressed)
            .onChange(of: isPressed) { _, newValue in
                if !newValue {
                    // Released - trigger shake
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                        shakeOffset = 5 * shakeIntensity
                        shakeRotation = 2 * shakeIntensity
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                            shakeOffset = 0
                            shakeRotation = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Glow Pulse Effect View Modifier

struct GlowPulseEffectModifier: ViewModifier {
    let isPressed: Bool
    let intensity: Double
    let pulseSpeed: Double
    let colorIntensity: Double
    let accentColor: Color
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(colorIntensity), lineWidth: 2 * intensity)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .blur(radius: 4 * intensity)
            )
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    // Pressed - start pulse
                    pulseScale = 1.0
                    pulseOpacity = 0.8 * intensity
                    
                    withAnimation(.easeOut(duration: 0.4 / pulseSpeed)) {
                        pulseScale = 1.15
                        pulseOpacity = 0.0
                    }
                } else {
                    // Released - final pulse
                    pulseScale = 1.0
                    pulseOpacity = 1.0 * intensity
                    
                    withAnimation(.easeOut(duration: 0.3 / pulseSpeed)) {
                        pulseScale = 1.3
                        pulseOpacity = 0.0
                    }
                }
            }
    }
}

// MARK: - Classic Opacity Effect View Modifier

struct ClassicOpacityEffectModifier: ViewModifier {
    let isPressed: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? 0.65 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

// MARK: - Interactive Tap Modifier

struct InteractiveTapModifier: ViewModifier {
    let style: TapInteractionStyle
    let parameters: TapInteractionParameters
    let accentColor: Color
    
    @State private var isPressed = false
    @State private var didCancelForDrag = false
    
    private let swipeCancellationDistance: CGFloat = 10
    
    func body(content: Content) -> some View {
        effectContent(content)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let translation = value.translation
                        let movement = sqrt((translation.width * translation.width) + (translation.height * translation.height))
                        
                        if movement > swipeCancellationDistance {
                            didCancelForDrag = true
                            if isPressed {
                                isPressed = false
                            }
                        } else if !didCancelForDrag, !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        didCancelForDrag = false
                    }
            )
    }
    
    @ViewBuilder
    private func effectContent(_ content: Content) -> some View {
        switch style {
        case .classic:
            content.modifier(
                ClassicOpacityEffectModifier(
                    isPressed: isPressed
                )
            )
        case .bounce:
            content.modifier(
                BounceEffectModifier(
                    isPressed: isPressed,
                    scale: parameters.bounceScale,
                    shakeIntensity: parameters.bounceShakeIntensity,
                    duration: parameters.bounceDuration
                )
            )
        case .ripple:
            content.modifier(
                RippleEffectModifier(
                    isPressed: isPressed,
                    speed: parameters.rippleSpeed,
                    amplitude: parameters.rippleAmplitude,
                    frequency: parameters.rippleFrequency,
                    accentColor: accentColor
                )
            )
        case .shimmer:
            content.modifier(
                ShimmerEffectModifier(
                    isPressed: isPressed,
                    intensity: parameters.shimmerIntensity,
                    speed: parameters.shimmerSpeed,
                    particleCount: parameters.shimmerParticleCount,
                    accentColor: accentColor
                )
            )
        case .glowPulse:
            content.modifier(
                GlowPulseEffectModifier(
                    isPressed: isPressed,
                    intensity: parameters.glowIntensity,
                    pulseSpeed: parameters.glowPulseSpeed,
                    colorIntensity: parameters.glowColorIntensity,
                    accentColor: accentColor
                )
            )
        }
    }
}

// MARK: - Interactive Tap Button Style

struct InteractiveTapButtonStyle: ButtonStyle {
    let style: TapInteractionStyle
    let parameters: TapInteractionParameters
    let accentColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        InteractiveTapStyledContent(
            style: style,
            parameters: parameters,
            accentColor: accentColor,
            isPressed: configuration.isPressed
        ) {
            configuration.label
        }
    }
}

private struct InteractiveTapStyledContent<Content: View>: View {
    let style: TapInteractionStyle
    let parameters: TapInteractionParameters
    let accentColor: Color
    let isPressed: Bool
    let content: Content
    
    init(
        style: TapInteractionStyle,
        parameters: TapInteractionParameters,
        accentColor: Color,
        isPressed: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.parameters = parameters
        self.accentColor = accentColor
        self.isPressed = isPressed
        self.content = content()
    }
    
    var body: some View {
        switch style {
        case .classic:
            content.modifier(
                ClassicOpacityEffectModifier(
                    isPressed: isPressed
                )
            )
        case .bounce:
            content.modifier(
                BounceEffectModifier(
                    isPressed: isPressed,
                    scale: parameters.bounceScale,
                    shakeIntensity: parameters.bounceShakeIntensity,
                    duration: parameters.bounceDuration
                )
            )
        case .ripple:
            content.modifier(
                RippleEffectModifier(
                    isPressed: isPressed,
                    speed: parameters.rippleSpeed,
                    amplitude: parameters.rippleAmplitude,
                    frequency: parameters.rippleFrequency,
                    accentColor: accentColor
                )
            )
        case .shimmer:
            content.modifier(
                ShimmerEffectModifier(
                    isPressed: isPressed,
                    intensity: parameters.shimmerIntensity,
                    speed: parameters.shimmerSpeed,
                    particleCount: parameters.shimmerParticleCount,
                    accentColor: accentColor
                )
            )
        case .glowPulse:
            content.modifier(
                GlowPulseEffectModifier(
                    isPressed: isPressed,
                    intensity: parameters.glowIntensity,
                    pulseSpeed: parameters.glowPulseSpeed,
                    colorIntensity: parameters.glowColorIntensity,
                    accentColor: accentColor
                )
            )
        }
    }
}

// MARK: - Ripple Effect View Modifier

struct RippleEffectModifier: ViewModifier {
    let isPressed: Bool
    let speed: Double
    let amplitude: Double
    let frequency: Double
    let accentColor: Color
    
    @State private var rippleProgress: Double = 0.0
    @State private var rippleOpacity: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            guard rippleOpacity > 0 else { return }
                            
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2
                            
                            for i in 0..<Int(3 * frequency) {
                                let offset = Double(i) * 0.33 / frequency
                                let adjustedProgress = max(0, min(1, rippleProgress - offset))
                                let radius = maxRadius * adjustedProgress
                                let opacity = rippleOpacity * (1.0 - adjustedProgress)
                                
                                if radius > 0 && opacity > 0 {
                                    var path = Path()
                                    path.addEllipse(in: CGRect(
                                        x: center.x - radius,
                                        y: center.y - radius,
                                        width: radius * 2,
                                        height: radius * 2
                                    ))
                                    
                                    context.stroke(
                                        path,
                                        with: .color(accentColor.opacity(opacity)),
                                        lineWidth: 2 * amplitude
                                    )
                                }
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
            )
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    rippleProgress = 0.0
                    rippleOpacity = 0.8
                    
                    withAnimation(.easeOut(duration: 0.6 / speed)) {
                        rippleProgress = 1.0
                        rippleOpacity = 0.0
                    }
                }
            }
    }
}

// MARK: - Shimmer Effect View Modifier

struct ShimmerEffectModifier: ViewModifier {
    let isPressed: Bool
    let intensity: Double
    let speed: Double
    let particleCount: Double
    let accentColor: Color
    
    @State private var shimmerProgress: Double = 0.0
    @State private var shimmerOpacity: Double = 0.0
    @State private var particleOffsets: [CGPoint] = []
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            guard shimmerOpacity > 0 else { return }
                            
                            let particleTotal = Int(20 * particleCount)
                            
                            for i in 0..<particleTotal {
                                if i < particleOffsets.count {
                                    let offset = particleOffsets[i]
                                    let particleProgress = shimmerProgress + Double(i) * 0.03
                                    let adjustedProgress = max(0, min(1, particleProgress))
                                    
                                    let x = offset.x * size.width
                                    let y = offset.y * size.height - adjustedProgress * 30
                                    let size = (4 + Double(i % 3) * 2) * intensity
                                    let opacity = shimmerOpacity * (1.0 - adjustedProgress) * (0.5 + Double.random(in: 0...0.5))
                                    
                                    if opacity > 0 {
                                        var path = Path()
                                        path.addEllipse(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size))
                                        
                                        context.fill(
                                            path,
                                            with: .color(accentColor.opacity(opacity))
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
            )
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    // Generate random particle positions
                    let particleTotal = Int(20 * particleCount)
                    particleOffsets = (0..<particleTotal).map { _ in
                        CGPoint(
                            x: Double.random(in: 0.2...0.8),
                            y: Double.random(in: 0.3...0.9)
                        )
                    }
                    
                    shimmerProgress = 0.0
                    shimmerOpacity = 1.0 * intensity
                    
                    withAnimation(.easeOut(duration: 0.8 / speed)) {
                        shimmerProgress = 1.0
                        shimmerOpacity = 0.0
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func interactiveTapEffect(
        style: TapInteractionStyle,
        parameters: TapInteractionParameters,
        accentColor: Color = DesignSystem.Color.accent
    ) -> some View {
        self.modifier(InteractiveTapModifier(
            style: style,
            parameters: parameters,
            accentColor: accentColor
        ))
    }
}

extension Button {
    func interactiveTapStyle(
        style: TapInteractionStyle,
        parameters: TapInteractionParameters,
        accentColor: Color = DesignSystem.Color.accent
    ) -> some View {
        self.buttonStyle(InteractiveTapButtonStyle(
            style: style,
            parameters: parameters,
            accentColor: accentColor
        ))
    }
}
