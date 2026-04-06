//
//  ThemeManager.swift
//  Cyclismo
//
//  Theme Management System (ported from WatchedIt).
//

import SwiftUI
import Combine
import UIKit
import CloudKit

// MARK: - Theme Protocol (extends MinTheme from MinAppKit)

/// Cyclismo extends MinTheme with duotone color properties.
protocol Theme: MinTheme {
    var duotoneHighlightColor: SwiftUI.Color { get }
    var duotoneShadowColor: SwiftUI.Color { get }
}

extension Theme {
    var duotoneHighlightColor: SwiftUI.Color {
        let accentUIColor = UIColor(accent)
        let headlineUIColor = UIColor(headlineColor)
        return accentUIColor.perceivedLuminance >= headlineUIColor.perceivedLuminance ? accent : headlineColor
    }

    var duotoneShadowColor: SwiftUI.Color {
        let accentUIColor = UIColor(accent)
        let headlineUIColor = UIColor(headlineColor)
        return accentUIColor.perceivedLuminance < headlineUIColor.perceivedLuminance ? accent : headlineColor
    }
}

extension CustomTheme: Theme {}

// MARK: - Built-in Themes

struct CyclismoTheme: Theme {
    let name = "Cyclismo"
    let accent = SwiftUI.Color(UIColor.systemGray)
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(UIColor.systemGray5)
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = nil
    let darkModeBackground: SwiftUI.Color? = nil
    let lightModeBackground: SwiftUI.Color? = nil
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = nil
    let lightModeHeadlineColor: SwiftUI.Color? = nil
    let headlineColor = SwiftUI.Color.primary
}

struct UAETheme: Theme {
    let name = "UAE Team Emirates"
    let accent = SwiftUI.Color(red: 0.83, green: 0.05, blue: 0.11) // team red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.black
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.02, blue: 0.03)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.06, green: 0.06, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.98, green: 0.98, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct AlpecinTheme: Theme {
    let name = "Alpecin-Deceuninck"
    let accent = SwiftUI.Color(red: 0.12, green: 0.38, blue: 0.77) // team blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.55, green: 0.57, blue: 0.6) // silver gray
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.17, green: 0.19, blue: 0.22)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.07, green: 0.08, blue: 0.09)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.98)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct VismaTheme: Theme {
    let name = "Visma | Lease a Bike"
    let accent = SwiftUI.Color(red: 1.0, green: 0.89, blue: 0.1) // bright yellow
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.black
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default).width(.condensed)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.11, green: 0.11, blue: 0.12)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.03, green: 0.03, blue: 0.04)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.98, blue: 0.88)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.89, blue: 0.1)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color(red: 1.0, green: 0.89, blue: 0.1)
}

struct RedBullBoraTheme: Theme {
    let name = "Red Bull-BORA-hansgrohe"
    let accent = SwiftUI.Color(red: 0.05, green: 0.26, blue: 0.66) // blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.84, green: 0.09, blue: 0.16) // red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .rounded)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.14, green: 0.17, blue: 0.22)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.06, green: 0.08, blue: 0.13)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.93, green: 0.94, blue: 0.96) // silver-ish
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.8, blue: 0.18) // yellow
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.55, green: 0.08, blue: 0.13) // deep red
    let headlineColor = SwiftUI.Color(red: 0.96, green: 0.8, blue: 0.18)
}

struct AlUlaJaycoTheme: Theme {
    let name = "AlUla Jayco"
    let accent = SwiftUI.Color(red: 0.58, green: 0.09, blue: 0.88) // bright purple
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.53, green: 1.0, blue: 0.11) // neon green
    let headlineFont = Font.system(size: 22, weight: .bold, design: .rounded)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.14, green: 0.04, blue: 0.18)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.04, blue: 0.05)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.95, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.53, green: 1.0, blue: 0.11)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.28, green: 0.04, blue: 0.45)
    let headlineColor = SwiftUI.Color(red: 0.53, green: 1.0, blue: 0.11)
}

