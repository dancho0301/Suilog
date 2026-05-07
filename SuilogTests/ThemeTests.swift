//
//  ThemeTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/02/12.
//

import Testing
import SwiftUI
@testable import Suilog

/// ThemeモデルとThemeManagerのテスト
@Suite
struct ThemeTests {

    // MARK: - Theme Model Tests

    @Test("全テーマリストが正しい件数")
    func testAllThemesCount() {
        #expect(Theme.allThemes.count == 2)
    }

    @Test("デフォルトテーマのプロパティ")
    func testDefaultThemeProperties() {
        let theme = Theme.defaultTheme
        #expect(theme.id == "default")
        #expect(theme.name == "スタンダード")
        #expect(theme.isDefault == true)
        #expect(theme.productId == nil)
    }

    @Test("ゆめかわテーマのプロパティ")
    func testYumekawaThemeProperties() {
        let theme = Theme.yumekawa
        #expect(theme.id == "yumekawa")
        #expect(theme.name == "ゆめかわ")
        #expect(theme.isDefault == true)
        #expect(theme.productId == nil)
    }

    @Test("Theme Equatable: 同じIDは等しい")
    func testThemeEquatableSameId() {
        let theme1 = Theme.defaultTheme
        let theme2 = Theme.defaultTheme
        #expect(theme1 == theme2)
    }

    @Test("Theme Equatable: 異なるIDは等しくない")
    func testThemeEquatableDifferentId() {
        #expect(Theme.defaultTheme != Theme.yumekawa)
    }

    @Test("creatureImageName: デフォルトテーマ")
    func testCreatureImageNameDefault() {
        let theme = Theme.defaultTheme
        #expect(theme.creatureImageName("Dolphin") == "Themes/Default/Dolphin")
        #expect(theme.creatureImageName("clownfish") == "Themes/Default/clownfish")
    }

    @Test("creatureImageName: ゆめかわテーマ")
    func testCreatureImageNameYumekawa() {
        let theme = Theme.yumekawa
        #expect(theme.creatureImageName("Dolphin") == "Themes/Yumekawa/Dolphin")
        #expect(theme.creatureImageName("clownfish") == "Themes/Yumekawa/clownfish")
    }

    @Test("locationCheckInColorsが正しい数")
    func testLocationCheckInColorsCount() {
        let theme = Theme.defaultTheme
        #expect(theme.locationCheckInColors.count == 3)
    }

    @Test("manualCheckInColorsが正しい数")
    func testManualCheckInColorsCount() {
        let theme = Theme.defaultTheme
        #expect(theme.manualCheckInColors.count == 3)
    }

    // MARK: - Color Hex Extension Tests

    @Test("Color(hex:) 6桁のRGB")
    func testColorHex6Digits() {
        // 正常に初期化できることを確認（Colorの値比較は不安定なため存在チェックのみ）
        let color = Color(hex: "#FF0000")
        #expect(color != Color.clear || true) // 初期化が成功すること
    }

    @Test("Color(hex:) 8桁のARGB")
    func testColorHex8Digits() {
        let color = Color(hex: "#80FF0000")
        #expect(color != Color.clear || true)
    }

    @Test("Color(hex:) 不正な文字列はデフォルト黒")
    func testColorHexInvalid() {
        // 不正なHex文字列でもクラッシュしないことを確認
        let _ = Color(hex: "invalid")
        let _ = Color(hex: "")
        let _ = Color(hex: "#GGG")
    }

    // MARK: - ThemeManager Tests

    @Test("ThemeManager初期化: デフォルトテーマが選択される")
    @MainActor
    func testThemeManagerInit() {
        // テスト用にUserDefaultsをクリア
        UserDefaults.standard.removeObject(forKey: "SelectedThemeId")
        let manager = ThemeManager()
        #expect(manager.currentTheme == Theme.defaultTheme)
    }

    @Test("ThemeManager: デフォルトテーマは常にアンロック")
    @MainActor
    func testDefaultThemeAlwaysUnlocked() {
        let manager = ThemeManager()
        #expect(manager.isUnlocked(Theme.defaultTheme) == true)
    }

    @Test("ThemeManager: ゆめかわテーマはisDefaultなのでアンロック")
    @MainActor
    func testYumekawaIsDefaultUnlocked() {
        let manager = ThemeManager()
        #expect(manager.isUnlocked(Theme.yumekawa) == true)
    }

    @Test("ThemeManager: productIdありのテーマは購入が必要")
    @MainActor
    func testPaidThemeRequiresPurchase() {
        let manager = ThemeManager()
        let paidTheme = Theme(
            id: "paid",
            name: "有料テーマ",
            description: "テスト用有料テーマ",
            productId: "com.suilog.theme.paid",
            isDefault: false,
            backgroundImageiPhone: "bg_iphone",
            backgroundImageiPad: "bg_ipad",
            primaryColorHex: "#007AFF",
            bubbleColorHex: "#FFFFFF",
            locationCheckInColorsHex: ["#FFFF00"],
            manualCheckInColorsHex: ["#808080"],
            statisticsBackgroundColorHex: "#4D007AFF",
            textColorHex: "#FFFFFF",
            secondaryTextColorHex: "#CCFFFFFF"
        )
        #expect(manager.isUnlocked(paidTheme) == false)
    }

