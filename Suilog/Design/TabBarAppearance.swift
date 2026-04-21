//
//  TabBarAppearance.swift
//  Suilog
//
//  デザイン仕様に沿ったタブバー外観の設定。
//  - 背景: rgba(255,255,255,0.92) + blur(16px)
//  - 上ボーダー: 0.5px solid rgba(0,0,0,0.08)
//  - アクティブ: primary色
//  - 非アクティブ: #C0C0CC / rgba(60,60,67,0.5)
//  - ラベル: 10pt / semibold
//

import SwiftUI
import UIKit

enum TabBarAppearance {
    @MainActor
    static func apply(primary: Color) {
        let primaryUI = UIColor(primary)
        let inactiveIcon = UIColor(red: 0xC0 / 255, green: 0xC0 / 255, blue: 0xCC / 255, alpha: 1)
        let inactiveText = UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.5)
        let topBorder = UIColor(red: 0, green: 0, blue: 0, alpha: 0.08)
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .semibold)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        appearance.shadowColor = topBorder

        configureItem(
            appearance.stackedLayoutAppearance,
            active: primaryUI,
            inactiveIcon: inactiveIcon,
            inactiveText: inactiveText,
            labelFont: labelFont
        )
        configureItem(
            appearance.inlineLayoutAppearance,
            active: primaryUI,
            inactiveIcon: inactiveIcon,
            inactiveText: inactiveText,
            labelFont: labelFont
        )
        configureItem(
            appearance.compactInlineLayoutAppearance,
            active: primaryUI,
            inactiveIcon: inactiveIcon,
            inactiveText: inactiveText,
            labelFont: labelFont
        )

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @MainActor
    private static func configureItem(
        _ item: UITabBarItemAppearance,
        active: UIColor,
        inactiveIcon: UIColor,
        inactiveText: UIColor,
        labelFont: UIFont
    ) {
        item.normal.iconColor = inactiveIcon
        item.normal.titleTextAttributes = [
            .foregroundColor: inactiveText,
            .font: labelFont
        ]
        item.selected.iconColor = active
        item.selected.titleTextAttributes = [
            .foregroundColor: active,
            .font: labelFont
        ]
    }
}
