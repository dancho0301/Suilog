//
//  ThemeManager.swift
//  Suilog
//
//  Created by dancho on 2025/01/07.
//

import SwiftUI
import Combine

/// テーマの状態を管理するマネージャー
@MainActor
class ThemeManager: ObservableObject {
    /// 現在選択されているテーマ
    @Published var currentTheme: Theme

    /// 利用可能な全テーマ
    @Published private(set) var availableThemes: [Theme] = Theme.allThemes

    /// スイログ Pro を購入済みか（StoreManager から更新される）
    @Published private(set) var isPro = false

    private let selectedThemeKey = CloudSettingsManager.selectedThemeIdKey
    private let cloudSettings = CloudSettingsManager.shared

    init() {
        // 保存されているテーマを読み込む（iCloud KVS優先）
        if let savedThemeId = cloudSettings.string(forKey: selectedThemeKey),
           let savedTheme = Theme.allThemes.first(where: { $0.id == savedThemeId }) {
            self.currentTheme = savedTheme
        } else {
            self.currentTheme = Theme.defaultTheme
        }

        // iCloudからのテーマ変更を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudThemeChange(_:)),
            name: .cloudThemeDidChange,
            object: nil
        )
    }

    @objc private func handleCloudThemeChange(_ notification: Notification) {
        guard let themeId = notification.userInfo?["themeId"] as? String,
              let theme = Theme.allThemes.first(where: { $0.id == themeId }),
              isUnlocked(theme) else {
            return
        }
        Task { @MainActor in
            self.currentTheme = theme
        }
    }

    /// アンロック済みのテーマ一覧
    /// 無料のテーマは常に、Pro 必須のテーマは Pro 購入後に使える
    var unlockedThemes: [Theme] {
        availableThemes.filter { isUnlocked($0) }
    }

    /// テーマがアンロック済みかどうか
    func isUnlocked(_ theme: Theme) -> Bool {
        !theme.requiresPro || isPro
    }

    /// テーマを選択する
    /// - Parameter theme: 選択するテーマ
    /// - Returns: 選択に成功したかどうか
    @discardableResult
    func selectTheme(_ theme: Theme) -> Bool {
        guard isUnlocked(theme) else {
            return false
        }

        currentTheme = theme
        cloudSettings.set(theme.id, forKey: selectedThemeKey)
        return true
    }

    /// Pro の購入状態を更新する
    /// 選択中のテーマがロックされてしまう場合は、この端末だけオーシャンブルーにする
    /// （iCloud の保存値は書き換えない。Pro が戻れば保存済みのテーマに戻る）
    func updatePro(_ isPro: Bool) {
        let wasPro = self.isPro
        self.isPro = isPro

        if !isUnlocked(currentTheme) {
            currentTheme = .defaultTheme
        } else if isPro && !wasPro {
            restoreSavedTheme()
        }
    }

    /// 保存済みのテーマ ID を読み直し、アンロック済みならそのテーマにする（保存はしない）
    private func restoreSavedTheme() {
        if let savedThemeId = cloudSettings.string(forKey: selectedThemeKey),
           let savedTheme = Theme.allThemes.first(where: { $0.id == savedThemeId }),
           isUnlocked(savedTheme) {
            currentTheme = savedTheme
        }
    }

    /// StoreManager の購入状態（権利）を反映する
    /// - Parameters:
    ///   - productIds: 購入済みの Product ID
    ///   - isLoaded: 権利の読み込みが終わっているか。起動直後は購入状態が空のまま届くため、
    ///     読み込み前に反映すると Pro の人のテーマがオーシャンブルーに戻って保存されてしまう
    func applyEntitlements(_ productIds: Set<String>, isLoaded: Bool) {
        guard isLoaded else { return }
        updatePro(StoreManager.isPro(in: productIds))
    }
}