struct IneosTheme: Theme {
    let name = "INEOS Grenadiers"
    let accent = SwiftUI.Color(red: 0.95, green: 0.25, blue: 0.1) // flame orange-red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.black
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.2, green: 0.06, blue: 0.03)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.06, green: 0.06, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.97, blue: 0.96)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

// MARK: - Historic Teams

struct SevenElevenTheme: Theme {
    let name = "7-Eleven"
    let accent = SwiftUI.Color(red: 0.92, green: 0.16, blue: 0.18) // classic 7-Eleven red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.0, green: 0.56, blue: 0.31) // 7-Eleven green
    let headlineFont = Font.system(size: 22, weight: .black, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.04, blue: 0.04)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.06, green: 0.06, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.96, blue: 0.96)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct SkyTheme: Theme {
    let name = "Team Sky"
    let accent = SwiftUI.Color(red: 0.0, green: 0.47, blue: 0.84) // Sky blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.black
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default).width(.condensed)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.03, green: 0.11, blue: 0.18)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.02, blue: 0.03)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.94, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.0, green: 0.47, blue: 0.84)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color(red: 0.0, green: 0.47, blue: 0.84)
}

struct QuickstepTheme: Theme {
    let name = "Quickstep"
    let accent = SwiftUI.Color(red: 0.0, green: 0.34, blue: 0.73) // Quickstep blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.white
    let headlineFont = Font.system(size: 22, weight: .heavy, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.08, blue: 0.16)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.08)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.95, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct LaVieClairetheme: Theme {
    let name = "La Vie Claire"
    let accent = SwiftUI.Color(red: 0.93, green: 0.18, blue: 0.22) // primary red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.82, blue: 0.0) // yellow
    let headlineFont = Font.system(size: 22, weight: .bold, design: .rounded)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.04, blue: 0.05)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.06, green: 0.06, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.98, blue: 0.94)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.82, blue: 0.0)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.93, green: 0.18, blue: 0.22)
    let headlineColor = SwiftUI.Color(red: 1.0, green: 0.82, blue: 0.0)
}

// MARK: - Current Teams

struct EFEducationTheme: Theme {
    let name = "EF Education-EasyPost"
    let accent = SwiftUI.Color(red: 0.92, green: 0.24, blue: 0.58) // signature pink
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.0, green: 0.64, blue: 0.91) // blue
    let headlineFont = Font.system(size: 22, weight: .bold, design: .rounded)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.05, blue: 0.12)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.06, green: 0.05, blue: 0.06)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.95, blue: 0.98)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.92, green: 0.24, blue: 0.58)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.64, green: 0.08, blue: 0.34)
    let headlineColor = SwiftUI.Color(red: 0.92, green: 0.24, blue: 0.58)
}

struct LidlTrekTheme: Theme {
    let name = "Lidl-Trek"
    let accent = SwiftUI.Color(red: 0.0, green: 0.52, blue: 0.96) // Trek blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.93, green: 0.0, blue: 0.26) // Lidl red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.12, blue: 0.20)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.06, blue: 0.08)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct UnoXTheme: Theme {
    let name = "UNO-X Mobility"
    let accent = SwiftUI.Color(red: 0.97, green: 0.51, blue: 0.0) // orange
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.88, blue: 0.0) // yellow
    let headlineFont = Font.system(size: 22, weight: .black, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.10, blue: 0.02)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.05)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.97, blue: 0.94)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.88, blue: 0.0)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color(red: 1.0, green: 0.88, blue: 0.0)
}

struct NSNTheme: Theme {
    let name = "NSN"
    let accent = SwiftUI.Color(red: 0.93, green: 0.0, blue: 0.29) // red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.black
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.02, blue: 0.06)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.06)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.96, blue: 0.97)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct FDJSuezTheme: Theme {
    let name = "FDJ-Suez"
    let accent = SwiftUI.Color(red: 0.0, green: 0.35, blue: 0.71) // FDJ blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.white
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.08, blue: 0.15)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

