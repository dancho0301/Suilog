//
//  WidgetColor.swift
//  SuilogWidget
//
//  ウィジェットは Theme を使わないので、16進数の色文字列から色を作る小さな補助。
//

import SwiftUI

extension Color {
    /// "#RRGGBB" または "#AARRGGBB" 形式から色を作る。不正な文字列は黒になる
    init(widgetHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let alpha, red, green, blue: UInt64
        switch cleaned.count {
        case 6:
            (alpha, red, green, blue) = (255, value >> 16, (value >> 8) & 0xFF, value & 0xFF)
        case 8:
            (alpha, red, green, blue) = (value >> 24, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
