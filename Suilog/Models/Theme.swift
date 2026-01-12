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
    /// デフォルトテーマ（無料）
    static let defaultTheme = Theme(
        id: "default",
        name: "スタンダード",
        description: "青い海をイメージした基本テーマ",
        productId: nil,
        isDefault: true,
        backgroundImageiPhone: "Themes/Default/background_iphone",
        backgroundImageiPad: "Themes/Default/background_ipad",
        primaryColorHex: "#007AFF",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFFF00", "#FFA500", "#FFD700"],  // yellow, orange, gold
        manualCheckInColorsHex: ["#808080", "#BFBFBF", "#D9D9D9"],    // gray shades
        statisticsBackgroundColorHex: "#4D007AFF"  // blue with 0.3 opacity (AARRGGBB format)
    )

    /// ゆめかわテーマ
    static let yumekawa = Theme(
        id: "yumekawa",
        name: "ゆめかわ",
        description: "パステルカラーの夢かわいい世界",
        productId: "com.suilog.theme.yumekawa",
        isDefault: false,
        backgroundImageiPhone: "Themes/Yumekawa/background_iphone",
        backgroundImageiPad: "Themes/Yumekawa/background_ipad",
        primaryColorHex: "#FFB3E6",
        bubbleColorHex: "#FFFFFF",
        locationCheckInColorsHex: ["#FFD6E8", "#FFADD6", "#FF85C8"],  // pastel pink shades
        manualCheckInColorsHex: ["#D6E8FF", "#ADD6FF", "#85C8FF"],    // pastel blue shades
        statisticsBackgroundColorHex: "#4DFFB3E6"  // pastel pink with 0.3 opacity (AARRGGBB format)
    )

    /// 全テーマのリスト
    static let allThemes: [Theme] = [
        .defaultTheme,
        .yumekawa
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