// MARK: - Country Themes

struct FranceTheme: Theme {
    let name = "France"
    let accent = SwiftUI.Color(red: 0.0, green: 0.22, blue: 0.64) // French blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.93, green: 0.15, blue: 0.22) // French red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .serif)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.06, blue: 0.14)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.97, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct USATheme: Theme {
    let name = "USA"
    let accent = SwiftUI.Color(red: 0.76, green: 0.11, blue: 0.22) // Old Glory red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.0, green: 0.20, blue: 0.45) // Old Glory blue
    let headlineFont = Font.system(size: 22, weight: .black, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.16, green: 0.03, blue: 0.05)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.06)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.97, blue: 0.98)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct ItalyTheme: Theme {
    let name = "Italy"
    let accent = SwiftUI.Color(red: 0.0, green: 0.55, blue: 0.30) // Italian green
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.81, green: 0.13, blue: 0.16) // Italian red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .serif)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.12, blue: 0.07)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.05)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.99, blue: 0.97)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct DenmarkTheme: Theme {
    let name = "Denmark"
    let accent = SwiftUI.Color(red: 0.78, green: 0.11, blue: 0.16) // Dannebrog red
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.white
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.16, green: 0.03, blue: 0.04)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.06)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.96, blue: 0.97)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct SlovakiaTheme: Theme {
    let name = "Slovakia"
    let accent = SwiftUI.Color(red: 0.0, green: 0.33, blue: 0.65) // Slovak blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.87, green: 0.16, blue: 0.22) // Slovak red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.08, blue: 0.14)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.07)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct NetherlandsTheme: Theme {
    let name = "Netherlands"
    let accent = SwiftUI.Color(red: 1.0, green: 0.55, blue: 0.0) // Dutch orange
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.93, green: 0.17, blue: 0.21) // Dutch red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.11, blue: 0.02)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.05)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.98, blue: 0.95)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.68, blue: 0.26)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color(red: 1.0, green: 0.68, blue: 0.26)
}

struct BelgiumTheme: Theme {
    let name = "Belgium"
    let accent = SwiftUI.Color(red: 0.97, green: 0.82, blue: 0.0) // Belgian yellow
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color.black
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.18, green: 0.16, blue: 0.02)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.04, blue: 0.04)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.99, green: 0.99, blue: 0.94)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.97, green: 0.82, blue: 0.0)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color(red: 0.97, green: 0.82, blue: 0.0)
}

struct UKTheme: Theme {
    let name = "United Kingdom"
    let accent = SwiftUI.Color(red: 0.0, green: 0.15, blue: 0.49) // Union Jack blue
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.79, green: 0.09, blue: 0.19) // Union Jack red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .serif)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.05, blue: 0.11)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.04, blue: 0.06)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.97, green: 0.97, blue: 0.99)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

struct AustraliaTheme: Theme {
    let name = "Australia"
    let accent = SwiftUI.Color(red: 0.0, green: 0.52, blue: 0.31) // green
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.75, blue: 0.0) // gold
    let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.11, blue: 0.07)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.05)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.99, blue: 0.97)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.75, blue: 0.0)
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color(red: 1.0, green: 0.75, blue: 0.0)
}

struct MexicoTheme: Theme {
    let name = "Mexico"
    let accent = SwiftUI.Color(red: 0.0, green: 0.42, blue: 0.30) // Mexican green
    let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 0.81, green: 0.13, blue: 0.16) // Mexican red
    let headlineFont = Font.system(size: 22, weight: .bold, design: .rounded)
    let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.09, blue: 0.07)
    let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.05)
    let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.96, green: 0.99, blue: 0.97)
    let supportsLightMode = true
    let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.white
    let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color.black
    let headlineColor = SwiftUI.Color.white
}

// MARK: - Custom Theme Models (ThemeColorData, ThemeFontStyle, CustomThemeDefinition, 
// CustomTheme, ThemeAdaptedPalette provided by MinAppKit)

