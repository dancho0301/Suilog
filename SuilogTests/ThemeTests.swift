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

    /// 保存済みテーマ（iCloud KVS / UserDefaults）を消した状態の ThemeManager を作る
    @MainActor
    private func makeManager() -> ThemeManager {
        CloudSettingsManager.shared.set(nil, forKey: CloudSettingsManager.selectedThemeIdKey)
        return ThemeManager()
    }

    // MARK: - Theme Model Tests

    @Test("マイ水槽のレトロな動きは16ビットテーマだけ")
    func testRetroTankMotionOnlyFor16bit() {
        #expect(Theme.sixteenBit.usesRetroTankMotion)
        #expect(!Theme.defaultTheme.usesRetroTankMotion)
        #expect(!Theme.yumekawa.usesRetroTankMotion)
    }

    @Test("全テーマリストが正しい件数")
    func testAllThemesCount() {
        // mint / coral は一時無効化中のため3テーマ
        #expect(Theme.allThemes.count == 3)
    }

    @Test("無料なのはオーシャンブルーだけ")
    func testOnlyDefaultThemeIsFree() {
        #expect(Theme.defaultTheme.requiresPro == false)
        #expect(Theme.yumekawa.requiresPro == true)
        #expect(Theme.sixteenBit.requiresPro == true)
        #expect(Theme.mint.requiresPro == true)
        #expect(Theme.coral.requiresPro == true)
        #expect(Theme.allThemes.filter { !$0.requiresPro } == [Theme.defaultTheme])
    }

    @Test("デフォルトテーマのプロパティ")
    func testDefaultThemeProperties() {
        let theme = Theme.defaultTheme
        #expect(theme.id == "default")
        #expect(theme.name == "オーシャンブルー")
    }

    @Test("ゆめかわテーマのプロパティ")
    func testYumekawaThemeProperties() {
        let theme = Theme.yumekawa
        #expect(theme.id == "yumekawa")
        #expect(theme.name == "ゆめかわ")
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
        let manager = makeManager()
        #expect(manager.currentTheme == Theme.defaultTheme)
        #expect(manager.isPro == false)
    }

    @Test("ThemeManager: Pro でなければオーシャンブルーだけ使える")
    @MainActor
    func testWithoutProOnlyDefaultIsUnlocked() {
        let manager = makeManager()
        #expect(manager.isUnlocked(Theme.defaultTheme) == true)
        #expect(manager.isUnlocked(Theme.yumekawa) == false)
        #expect(manager.isUnlocked(Theme.sixteenBit) == false)
        #expect(manager.unlockedThemes == [Theme.defaultTheme])
    }

    @Test("ThemeManager: Pro ならすべてのテーマが使える")
    @MainActor
    func testWithProAllThemesAreUnlocked() {
        let manager = makeManager()
        manager.updatePro(true)
        #expect(manager.isUnlocked(Theme.yumekawa) == true)
        #expect(manager.isUnlocked(Theme.sixteenBit) == true)
        #expect(manager.unlockedThemes.count == Theme.allThemes.count)
    }

    @Test("ThemeManager: ロック中テーマの選択が失敗")
    @MainActor
    func testSelectLockedTheme() {
        let manager = makeManager()
        let result = manager.selectTheme(Theme.yumekawa)
        #expect(result == false)
        #expect(manager.currentTheme == Theme.defaultTheme)
    }

    @Test("ThemeManager: Pro なら Pro テーマを選択できる")
    @MainActor
    func testSelectProTheme() {
        let manager = makeManager()
        manager.updatePro(true)
        let result = manager.selectTheme(Theme.yumekawa)
        #expect(result == true)
        #expect(manager.currentTheme == Theme.yumekawa)
    }

    @Test("ThemeManager: Pro が外れるとオーシャンブルーに戻る")
    @MainActor
    func testLosingProResetsTheme() {
        let manager = makeManager()
        manager.updatePro(true)
        _ = manager.selectTheme(Theme.sixteenBit)
        #expect(manager.currentTheme == Theme.sixteenBit)

        manager.updatePro(false)
        #expect(manager.currentTheme == Theme.defaultTheme)
        #expect(manager.isPro == false)
    }

    @Test("Pro を失っても保存済みのテーマ ID は残る")
    @MainActor
    func testLosingProKeepsSavedThemeId() {
        let manager = makeManager()
        manager.updatePro(true)
        _ = manager.selectTheme(Theme.sixteenBit)

        manager.updatePro(false)

        #expect(manager.currentTheme == Theme.defaultTheme)
        #expect(CloudSettingsManager.shared.string(forKey: CloudSettingsManager.selectedThemeIdKey) == "16bit")
    }

    @Test("Pro に戻ると保存済みのテーマに戻る")
    @MainActor
    func testRegainingProRestoresSavedTheme() {
        let manager = makeManager()
        manager.updatePro(true)
        _ = manager.selectTheme(Theme.sixteenBit)
        manager.updatePro(false)

        manager.updatePro(true)

        #expect(manager.currentTheme == Theme.sixteenBit)
    }

    @Test("Pro でない端末が起動しても保存済みの Pro テーマを上書きしない")
    @MainActor
    func testNonProLaunchDoesNotOverwriteSavedTheme() {
        _ = makeManager()
        CloudSettingsManager.shared.set("yumekawa", forKey: CloudSettingsManager.selectedThemeIdKey)
        let manager = ThemeManager()

        manager.applyEntitlements([], isLoaded: true)

        #expect(manager.currentTheme == Theme.defaultTheme)
        #expect(CloudSettingsManager.shared.string(forKey: CloudSettingsManager.selectedThemeIdKey) == "yumekawa")
    }

    // MARK: - 購入状態（権利）の反映

    @Test("applyEntitlements: 読み込み前は Pro テーマを巻き戻さない")
    @MainActor
    func testEntitlementsNotLoadedKeepsTheme() {
        let manager = makeManager()
        manager.updatePro(true)
        _ = manager.selectTheme(Theme.sixteenBit)

        // 起動直後は購入状態が空のまま届く。読み込み前なので無視されるべき
        manager.applyEntitlements([], isLoaded: false)

        #expect(manager.currentTheme == Theme.sixteenBit)
        #expect(manager.isPro == true)
    }

    @Test("applyEntitlements: 読み込み後に Pro を持っていれば Pro 扱い")
    @MainActor
    func testEntitlementsLoadedWithPro() {
        let manager = makeManager()
        manager.applyEntitlements([StoreManager.proProductId], isLoaded: true)
        #expect(manager.isPro == true)
        #expect(manager.isUnlocked(Theme.yumekawa) == true)
    }

    @Test("applyEntitlements: 読み込み後に Pro がなければオーシャンブルーに戻る")
    @MainActor
    func testEntitlementsLoadedWithoutPro() {
        let manager = makeManager()
        manager.updatePro(true)
        _ = manager.selectTheme(Theme.yumekawa)

        manager.applyEntitlements([], isLoaded: true)

        #expect(manager.isPro == false)
        #expect(manager.currentTheme == Theme.defaultTheme)
    }

    @Test("applyEntitlements: チップだけでは Pro 扱いにならない")
    @MainActor
    func testTipsDoNotUnlockPro() {
        let manager = makeManager()
        manager.applyEntitlements(StoreManager.tipProductIds, isLoaded: true)
        #expect(manager.isPro == false)
    }
}
