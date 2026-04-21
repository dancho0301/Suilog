//
//  DesignTokens.swift
//  Suilog
//
//  デザイン仕様に基づくカラー/スペース/タイポ/シャドウのトークン定義。
//

import SwiftUI

enum SuiColor {
    static let heading = Color(hex: "#1A3040")
    static let subText = Color(hex: "#AABBC4")
    static let midText = Color(hex: "#5A7888")
    static let divider = Color(hex: "#F0F4F7")
    static let star = Color(hex: "#F5B942")

    static let goldBg = Color(hex: "#FFF8E6")
    static let goldBorder = Color(hex: "#F5C842")
    static let goldText = Color(hex: "#B8860B")

    static let silverBg = Color(hex: "#F4F4F4")
    static let silverBorder = Color(hex: "#CFD8DC")
    static let silverText = Color(hex: "#7A90A0")

    static let cardSurface = Color.white
    static let fieldBg = Color(hex: "#F8FAFB")
    static let fieldBorder = Color(hex: "#E8EEF2")
    static let tabInactive = Color(hex: "#C0C0CC")
}

enum SuiSpacing {
    static let screenHorizontal: CGFloat = 20
    static let cardGap: CGFloat = 12
    static let statusBarTop: CGFloat = 58
}

enum SuiRadius {
    static let cardLarge: CGFloat = 20
    static let cardMedium: CGFloat = 18
    static let cardSmall: CGFloat = 14
    static let pill: CGFloat = 20
    static let button: CGFloat = 16
}

enum SuiFont {
    static let screenTitle = Font.system(size: 26, weight: .heavy)
    static let heading = Font.system(size: 20, weight: .bold)
    static let section = Font.system(size: 17, weight: .bold)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .semibold)
    static let label = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let tinyLabel = Font.system(size: 11, weight: .bold)
    static let stat = Font.system(size: 24, weight: .heavy)
}

struct SuiShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = SuiShadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)

    static func cardEmphasized(primary: Color) -> SuiShadow {
        SuiShadow(color: primary.opacity(0.19), radius: 24, x: 0, y: 8)
    }

    static func primaryButton(primary: Color) -> SuiShadow {
        SuiShadow(color: primary.opacity(0.31), radius: 20, x: 0, y: 6)
    }
}

extension View {
    func suiShadow(_ shadow: SuiShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
