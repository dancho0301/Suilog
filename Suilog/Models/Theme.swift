//
//  Theme.swift
//  Suilog
//
//  Created by dancho on 2025/01/07.
//

import SwiftUI

/// テーマデータモデル
/// 水槽の背景や魚の色などをカスタマイズするためのテーマ
struct Theme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let productId: String?          // App Store Connect の Product ID（nil = 無料）
    let isDefault: Bool             // デフォルトテーマかどうか

    // アセット名
    let backgroundImageiPhone: String
    let backgroundImageiPad: String

    // 色テーマ（Codable対応のためHexで保存）
    let primaryColorHex: String
    let bubbleColorHex: String
    let locationCheckInColorsHex: [String]   // ゴールド系
    let manualCheckInColorsHex: [String]     // シルバー系
    let statisticsBackgroundColorHex: String
    let textColorHex: String                  // メインテキスト色
    let secondaryTextColorHex: String         // サブテキスト色

    // リデザイン用トークン（全て任意。未指定時はprimaryColorHexから派生したフォールバック値を使用）
    let primaryDarkHex: String?
    let primaryLightHex: String?
    let primaryBgHex: String?
    let accentHex: String?
    let tankTopHex: String?
    let tankBottomHex: String?

    // MARK: - Color Computed Properties

    var primaryColor: Color {
        Color(hex: primaryColorHex)
    }

    var bubbleColor: Color {
        Color(hex: bubbleColorHex)
    }

    var locationCheckInColors: [Color] {
        locationCheckInColorsHex.map { Color(hex: $0) }
    }

    var manualCheckInColors: [Color] {
        manualCheckInColorsHex.map { Color(hex: $0) }
    }

    var statisticsBackgroundColor: Color {
        Color(hex: statisticsBackgroundColorHex)
    }

    var textColor: Color {
        Color(hex: textColorHex)
    }

    var secondaryTextColor: Color {
        Color(hex: secondaryTextColorHex)
    }

    // MARK: - リデザイン用カラー（フォールバック付き）

    var primaryDark: Color {
        Color(hex: primaryDarkHex ?? primaryColorHex)
    }

    var primaryLight: Color {
        Color(hex: primaryLightHex ?? primaryColorHex)
    }

    /// リデザインの画面全体背景色。未指定テーマは明るい水色 (#EEF7FF)。
    var primaryBg: Color {
        Color(hex: primaryBgHex ?? "#EEF7FF")
    }

    var accent: Color {
        Color(hex: accentHex ?? "#FF8F6B")
    }

    var tankTop: Color {
        Color(hex: tankTopHex ?? "#A8D8EF")
    }

    var tankBottom: Color {
        Color(hex: tankBottomHex ?? "#6BBBD8")
    }

    /// デバイスに応じた背景画像名を返す
    var backgroundImageName: String {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? backgroundImageiPad : backgroundImageiPhone
    }

    /// テーマに応じた生き物の画像名を返す
    /// - Parameter creatureName: 生き物の名前（例: "Dolphin", "clownfish"）
    /// - Returns: テーマフォルダを含む画像名（例: "Themes/Default/Dolphin"）
    func creatureImageName(_ creatureName: String) -> String {
        // デフォルトテーマの場合
        if id == "default" {
            return "Themes/Default/\(creatureName)"
        }
        // ゆめかわテーマの場合
        else if id == "yumekawa" {
            return "Themes/Yumekawa/\(creatureName)"
        }
        // 16ビットテーマの場合
        else if id == "16bit" {
            return "Themes/16bit/\(creatureName)"
        }
        // その他のテーマ（フォールバック）
        return "Themes/Default/\(creatureName)"
    }

    // MARK: - Equatable

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Default Themes

extension Theme {
    /// オーシャンブルー（デフォルト・無料）
    /// デザイン仕様のデフォルトテーマ。
    static let defaultTheme = Theme(
        id: "default",
        name: "オーシャンブルー",
        description: "明るい水色ベースの基本テーマ",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "Themes/Default/background_iphone",
        backgroundImageiPad: "Themes/Default/background_ipad",
        primaryColorHex: "#3FA8CB",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFD700", "#FFA500", "#F5C842"],
        manualCheckInColorsHex: ["#CFD8DC", "#BFBFBF", "#D9D9D9"],
        statisticsBackgroundColorHex: "#FFFFFFFF",
        textColorHex: "#1A3040",
        secondaryTextColorHex: "#AABBC4",
        primaryDarkHex: "#2C87A8",
        primaryLightHex: "#B8DFEF",
        primaryBgHex: "#EEF7FF",
        accentHex: "#FF8F6B",
        tankTopHex: "#A8D8EF",
        tankBottomHex: "#6BBBD8"
    )