private enum ThemePreferences {
    static let selectedThemeKey = "Cyclismo.selectedTheme"
    static let customThemesStorageKey = "Cyclismo.customThemes"
    static let lastUpdatedKey = "Cyclismo.themePreferencesLastUpdated"
    static let defaultThemeName = "AlUla Jayco"

    static func selectedThemeName() -> String {
        UserDefaults.standard.string(forKey: selectedThemeKey) ?? defaultThemeName
    }

    static func setSelectedThemeName(_ name: String) {
        UserDefaults.standard.set(name, forKey: selectedThemeKey)
    }

    static func customThemesData() -> Data {
        UserDefaults.standard.data(forKey: customThemesStorageKey) ?? Data()
    }

    static func decodeThemes(from data: Data) -> [CustomThemeDefinition] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CustomThemeDefinition].self, from: data)) ?? []
    }

    static func encodeThemes(_ themes: [CustomThemeDefinition]) -> Data {
        (try? JSONEncoder().encode(themes)) ?? Data()
    }

    static func lastUpdated() -> Date {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date ?? Date.distantPast
    }

    static func updateLastUpdated(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastUpdatedKey)
    }
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: Theme {
        didSet {
            ThemePreferences.setSelectedThemeName(currentTheme.name)
            ThemePreferences.updateLastUpdated()
            scheduleThemesPushToCloudKit()
        }
    }

    @Published private(set) var customThemeDefinitions: [CustomThemeDefinition] = []
    private var hasRestoredThemesThisSession = false
    private var hasPushedThemesThisSession = false
    private var pendingPushTask: Task<Void, Never>?

    private let builtInThemes: [Theme] = [
        CyclismoTheme(),
        UAETheme(),
        AlpecinTheme(),
        VismaTheme(),
        RedBullBoraTheme(),
        AlUlaJaycoTheme(),
        IneosTheme(),
        // Historic Teams
        SevenElevenTheme(),
        SkyTheme(),
        QuickstepTheme(),
        LaVieClairetheme(),
        // Current Teams
        EFEducationTheme(),
        LidlTrekTheme(),
        UnoXTheme(),
        NSNTheme(),
        FDJSuezTheme(),
        // Countries
        FranceTheme(),
        USATheme(),
        ItalyTheme(),
        DenmarkTheme(),
        SlovakiaTheme(),
        NetherlandsTheme(),
        BelgiumTheme(),
        UKTheme(),
        AustraliaTheme(),
        MexicoTheme()
    ]

    private var defaultTheme: Theme {
        allThemesSnapshot().first { $0.name == ThemePreferences.defaultThemeName } ?? CyclismoTheme()
    }

    init() {
        customThemeDefinitions = ThemePreferences.decodeThemes(from: ThemePreferences.customThemesData())
        // Initialize without touching instance members before all stored properties are set.
        currentTheme = AlUlaJaycoTheme()
        let savedThemeName = ThemePreferences.selectedThemeName()
        currentTheme = allThemesSnapshot().first { $0.name == savedThemeName } ?? defaultTheme
    }

    func getTheme(named name: String) -> Theme? {
        allThemesSnapshot().first { $0.name == name }
    }

    func getAllThemes() -> [Theme] {
        allThemesSnapshot()
    }

    func setTheme(_ theme: Theme) {
        currentTheme = theme
    }

    func makeAdaptedPalette(from highlight: SwiftUI.Color) -> ThemeAdaptedPalette {
        .from(highlight: highlight)
    }

    func createOrUpdateCustomTheme(
        existingID: UUID?,
        name: String,
        fontStyle: ThemeFontStyle,
        accent: SwiftUI.Color,
        secondaryAccent: SwiftUI.Color,
        darkModeHeadlineColor: SwiftUI.Color,
        lightModeHeadlineColor: SwiftUI.Color,
        darkModeBackground: SwiftUI.Color,
        lightModeBackground: SwiftUI.Color,
        supportsLightMode: Bool
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let builtInConflict = builtInThemes.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
        if builtInConflict && existingID == nil {
            return false
        }

        let now = Date()
        let derivedBackgroundTint = UIColor(darkModeBackground).lightened(by: 0.03).asColor()
        let definition: CustomThemeDefinition
        if let existingID, let existing = customThemeDefinitions.first(where: { $0.id == existingID }) {
            definition = CustomThemeDefinition(
                id: existing.id,
                name: trimmedName,
                fontStyle: fontStyle,
                accent: .from(accent),
                secondaryAccent: .from(secondaryAccent),
                darkModeHeadlineColor: .from(darkModeHeadlineColor),
                lightModeHeadlineColor: .from(lightModeHeadlineColor),
                backgroundTint: .from(derivedBackgroundTint),
                darkModeBackground: .from(darkModeBackground),
                lightModeBackground: .from(lightModeBackground),
                supportsLightMode: supportsLightMode,
                createdAt: existing.createdAt,
                lastUpdated: now
            )
            customThemeDefinitions.removeAll { $0.id == existingID }
        } else if let existingByName = customThemeDefinitions.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            definition = CustomThemeDefinition(
                id: existingByName.id,
                name: trimmedName,
                fontStyle: fontStyle,
                accent: .from(accent),
                secondaryAccent: .from(secondaryAccent),
                darkModeHeadlineColor: .from(darkModeHeadlineColor),
                lightModeHeadlineColor: .from(lightModeHeadlineColor),
                backgroundTint: .from(derivedBackgroundTint),
                darkModeBackground: .from(darkModeBackground),
                lightModeBackground: .from(lightModeBackground),
                supportsLightMode: supportsLightMode,
                createdAt: existingByName.createdAt,
                lastUpdated: now
            )
            customThemeDefinitions.removeAll { $0.id == existingByName.id }
        } else {
            definition = CustomThemeDefinition(
                name: trimmedName,
                fontStyle: fontStyle,
                accent: .from(accent),
                secondaryAccent: .from(secondaryAccent),
                darkModeHeadlineColor: .from(darkModeHeadlineColor),
                lightModeHeadlineColor: .from(lightModeHeadlineColor),
                backgroundTint: .from(derivedBackgroundTint),
                darkModeBackground: .from(darkModeBackground),
                lightModeBackground: .from(lightModeBackground),
                supportsLightMode: supportsLightMode,
                createdAt: now,
                lastUpdated: now
            )
        }

        customThemeDefinitions.append(definition)
        customThemeDefinitions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistCustomThemes()
        currentTheme = CustomTheme(definition: definition)
        return true
    }

    func deleteCustomTheme(id: UUID) {
        guard let index = customThemeDefinitions.firstIndex(where: { $0.id == id }) else { return }
        let removed = customThemeDefinitions.remove(at: index)
        persistCustomThemes()
        if currentTheme.name.caseInsensitiveCompare(removed.name) == .orderedSame {
            currentTheme = defaultTheme
        }
    }

    func currentThemeFontStyle() -> ThemeFontStyle {
        currentThemeHeadlineFontStyle()
    }

    func currentThemeHeadlineFontStyle() -> ThemeFontStyle {
        if let customTheme = currentTheme as? CustomTheme {
            return customTheme.definition.fontStyle
        }
        switch currentTheme.name {
        case "Alpecin-Deceuninck":
            return .monospaced
        case "Red Bull-BORA-hansgrohe", "AlUla Jayco", "La Vie Claire", "EF Education-EasyPost", "Mexico":
            return .rounded
        case "Visma | Lease a Bike", "Team Sky":
            return .condensed
        case "France", "Italy", "United Kingdom":
            return .serif
        default:
            return .system
        }
    }

    func currentThemeBodyFontStyle() -> ThemeFontStyle {
        if let customTheme = currentTheme as? CustomTheme {
            return customTheme.definition.fontStyle
        }
        return .system
    }

    func restoreThemesFromCloudKitIfNeeded() async {
        if !customThemeDefinitions.isEmpty {
            return
        }
        let status = await ICloudSyncManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await ICloudSyncManager.shared.fetchUserThemePreferencesPayload() else {
                return
            }
            applyThemePayload(payload)
            hasRestoredThemesThisSession = true
        } catch {
            print("⚠️ Failed to fetch theme preferences from iCloud: \(error)")
        }
    }

    func syncThemesFromCloudKitIfNewer() async {
        let status = await ICloudSyncManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await ICloudSyncManager.shared.fetchUserThemePreferencesPayload() else {
                return
            }
            guard payload.lastUpdated > ThemePreferences.lastUpdated() else { return }
            applyThemePayload(payload)
        } catch {
            print("⚠️ Failed to sync theme preferences from iCloud: \(error)")
        }
    }

    func pushLocalThemesToCloudKitIfNeeded() async {
        guard !hasPushedThemesThisSession else {
            return
        }
        let status = await ICloudSyncManager.shared.accountStatus()
        guard status == .available else { return }

        let themesData = ThemePreferences.encodeThemes(customThemeDefinitions)
        var lastUpdated = ThemePreferences.lastUpdated()
        if lastUpdated == Date.distantPast {
            lastUpdated = Date()
            ThemePreferences.updateLastUpdated(lastUpdated)
        }

        let payload = ICloudSyncManager.UserThemePreferencesPayload(
            customThemesData: themesData,
            selectedThemeName: currentTheme.name,
            lastUpdated: lastUpdated
        )
        hasPushedThemesThisSession = true
        await ICloudSyncManager.shared.saveUserThemePreferencesPayload(payload)
    }

    private func allThemesSnapshot() -> [Theme] {
        builtInThemes + customThemeDefinitions.map { CustomTheme(definition: $0) as Theme }
    }

    private func persistCustomThemes() {
        let data = ThemePreferences.encodeThemes(customThemeDefinitions)
        UserDefaults.standard.set(data, forKey: ThemePreferences.customThemesStorageKey)
        ThemePreferences.updateLastUpdated()
        hasPushedThemesThisSession = false
        scheduleThemesPushToCloudKit()
    }

    private func scheduleThemesPushToCloudKit() {
        pendingPushTask?.cancel()
        pendingPushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await self?.pushLocalThemesToCloudKitIfNeeded()
        }
    }

    private func applyThemePayload(_ payload: ICloudSyncManager.UserThemePreferencesPayload) {
        let decoded = ThemePreferences.decodeThemes(from: payload.customThemesData)
        customThemeDefinitions = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        UserDefaults.standard.set(payload.customThemesData, forKey: ThemePreferences.customThemesStorageKey)
        ThemePreferences.setSelectedThemeName(payload.selectedThemeName)
        ThemePreferences.updateLastUpdated(payload.lastUpdated)
        if let matchedTheme = getTheme(named: payload.selectedThemeName) {
            currentTheme = matchedTheme
        } else {
            currentTheme = defaultTheme
        }
        hasPushedThemesThisSession = true
    }
}

