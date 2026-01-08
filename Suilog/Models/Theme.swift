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

    /// デバイスに応じた背景画像名を返す
    var backgroundImageName: String {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? backgroundImageiPad : backgroundImageiPhone
    }

    // MARK: - Equatable

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Default Themes

extension Theme {
    /// デフォルトテーマ（無料）
    static let defaultTheme = Theme(
        id: "default",
        name: "スタンダード",
        description: "青い海をイメージした基本テーマ",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "background_iphone",
        backgroundImageiPad: "background_ipad",
        primaryColorHex: "#007AFF",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFFF00", "#FFA500", "#FFD700"],  // yellow, orange, gold
        manualCheckInColorsHex: ["#808080", "#BFBFBF", "#D9D9D9"],    // gray shades
        statisticsBackgroundColorHex: "#007AFF4D"  // blue with 0.3 opacity
    )

    /// サンゴ礁テーマ
    static let coralReef = Theme(
        id: "coral_reef",
        name: "サンゴ礁",
        description: "カラフルなサンゴ礁の世界",
        productId: "com.suilog.theme.coral_reef",
        isDefault: false,
        backgroundImageiPhone: "background_coral_reef_iphone",
        backgroundImageiPad: "background_coral_reef_ipad",
        primaryColorHex: "#FF6B9D",
        bubbleColorHex: "#FFE4EC",
        locationCheckInColorsHex: ["#FF6B9D", "#FF8FB3", "#FFB3C9"],  // coral pink shades
        manualCheckInColorsHex: ["#9DDCDC", "#B8E8E8", "#D4F4F4"],    // turquoise shades
        statisticsBackgroundColorHex: "#FF6B9D4D"
    )

    /// 深海テーマ
    static let deepSea = Theme(
        id: "deep_sea",
        name: "深海",
        description: "神秘的な深海の世界",
        productId: "com.suilog.theme.deep_sea",
        isDefault: false,
        backgroundImageiPhone: "background_deep_sea_iphone",
        backgroundImageiPad: "background_deep_sea_ipad",
        primaryColorHex: "#1A237E",
        bubbleColorHex: "#82B1FF",
        locationCheckInColorsHex: ["#00E5FF", "#18FFFF", "#84FFFF"],  // bioluminescent cyan
        manualCheckInColorsHex: ["#7C4DFF", "#B388FF", "#D1C4E9"],    // purple shades
        statisticsBackgroundColorHex: "#1A237E4D"
    )

    /// トロピカルテーマ
    static let tropical = Theme(
        id: "tropical",
        name: "トロピカル",
        description: "南国の透き通る海",
        productId: "com.suilog.theme.tropical",
        isDefault: false,
        backgroundImageiPhone: "background_tropical_iphone",
        backgroundImageiPad: "background_tropical_ipad",
        primaryColorHex: "#00BFA5",
        bubbleColorHex: "#E0F7FA",
        locationCheckInColorsHex: ["#FFD54F", "#FFCA28", "#FFC107"],  // tropical yellow
        manualCheckInColorsHex: ["#4DD0E1", "#80DEEA", "#B2EBF2"],    // aqua shades
        statisticsBackgroundColorHex: "#00BFA54D"
    )

    /// 全テーマのリスト
    static let allThemes: [Theme] = [
        .defaultTheme,
        .coralReef,
        .deepSea,
        .tropical
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
