//
//  ThemeManager.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import Observation

@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    
    private(set) var currentTheme: AppTheme
    private(set) var availableThemes: [AppTheme]
    
    private init() {
        self.availableThemes = AppTheme.defaultThemes
        self.currentTheme = availableThemes.first { $0.id == "default-cyan" } ?? availableThemes[0]
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}

struct AppTheme: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let accent: CodableColor
    let secondaryAccent: CodableColor?
    let headlineColor: CodableColor
    let isDark: Bool
    let supportsLightMode: Bool
    let darkModeBackground: CodableColor?
    let lightModeBackground: CodableColor?
    
    init(
        id: String,
        name: String,
        accent: Color,
        secondaryAccent: Color? = nil,
        headlineColor: Color,
        isDark: Bool = false,
        supportsLightMode: Bool = true,
        darkModeBackground: Color? = nil,
        lightModeBackground: Color? = nil
    ) {
        self.id = id
        self.name = name
        self.accent = CodableColor(accent)
        self.secondaryAccent = secondaryAccent.map { CodableColor($0) }
        self.headlineColor = CodableColor(headlineColor)
        self.isDark = isDark
        self.supportsLightMode = supportsLightMode
        self.darkModeBackground = darkModeBackground.map { CodableColor($0) }
        self.lightModeBackground = lightModeBackground.map { CodableColor($0) }
    }
    
    static let defaultThemes: [AppTheme] = [
        AppTheme(
            id: "default-cyan",
            name: "Cyan",
            accent: Color.cyan,
            headlineColor: Color.cyan,
            supportsLightMode: true
        ),
        AppTheme(
            id: "orange",
            name: "Orange",
            accent: Color.orange,
            headlineColor: Color.orange,
            supportsLightMode: true
        ),
        AppTheme(
            id: "green",
            name: "Green",
            accent: Color.green,
            headlineColor: Color.green,
            supportsLightMode: true
        ),
        AppTheme(
            id: "blue",
            name: "Blue",
            accent: Color.blue,
            headlineColor: Color.blue,
            supportsLightMode: true
        ),
        AppTheme(
            id: "purple",
            name: "Purple",
            accent: Color.purple,
            headlineColor: Color.purple,
            supportsLightMode: true
        ),
        AppTheme(
            id: "pink",
            name: "Pink",
            accent: Color.pink,
            headlineColor: Color.pink,
            supportsLightMode: true
        ),
        AppTheme(
            id: "red",
            name: "Red",
            accent: Color.red,
            headlineColor: Color.red,
            supportsLightMode: true
        ),
        AppTheme(
            id: "yellow",
            name: "Yellow",
            accent: Color.yellow,
            headlineColor: Color.yellow,
            supportsLightMode: true
        ),
    ]
}

/// A wrapper for Color that conforms to Codable
struct CodableColor: Codable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension AppTheme {
    var accent: Color {
        self.accent.color
    }
    
    var secondaryAccent: Color? {
        self.secondaryAccent?.color
    }
    
    var headlineColor: Color {
        self.headlineColor.color
    }
    
    var darkModeBackground: Color? {
        self.darkModeBackground?.color
    }
    
    var lightModeBackground: Color? {
        self.lightModeBackground?.color
    }
}
