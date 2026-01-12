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

    /// 購入済みのProduct ID一覧（StoreManagerから更新される）
    @Published var purchasedProductIds: Set<String> = []

    private let selectedThemeKey = "SelectedThemeId"

    init() {
        // 保存されているテーマを読み込む
        if let savedThemeId = UserDefaults.standard.string(forKey: selectedThemeKey),
           let savedTheme = Theme.allThemes.first(where: { $0.id == savedThemeId }) {
            self.currentTheme = savedTheme
        } else {
            self.currentTheme = Theme.defaultTheme
        }
    }

    /// アンロック済みのテーマ一覧
    /// デフォルトテーマは常にアンロック、それ以外は購入済みのものだけ
    var unlockedThemes: [Theme] {
        availableThemes.filter { theme in
            theme.isDefault ||
            purchasedProductIds.contains(theme.productId ?? "") ||
            purchasedProductIds.contains("com.suilog.theme.all_pack")
        }
    }

    /// テーマがアンロック済みかどうか
    func isUnlocked(_ theme: Theme) -> Bool {
        theme.isDefault ||
        purchasedProductIds.contains(theme.productId ?? "") ||
        purchasedProductIds.contains("com.suilog.theme.all_pack")
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
        UserDefaults.standard.set(theme.id, forKey: selectedThemeKey)
        return true
    }

    /// 購入済みProduct IDを更新する
    func updatePurchasedProducts(_ productIds: Set<String>) {
        purchasedProductIds = productIds

        // 現在のテーマがアンロックされていない場合はデフォルトに戻す
        if !isUnlocked(currentTheme) {
            selectTheme(.defaultTheme)
        }
    }
}
