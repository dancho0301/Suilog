//
//  DesignTokens.swift
//  Suilog
//
//  デザイン仕様に基づくカラー/スペース/タイポ/シャドウのトークン定義。
//

import SwiftUI
import UIKit

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
    // Dynamic Type 対応: 端末の文字サイズ設定に追従する
    static var screenTitle: Font { scaled(26, weight: .heavy, relativeTo: .title1) }
    static var heading: Font { scaled(20, weight: .bold, relativeTo: .title3) }
    static var section: Font { scaled(17, weight: .bold, relativeTo: .headline) }
    static var body: Font { scaled(15, weight: .regular, relativeTo: .body) }
    static var bodyMedium: Font { scaled(15, weight: .semibold, relativeTo: .body) }
    static var label: Font { scaled(13, weight: .regular, relativeTo: .footnote) }
    static var caption: Font { scaled(12, weight: .regular, relativeTo: .caption1) }
    static var tinyLabel: Font { scaled(11, weight: .bold, relativeTo: .caption2) }
    static var stat: Font { scaled(24, weight: .heavy, relativeTo: .title2) }

    /// デザイン上の基準サイズを、指定テキストスタイルの拡大率でスケールしたシステムフォントを返す
    /// レイアウト崩れを防ぐため、拡大率は accessibilityMedium を上限とする
    private static func scaled(_ size: CGFloat, weight: Font.Weight, relativeTo style: UIFont.TextStyle) -> Font {
        let current = UIApplication.shared.preferredContentSizeCategory
        let capped = min(current, .accessibilityMedium)
        let traits = UITraitCollection(preferredContentSizeCategory: capped)
        let scaledSize = UIFontMetrics(forTextStyle: style).scaledValue(for: size, compatibleWith: traits)
        return .system(size: scaledSize, weight: weight)
    }
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