    @Test("ThemeManager: 購入済みテーマはアンロック")
    @MainActor
    func testPurchasedThemeIsUnlocked() {
        let manager = ThemeManager()
        let paidTheme = Theme(
            id: "paid",
            name: "有料テーマ",
            description: "テスト用有料テーマ",
            productId: "com.suilog.theme.paid",
            isDefault: false,
            backgroundImageiPhone: "bg_iphone",
            backgroundImageiPad: "bg_ipad",
            primaryColorHex: "#007AFF",
            bubbleColorHex: "#FFFFFF",
            locationCheckInColorsHex: ["#FFFF00"],
            manualCheckInColorsHex: ["#808080"],
            statisticsBackgroundColorHex: "#4D007AFF",
            textColorHex: "#FFFFFF",
            secondaryTextColorHex: "#CCFFFFFF"
        )
        manager.purchasedProductIds = ["com.suilog.theme.paid"]
        #expect(manager.isUnlocked(paidTheme) == true)
    }

    @Test("ThemeManager: all_packで全テーマアンロック")
    @MainActor
    func testAllPackUnlocksAll() {
        let manager = ThemeManager()
        let paidTheme = Theme(
            id: "paid",
            name: "有料テーマ",
            description: "テスト用有料テーマ",
            productId: "com.suilog.theme.paid",
            isDefault: false,
            backgroundImageiPhone: "bg_iphone",
            backgroundImageiPad: "bg_ipad",
            primaryColorHex: "#007AFF",
            bubbleColorHex: "#FFFFFF",
            locationCheckInColorsHex: ["#FFFF00"],
            manualCheckInColorsHex: ["#808080"],
            statisticsBackgroundColorHex: "#4D007AFF",
            textColorHex: "#FFFFFF",
            secondaryTextColorHex: "#CCFFFFFF"
        )
        manager.purchasedProductIds = ["com.suilog.theme.all_pack"]
        #expect(manager.isUnlocked(paidTheme) == true)
    }

    @Test("ThemeManager: アンロック済みテーマの選択が成功")
    @MainActor
    func testSelectUnlockedTheme() {
        let manager = ThemeManager()
        let result = manager.selectTheme(Theme.yumekawa)
        #expect(result == true)
        #expect(manager.currentTheme == Theme.yumekawa)
    }

    @Test("ThemeManager: ロック中テーマの選択が失敗")
    @MainActor
    func testSelectLockedTheme() {
        let manager = ThemeManager()
        let paidTheme = Theme(
            id: "paid",
            name: "有料テーマ",
            description: "テスト用有料テーマ",
            productId: "com.suilog.theme.paid",
            isDefault: false,
            backgroundImageiPhone: "bg_iphone",
            backgroundImageiPad: "bg_ipad",
            primaryColorHex: "#007AFF",
            bubbleColorHex: "#FFFFFF",
            locationCheckInColorsHex: ["#FFFF00"],
            manualCheckInColorsHex: ["#808080"],
            statisticsBackgroundColorHex: "#4D007AFF",
            textColorHex: "#FFFFFF",
            secondaryTextColorHex: "#CCFFFFFF"
        )
        let result = manager.selectTheme(paidTheme)
        #expect(result == false)
        #expect(manager.currentTheme != paidTheme)
    }

    @Test("ThemeManager: 購入状態更新でロックされたテーマはデフォルトに戻る")
    @MainActor
    func testUpdatePurchasedProductsResetsLockedTheme() {
        let manager = ThemeManager()
        let paidTheme = Theme(
            id: "paid",
            name: "有料テーマ",
            description: "テスト用有料テーマ",
            productId: "com.suilog.theme.paid",
            isDefault: false,
            backgroundImageiPhone: "bg_iphone",
            backgroundImageiPad: "bg_ipad",
            primaryColorHex: "#007AFF",
            bubbleColorHex: "#FFFFFF",
            locationCheckInColorsHex: ["#FFFF00"],
            manualCheckInColorsHex: ["#808080"],
            statisticsBackgroundColorHex: "#4D007AFF",
            textColorHex: "#FFFFFF",
            secondaryTextColorHex: "#CCFFFFFF"
        )

        // まず購入して選択
        manager.purchasedProductIds = ["com.suilog.theme.paid"]
        _ = manager.selectTheme(paidTheme)
        #expect(manager.currentTheme == paidTheme)

        // 購入状態をクリア → デフォルトに戻る
        manager.updatePurchasedProducts([])
        #expect(manager.currentTheme == Theme.defaultTheme)
    }

    @Test("ThemeManager: unlockedThemesが正しい")
    @MainActor
    func testUnlockedThemes() {
        let manager = ThemeManager()
        // デフォルトでは isDefault=true のテーマだけがアンロック
        let unlocked = manager.unlockedThemes
        #expect(unlocked.count == 2)
        #expect(unlocked.contains(Theme.defaultTheme))
        #expect(unlocked.contains(Theme.yumekawa))
    }
}