    /// フレッシュミント（無料）
    static let mint = Theme(
        id: "mint",
        name: "フレッシュミント",
        description: "みずみずしいグリーン基調のテーマ",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "Themes/Default/background_iphone",
        backgroundImageiPad: "Themes/Default/background_ipad",
        primaryColorHex: "#3CAF88",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFD700", "#FFA500", "#F5C842"],
        manualCheckInColorsHex: ["#CFD8DC", "#BFBFBF", "#D9D9D9"],
        statisticsBackgroundColorHex: "#FFFFFFFF",
        textColorHex: "#1A3040",
        secondaryTextColorHex: "#AABBC4",
        primaryDarkHex: "#2E8C6C",
        primaryLightHex: "#A4E0C6",
        primaryBgHex: "#F0FCF6",
        accentHex: "#FFB347",
        tankTopHex: "#A4E0C6",
        tankBottomHex: "#5CC49A"
    )

    /// サンセットコーラル（無料）
    static let coral = Theme(
        id: "coral",
        name: "サンセットコーラル",
        description: "夕焼けを思わせる暖色テーマ",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "Themes/Default/background_iphone",
        backgroundImageiPad: "Themes/Default/background_ipad",
        primaryColorHex: "#E06B5A",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFD700", "#FFA500", "#F5C842"],
        manualCheckInColorsHex: ["#CFD8DC", "#BFBFBF", "#D9D9D9"],
        statisticsBackgroundColorHex: "#FFFFFFFF",
        textColorHex: "#1A3040",
        secondaryTextColorHex: "#AABBC4",
        primaryDarkHex: "#C0523F",
        primaryLightHex: "#F5BDB4",
        primaryBgHex: "#FFF5F3",
        accentHex: "#4BA8CB",
        tankTopHex: "#F5BDB4",
        tankBottomHex: "#E8806F"
    )

    /// ゆめかわテーマ（無料・既存継続）
    static let yumekawa = Theme(
        id: "yumekawa",
        name: "ゆめかわ",
        description: "パステルカラーの夢かわいい世界",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "Themes/Yumekawa/background_iphone",
        backgroundImageiPad: "Themes/Yumekawa/background_ipad",
        primaryColorHex: "#9B4B9B",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFD6E8", "#FFADD6", "#FF85C8"],
        manualCheckInColorsHex: ["#D6E8FF", "#ADD6FF", "#85C8FF"],
        statisticsBackgroundColorHex: "#99FFFFFF",
        textColorHex: "#6B3A6B",
        secondaryTextColorHex: "#CC6B3A6B",
        primaryDarkHex: "#7A3A7A",
        primaryLightHex: "#E8C7E8",
        primaryBgHex: "#FFF0FA",
        accentHex: "#FFB347",
        tankTopHex: "#FFD6E8",
        tankBottomHex: "#FF85C8"
    )

    /// 16ビットテーマ（無料）
    static let sixteenBit = Theme(
        id: "16bit",
        name: "16ビット",
        description: "レトロゲーム風の明るい水槽テーマ",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "Themes/16bit/background_iphone",
        backgroundImageiPad: "Themes/16bit/background_ipad",
        primaryColorHex: "#2A6496",
        bubbleColorHex: "#DFF8FF",
        locationCheckInColorsHex: ["#FFE066", "#FFB84D", "#FFD43B"],
        manualCheckInColorsHex: ["#B7D7E8", "#8FB9CF", "#D0EAF5"],
        statisticsBackgroundColorHex: "#EEFFFFFF",
        textColorHex: "#0A1628",
        secondaryTextColorHex: "#8AAEC8",
        primaryDarkHex: "#0A4A78",
        primaryLightHex: "#8FD3F4",
        primaryBgHex: "#EAF8FF",
        accentHex: "#FFB84D",
        tankTopHex: "#8FD3F4",
        tankBottomHex: "#2A6496"
    )

    /// 全テーマのリスト
    static let allThemes: [Theme] = [
        .defaultTheme,
        .mint,
        .coral,
        .yumekawa,
        .sixteenBit
    ]
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (with alpha)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