// ThemeFontResolver and UIColor theme extensions provided by MinAppKit

// MARK: - Font Override Support

import SwiftUI
import UIKit

enum RotinaWeight: String, Codable, CaseIterable {
    case extraThin = "Rotina-ExtraThin"
    case thin = "Rotina-Thin"
    case extraLight = "Rotina-ExtraLight"
    case light = "Rotina-Light"
    case regular = "Rotina-Regular"
    case medium = "Rotina-Medium"
    case bold = "Rotina-Bold"
    case extraBold = "Rotina-ExtraBold"
    
    var weight: Font.Weight {
        switch self {
        case .extraThin: return .ultraLight
        case .thin: return .thin
        case .extraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
    
    var uiWeight: UIFont.Weight {
        switch self {
        case .extraThin: return .ultraLight
        case .thin: return .thin
        case .extraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
    
    var displayName: String {
        rawValue.replacingOccurrences(of: "Rotina-", with: "")
    }
}

enum FontTier: String, CaseIterable, Codable {
    case display    // H1, H2 - largest headings
    case heading    // H3-H6 - section headings
    case body       // Paragraphs, body text
    case ui         // Buttons, labels, controls
    case caption    // Small text, metadata
    
    var defaultRotinaWeight: RotinaWeight {
        switch self {
        case .display: return .bold
        case .heading: return .medium
        case .body: return .regular
        case .ui: return .medium
        case .caption: return .regular
        }
    }
    
    var displayName: String {
        switch self {
        case .display: return "Display"
        case .heading: return "Heading"
        case .body: return "Body"
        case .ui: return "UI"
        case .caption: return "Caption"
        }
    }
    
    var description: String {
        switch self {
        case .display: return "Large headings (H1, H2)"
        case .heading: return "Section headings (H3-H6)"
        case .body: return "Paragraphs and body text"
        case .ui: return "Buttons, labels, and controls"
        case .caption: return "Small text and captions"
        }
    }
}

struct FontOverrideSettings: Codable {
    var enabled: Bool = false
    var displayWeight: RotinaWeight = .bold
    var headingWeight: RotinaWeight = .medium
    var bodyWeight: RotinaWeight = .regular
    var uiWeight: RotinaWeight = .medium
    var captionWeight: RotinaWeight = .regular
    
    func weight(for tier: FontTier) -> RotinaWeight {
        switch tier {
        case .display: return displayWeight
        case .heading: return headingWeight
        case .body: return bodyWeight
        case .ui: return uiWeight
        case .caption: return captionWeight
        }
    }
    
    mutating func setWeight(_ weight: RotinaWeight, for tier: FontTier) {
        switch tier {
        case .display: displayWeight = weight
        case .heading: headingWeight = weight
        case .body: bodyWeight = weight
        case .ui: uiWeight = weight
        case .caption: captionWeight = weight
        }
    }
}

// Add these to your ThemeManager class:
extension ThemeManager {
    
    @AppStorage("fontOverrideEnabled") var fontOverrideEnabled: Bool = false
    
    private var fontOverrideSettingsData: Data? {
        get { UserDefaults.standard.data(forKey: "fontOverrideSettings") }
        set { UserDefaults.standard.set(newValue, forKey: "fontOverrideSettings") }
    }
    
    var fontOverrideSettings: FontOverrideSettings {
        get {
            guard let data = fontOverrideSettingsData,
                  let settings = try? JSONDecoder().decode(FontOverrideSettings.self, from: data) else {
                return FontOverrideSettings()
            }
            return settings
        }
        set {
            fontOverrideSettingsData = try? JSONEncoder().encode(newValue)
            objectWillChange.send()
        }
    }
    
    // Get custom font for a specific tier
    func customFont(_ tier: FontTier, size: CGFloat) -> Font {
        if fontOverrideEnabled {
            let weight = fontOverrideSettings.weight(for: tier)
            return .custom(weight.rawValue, size: size)
        }
        // Fallback to system font with appropriate weight
        return .system(size: size, weight: fontOverrideSettings.weight(for: tier).weight)
    }
    
    // Get custom UIFont for a specific tier
    func customUIFont(_ tier: FontTier, size: CGFloat) -> UIFont {
        if fontOverrideEnabled {
            let weight = fontOverrideSettings.weight(for: tier)
            if let font = UIFont(name: weight.rawValue, size: size) {
                return font
            }
        }
        // Fallback to system font
        return UIFont.systemFont(ofSize: size, weight: fontOverrideSettings.weight(for: tier).uiWeight)
    }
    
    // Verify fonts are loaded (useful for debugging)
    func verifyRotinaFontsLoaded() {
        let rotinaFonts = UIFont.fontNames(forFamilyName: "Rotina")
        if rotinaFonts.isEmpty {
            print("⚠️ WARNING: Rotina fonts not found!")
        } else {
            print("✅ Rotina fonts loaded successfully:")
            rotinaFonts.forEach { print("  - \($0)") }
        }
    }
}
