# スイログ Pro 課金 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 課金の柱を買い切りの「スイログ Pro」に一本化し、Pro で「すべてのテーマ」「ホーム画面ウィジェット（訪問の記録）」「写真無制限」が使える状態にする。

**Architecture:** Pro 判定は `StoreManager.isProUnlocked`（`com.suilog.pro` の所有）だけを入口にし、`ThemeManager` は `isPro: Bool` だけを受け取ってテーマを解放する。ウィジェットはアプリとは別プロセスなので、アプリが表示用の小さな `WidgetSnapshot`（JSON）を App Group の共有 UserDefaults に書き出し、ウィジェットは読むだけにする（SwiftData・`Theme.swift` には依存させない）。

**Tech Stack:** Swift 5 モード / SwiftUI / SwiftData / StoreKit 2 / StoreKitTest / WidgetKit / Swift Testing

**Spec:** `docs/superpowers/specs/2026-10-01-pro-monetization-design.md`

## Spec との差分（実装計画で決めたこと）

設計書の内容から次の3点だけ変えている。実装を簡単にするため。

1. **ウィジェットの色**: 設計書は「`Theme.swift` をウィジェットのターゲットにも含める」だったが、`WidgetSnapshot` に色の16進数（`primaryHex` / `tankTopHex` / `tankBottomHex`）を入れることにした。ウィジェットに共有するファイルが `WidgetSnapshot.swift` の1つだけになり、手作業が減る。`themeId` は持たない。
2. **テーマストアの「購入を復元」ボタン**: テーマストアは何も売らなくなるので削除する。復元は Pro の購入画面に一本化する。
3. **権利の読み込み待ち**: 起動直後は購入状態が空なので、読み込みが終わるまでテーマの巻き戻しとウィジェットの書き出しをしない（Pro の人のテーマやウィジェットが一瞬ロック状態で保存されるのを防ぐ）。`StoreManager.hasLoadedEntitlements` を追加する。

## Global Constraints

- 最低 OS は **iOS 26.0**。Swift 言語モードは 5、ビルド設定は `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。アプリとウィジェットで共有する型は `nonisolated` を付ける。
- 新しいユニットテストは **Swift Testing**（`import Testing` / `@Test` / `#expect`）。XCTest は使わない。
- プロジェクトは `PBXFileSystemSynchronizedRootGroup`。新規ファイルは該当フォルダに置くだけで自動的にターゲットに入る。**`project.pbxproj` は手で編集しない**（ウィジェットのターゲット追加は Xcode の画面で行う。Task 7）（Task 7 だけは、Xcode の画面操作ができなかったため、ユーザーの許可を得て直接編集した）。
- UI の文言は日本語。Pro の商品 ID は `com.suilog.pro`（買い切り・600円）、チップは `com.suilog.tip.small` / `.medium` / `.large`（消耗型）。
- 無料のテーマは **オーシャンブルー（`Theme.defaultTheme`）だけ**。ゆめかわ・16ビット・mint・coral は `requiresPro = true`。`Theme.allThemes` は今のまま `[defaultTheme, yumekawa, sixteenBit]`（mint・coral は無効のまま）。
- 写真の上限は今のまま（無料は `VisitRecord.freePhotoLimit = 1`、Pro は無制限）。
- App Group ID は `group.jp.dancho.Suilog`。ウィジェットのターゲットには `Theme.swift` も SwiftData のモデルも入れない。
- 図鑑・Pro を隠す `claude/hide-dex-and-pro` ブランチの変更は使わない（`FeatureFlags` は存在しない）。
- コミットメッセージは `<type>: <description>`（日本語）。末尾に次の1行を付ける:
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`
- ビルドとテストのコマンド（DerivedData は既定の場所を使う。`~/Documents` 配下に置くと codesign が失敗する）:
  - ユニットテスト全部: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
  - ビルドだけ: `xcodebuild -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|\*\* BUILD"`
  - テストが `Simulator device failed to launch ... Busy` で落ちたら、シミュレータを再起動して再実行する: `xcrun simctl shutdown 'iPhone 17 Pro'; xcrun simctl boot 'iPhone 17 Pro'`
  - `ThemeTests` はシミュレータに残った保存済みテーマの影響を受けることがある。落ちたら `xcrun simctl spawn booted defaults delete jp.dancho.Suilog SelectedThemeId` を実行してから再実行する。

## Review Focus

設計書が暗黙に求めているが、各タスクの通常のテストでは見えにくい「壊れやすい入力・状況」。それぞれ、担当タスクにテストを入れてある。

1. **Pro の人が起動した直後**: 購入状態の読み込みが終わる前に、選んでいた Pro テーマをオーシャンブルーに戻して保存してしまわない。ウィジェットにもロック状態を書き出さない。→ Task 1（`applyEntitlements`）、Task 6（`WidgetSnapshotSync`）
2. **Pro が外れたとき**（返金・別の Apple ID）: テーマがオーシャンブルーに戻り、ウィジェットは「Pro で使えます」になる。→ Task 1、Task 5、Task 8
3. **訪問記録が 0 件 / 水族館が消えた記録**: 件数は 0、最近の訪問は空、名前は「水族館」で表示。同じ日時の記録でも並びが毎回同じ。→ Task 5
4. **壊れた・古い形式の共有データ**: ウィジェットは落ちずに「アプリを開くと表示されます」になる。→ Task 4、Task 8
5. **商品を読み込めない（オフライン）/ 復元できる購入がない**: 購入画面に「もう一度読み込む」が出る。復元の結果が「復元しました」「見つかりませんでした」と分かる。→ Task 2

---

### Task 1: Pro でテーマを解放する（モデル・マネージャー・テーマストア）

テーマの `productId` / `isDefault` をやめて `requiresPro` にし、`ThemeManager` を Pro の有無だけで判定させる。`StoreManager` からテーマ商品（ゆめかわ・全部入りパック）をなくす。この変更はコンパイルが連動するため1タスクにまとめている。

**Files:**
- Modify: `Suilog/Models/Theme.swift`
- Modify: `Suilog/Managers/ThemeManager.swift`（全面書き換え）
- Modify: `Suilog/Managers/StoreManager.swift`
- Modify: `Suilog/SuilogApp.swift`
- Modify: `Suilog/Views/ThemeStoreView.swift`
- Test: `SuilogTests/ThemeTests.swift`（全面書き換え）
- Test: `SuilogTests/StoreManagerTests.swift`（全面書き換え）
- Test: `SuilogTests/StoreProductTests.swift`

**Interfaces:**
- Consumes: なし
- Produces:
  - `Theme.requiresPro: Bool`（`productId` / `isDefault` は削除）
  - `ThemeManager.isPro: Bool`（`private(set)`）、`ThemeManager.updatePro(_ isPro: Bool)`、`ThemeManager.applyEntitlements(_ productIds: Set<String>, isLoaded: Bool)`、`ThemeManager.isUnlocked(_ theme: Theme) -> Bool`
  - `StoreManager.isPro(in productIds: Set<String>) -> Bool`（static）、`StoreManager.hasLoadedEntitlements: Bool`（`private(set)` / `@Published`）
  - `StoreManager.allProductIds` は Pro とチップの4つだけ。`themeProductIds` / `allThemesPackId` / `isPurchased(_:)` / `resolveIsPurchased(_:in:)` は削除

- [ ] **Step 1: ThemeTests を書き換える（失敗するテストを先に書く）**

`SuilogTests/ThemeTests.swift` を次の内容で置き換える。

```swift
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
```

- [ ] **Step 2: StoreManagerTests と StoreProductTests を書き換える**

`SuilogTests/StoreManagerTests.swift` を次の内容で置き換える。

```swift
//
//  StoreManagerTests.swift
//  SuilogTests
//
//  StoreManagerの購入判定ロジック（純粋関数部分）のテスト。
//  StoreKit本体を使う購入のテストは ProPurchaseTests にある。
//

import Testing
import Foundation
@testable import Suilog

@Suite
struct StoreManagerTests {

    // MARK: - isPro(in:)

    @Test("Pro を所有していれば Pro 扱い")
    @MainActor
    func testOwnedPro() {
        #expect(StoreManager.isPro(in: ["com.suilog.pro"]) == true)
    }

    @Test("空の所有セットでは Pro ではない")
    @MainActor
    func testEmptyOwnership() {
        #expect(StoreManager.isPro(in: []) == false)
    }

    @Test("チップだけでは Pro ではない")
    @MainActor
    func testTipsAreNotPro() {
        #expect(StoreManager.isPro(in: StoreManager.tipProductIds) == false)
    }

    @Test("販売をやめたテーマ商品を持っていても Pro 扱いにならない")
    @MainActor
    func testRetiredThemeProductsAreNotPro() {
        let retired: Set<String> = ["com.suilog.theme.yumekawa", "com.suilog.theme.all_pack"]
        #expect(StoreManager.isPro(in: retired) == false)
    }
}
```

`SuilogTests/StoreProductTests.swift` の末尾2つのテスト（`testThemeProductIdsUnchanged` と `testAllProductIds`）を、次の1つに置き換える。

```swift
    @Test("全Product IDはProとチップだけで、テーマ商品は含まれない")
    @MainActor
    func testAllProductIds() {
        let all = StoreManager.allProductIds
        #expect(all.count == 4) // Pro1 + チップ3
        #expect(all.isSuperset(of: StoreManager.tipProductIds))
        #expect(all.contains(StoreManager.proProductId))
        #expect(!all.contains("com.suilog.theme.yumekawa"))
        #expect(!all.contains("com.suilog.theme.all_pack"))
    }
```

- [ ] **Step 3: テストが失敗（コンパイルできない）ことを確認**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|\*\* TEST"`
Expected: `requiresPro` / `isPro` / `updatePro` / `applyEntitlements` が見つからないというエラーと `** TEST FAILED **`（または `BUILD FAILED`）

- [ ] **Step 4: Theme を `requiresPro` に変える**

`Suilog/Models/Theme.swift` の構造体定義で、次の2行を

```swift
    let productId: String?          // App Store Connect の Product ID（nil = 無料）
    let isDefault: Bool             // デフォルトテーマかどうか
```

次の1行に置き換える（Edit ツール）。

```swift
    let requiresPro: Bool           // true = スイログ Pro が必要（false = 無料）
```

続けて、5つのテーマ定義（`defaultTheme` / `mint` / `coral` / `yumekawa` / `sixteenBit`）の `productId: nil,` `isDefault: true,` の2行を置き換える。ファイル内に同じ2行の並びが5回あり、1回目が `defaultTheme`（無料）、残り4回が Pro 必須なので、次のスクリプトで一括変換する。

```bash
python3 - <<'EOF'
p = "Suilog/Models/Theme.swift"
s = open(p, encoding="utf-8").read()
old = "        productId: nil,\n        isDefault: true,\n"
assert s.count(old) == 5, s.count(old)
first = s.index(old)
s = s[:first] + "        requiresPro: false,\n" + s[first + len(old):]
s = s.replace(old, "        requiresPro: true,\n")
open(p, "w", encoding="utf-8").write(s)
EOF
grep -n "requiresPro" Suilog/Models/Theme.swift
```

Expected: `requiresPro` の行が、構造体の宣言1つ + テーマ5つ（`false` が1つ、`true` が4つ）の計6行出る。

あわせて、各テーマ定義の直前のコメントのうち「（無料）」「（無料・既存継続）」などを実態に合わせて直す:

- `/// フレッシュミント（無料）` → `/// フレッシュミント（Pro・現在は無効）`
- `mint` / `coral` / `yumekawa` / `sixteenBit` の直前コメントの「無料」表記も同様に「Pro」へ（`defaultTheme` の「デフォルト・無料」はそのまま）。

- [ ] **Step 5: ThemeManager を Pro だけで判定するように書き換える**

`Suilog/Managers/ThemeManager.swift` を次の内容で置き換える。

```swift
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
    /// 選択中のテーマがロックされてしまう場合はオーシャンブルーに戻す
    func updatePro(_ isPro: Bool) {
        self.isPro = isPro

        if !isUnlocked(currentTheme) {
            selectTheme(.defaultTheme)
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
```

- [ ] **Step 6: StoreManager からテーマ商品を消し、Pro 判定と読み込み完了フラグを足す**

`Suilog/Managers/StoreManager.swift` を次の順に編集する（Edit ツール）。

(a) `themeProductIds` の定義を削除する。次の塊を空にする。

```swift
    /// テーマ商品のProduct ID一覧
    static let themeProductIds: Set<String> = [
        "com.suilog.theme.yumekawa",
        "com.suilog.theme.all_pack"
    ]

```

(b) `allProductIds` を置き換える。

```swift
    static var allProductIds: Set<String> {
        themeProductIds.union(tipProductIds).union([proProductId])
    }
```
→
```swift
    static var allProductIds: Set<String> {
        tipProductIds.union([proProductId])
    }
```

(c) `isProUnlocked` を置き換え、`isPro(in:)` を足す。

```swift
    /// スイログ Pro を購入済みかどうか
    var isProUnlocked: Bool {
        purchasedProductIds.contains(Self.proProductId)
    }
```
→
```swift
    /// スイログ Pro を購入済みかどうか
    var isProUnlocked: Bool {
        Self.isPro(in: purchasedProductIds)
    }

    /// 購入済みの Product ID に Pro が含まれるか（テスト容易性のため純粋関数として分離）
    static func isPro(in productIds: Set<String>) -> Bool {
        productIds.contains(proProductId)
    }
```

(d) `purchasedProductIds` の宣言の直後に読み込み完了フラグを足す。

```swift
    /// 購入済みのProduct ID一覧
    @Published private(set) var purchasedProductIds: Set<String> = []
```
→
```swift
    /// 購入済みのProduct ID一覧
    @Published private(set) var purchasedProductIds: Set<String> = []

    /// 購入状態（権利）の最初の読み込みが終わったか。
    /// 起動直後は購入済みが空のため、テーマの巻き戻しやウィジェットの書き出しはこれが true になってから行う
    @Published private(set) var hasLoadedEntitlements = false
```

(e) テーマパックまわりの処理を削除する。次の塊を空にする。

```swift
    /// 全テーマパックのProduct ID（これを持っていれば全テーマがアンロックされる）
    static let allThemesPackId = "com.suilog.theme.all_pack"

    /// 特定の商品が購入済みかどうか
    func isPurchased(_ productId: String) -> Bool {
        Self.resolveIsPurchased(productId, in: purchasedProductIds)
    }

    /// 購入済み判定ロジック（テスト容易性のため純粋関数として分離）
    /// 全テーマパックを所有している場合は個別テーマも購入済みとみなす
    static func resolveIsPurchased(_ productId: String, in purchasedIds: Set<String>) -> Bool {
        purchasedIds.contains(productId) || purchasedIds.contains(allThemesPackId)
    }

```

(f) `updatePurchasedProducts()` の最後で完了フラグを立てる。

```swift
        purchasedProductIds = purchased
    }
```
→
```swift
        purchasedProductIds = purchased
        hasLoadedEntitlements = true
    }
```

- [ ] **Step 7: SuilogApp の購入状態の反映を置き換える**

`Suilog/SuilogApp.swift` の import に `import Combine` を足す（`combineLatest` を使うため。既にあれば何もしない）。

```swift
import SwiftUI
import SwiftData
```
→
```swift
import SwiftUI
import SwiftData
import Combine
```

そして `onReceive` を置き換える。

```swift
                .onReceive(storeManager.$purchasedProductIds) { productIds in
                    // 購入状態が変わったらThemeManagerに通知
                    themeManager.updatePurchasedProducts(productIds)
                }
```
→
```swift
                .onReceive(storeManager.$purchasedProductIds.combineLatest(storeManager.$hasLoadedEntitlements)) { productIds, isLoaded in
                    // 購入状態が変わったらThemeManagerに通知（権利の読み込みが終わるまでは反映しない）
                    themeManager.applyEntitlements(productIds, isLoaded: isLoaded)
                }
```

- [ ] **Step 8: テーマストアを Pro 前提の画面に直す**

`Suilog/Views/ThemeStoreView.swift` を次の順に編集する。

(a) 「お得なセット」と「購入を復元」のセクションを削除する。

```bash
python3 - <<'EOF'
p = "Suilog/Views/ThemeStoreView.swift"
s = open(p, encoding="utf-8").read()

# body から呼び出しを削除
call = "\n\n                    // 全テーマパック\n                    allThemesPackSection\n\n                    // 購入復元ボタン\n                    restorePurchasesButton"
assert call in s
s = s.replace(call, "")

# セクション定義（All Themes Pack と Restore Purchases Button）を削除
a = s.index("    // MARK: - All Themes Pack\n")
b = s.index("}\n\n// MARK: - Theme Card")
s = s[:a].rstrip("\n") + "\n" + s[b:]

open(p, "w", encoding="utf-8").write(s)
EOF
grep -n "allThemesPack\|restorePurchasesButton\|all_pack" Suilog/Views/ThemeStoreView.swift
```
Expected: grep の出力が空（何も残っていない）。

(b) `ThemeCard` の状態表示（価格表示）を Pro バッジに変える。

```swift
            Group {
                if isPurchased {
                    if isSelected {
                        Text("使用中")
                            .foregroundColor(.green)
                    } else {
                        Text("選択可能")
                            .foregroundColor(.blue)
                    }
                } else {
                    if let product = storeManager.product(for: theme.productId ?? "") {
                        Text(product.displayPrice)
                            .foregroundColor(.orange)
                    } else if theme.isDefault {
                        Text("無料")
                            .foregroundColor(.green)
                    } else {
                        Text("読み込み中...")
                            .foregroundColor(.secondary)
                    }
                }
            }
```
→
```swift
            Group {
                if isPurchased {
                    if isSelected {
                        Text("使用中")
                            .foregroundColor(.green)
                    } else {
                        Text("選択可能")
                            .foregroundColor(.blue)
                    }
                } else {
                    Label("Pro", systemImage: "crown.fill")
                        .foregroundColor(.orange)
                }
            }
```

(c) `ThemePreviewView` に Pro 購入画面を開く状態を足す。

```swift
    @Environment(\.dismiss) private var dismiss

    @State private var showingPurchaseError = false

    private var isPurchased: Bool {
```
→
```swift
    @Environment(\.dismiss) private var dismiss

    @State private var showingPurchaseError = false
    @State private var showingProStore = false

    private var isPurchased: Bool {
```

(d) `ThemePreviewView` の購入ボタン（商品を買う分岐と読み込み中の分岐）を、Pro 購入画面への案内に置き換える。

```bash
python3 - <<'EOF'
p = "Suilog/Views/ThemeStoreView.swift"
s = open(p, encoding="utf-8").read()
a = s.index("                        } else if let productId = theme.productId,")
b = s.index("                    }\n                    .padding(24)")
new = '''                        } else {
                            // Pro 限定のテーマ：Pro の購入画面へ案内する
                            Button {
                                showingProStore = true
                            } label: {
                                Label("Pro で使えるようになります", systemImage: "crown.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("themePreview.proButton")
                        }
'''
s = s[:a] + new + s[b:]
open(p, "w", encoding="utf-8").write(s)
EOF
grep -n "productId\|isDefault\|updatePurchasedProducts" Suilog/Views/ThemeStoreView.swift
```
Expected: grep の出力が空。

(e) `ThemePreviewView` に Pro 購入画面のシートを付ける。

```swift
            .ignoresSafeArea(edges: .top)
            .alert("エラー", isPresented: $showingPurchaseError) {
```
→
```swift
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showingProStore) {
                ProStoreView()
                    .environmentObject(storeManager)
                    .environmentObject(themeManager)
            }
            .alert("エラー", isPresented: $showingPurchaseError) {
```

- [ ] **Step 9: 取り残しがないことを確認してテストを通す**

Run: `grep -rn -E "productId:|\.isDefault|updatePurchasedProducts|themeProductIds|allThemesPackId|isPurchased\(|resolveIsPurchased" Suilog SuilogTests | grep "\.swift:"`
Expected: 出力が空（`StoreManager.proProductId` などは `productId:` に一致しない）

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `Test run with ... tests ... passed` と `** TEST SUCCEEDED **`

- [ ] **Step 10: コミット**

```bash
git add Suilog/Models/Theme.swift Suilog/Managers/ThemeManager.swift Suilog/Managers/StoreManager.swift Suilog/SuilogApp.swift Suilog/Views/ThemeStoreView.swift SuilogTests/ThemeTests.swift SuilogTests/StoreManagerTests.swift SuilogTests/StoreProductTests.swift
git commit -m "feat: テーマをスイログ Proで解放する形に一本化

テーマの個別販売と全部入りパックをやめ、Proを持っていれば全テーマが使えるようにする。
無料はオーシャンブルーだけ。購入状態の読み込みが終わるまではテーマを巻き戻さない。

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Pro の購入画面（特典の文言・再読み込み・復元結果）

**Files:**
- Modify: `Suilog/Managers/StoreManager.swift`
- Modify: `Suilog/Views/ProStoreView.swift`
- Modify: `Suilog/Views/ProfileView.swift`
- Test: `SuilogTests/StoreManagerTests.swift`

**Interfaces:**
- Consumes: Task 1 の `StoreManager.isProUnlocked`
- Produces:
  - `enum RestoreOutcome: Equatable { case restored, nothingToRestore, failed }`（`static func resolve(isProUnlocked: Bool, failed: Bool) -> RestoreOutcome`、`var message: String?`）
  - `StoreManager.restorePurchases() async -> RestoreOutcome`（`@discardableResult`）

- [ ] **Step 1: 失敗するテストを書く**

`SuilogTests/StoreManagerTests.swift` の末尾（最後の `}` の直前）に次を足す。

```swift

    // MARK: - RestoreOutcome

    @Test("復元: Pro が見つかれば restored")
    func testRestoreOutcomeRestored() {
        let outcome = RestoreOutcome.resolve(isProUnlocked: true, failed: false)
        #expect(outcome == .restored)
        #expect(outcome.message == "Pro を復元しました")
    }

    @Test("復元: 通信は成功したが Pro がなければ nothingToRestore")
    func testRestoreOutcomeNothingToRestore() {
        let outcome = RestoreOutcome.resolve(isProUnlocked: false, failed: false)
        #expect(outcome == .nothingToRestore)
        #expect(outcome.message == "復元できる購入が見つかりませんでした")
    }

    @Test("復元: 失敗したら failed（メッセージは errorMessage 側で出すので nil）")
    func testRestoreOutcomeFailed() {
        // 失敗時は、たまたま Pro を持っていても failed を優先する
        let outcome = RestoreOutcome.resolve(isProUnlocked: true, failed: true)
        #expect(outcome == .failed)
        #expect(outcome.message == nil)
    }
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests/StoreManagerTests 2>&1 | grep -E "error:|\*\* TEST"`
Expected: `RestoreOutcome` が見つからないというエラー

- [ ] **Step 3: `RestoreOutcome` と `restorePurchases` の戻り値を実装する**

`Suilog/Managers/StoreManager.swift` の `restorePurchases()` を置き換える。

```swift
    /// 購入を復元する
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }
```
→
```swift
    /// 購入を復元する
    /// - Returns: 復元の結果（画面に「復元しました」などを出すために使う）
    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        isLoading = true
        errorMessage = nil
        var failed = false

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
            failed = true
        }

        isLoading = false
        return RestoreOutcome.resolve(isProUnlocked: isProUnlocked, failed: failed)
    }
```

同じファイルの末尾（`StoreError` の定義の後）に足す。

```swift

// MARK: - Restore Outcome

/// 購入の復元の結果
enum RestoreOutcome: Equatable {
    /// Pro が見つかって復元された
    case restored
    /// 通信は成功したが、復元できる購入がなかった
    case nothingToRestore
    /// 復元に失敗した（理由は StoreManager.errorMessage に入る）
    case failed

    static func resolve(isProUnlocked: Bool, failed: Bool) -> RestoreOutcome {
        if failed { return .failed }
        return isProUnlocked ? .restored : .nothingToRestore
    }

    /// 画面に出すメッセージ。失敗時は errorMessage のアラートが別に出るので nil
    var message: String? {
        switch self {
        case .restored: return "Pro を復元しました"
        case .nothingToRestore: return "復元できる購入が見つかりませんでした"
        case .failed: return nil
        }
    }
}
```

- [ ] **Step 4: ProStoreView を直す**

`Suilog/Views/ProStoreView.swift` を次の順に編集する。

(a) 状態を足す。

```swift
    @State private var showingPurchaseSuccess = false
```
→
```swift
    @State private var showingPurchaseSuccess = false
    @State private var restoreMessage: String?
```

(b) 復元結果のアラートを足す（`.alert("エラー", ...` の直前に入れる）。

```swift
            .alert("エラー", isPresented: .init(
```
→
```swift
            .alert("購入の復元", isPresented: .init(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage ?? "")
            }
            .alert("エラー", isPresented: .init(
```

(c) ヘッダーの説明文を、約束しすぎない文言にする。

```swift
            Text("一度の購入で、すべてのPro機能がずっと使えます")
```
→
```swift
            Text("一度の購入で、ずっと使えます")
```

(d) 特典の一覧を実際の中身に合わせる。`benefitsCard` の `VStack` の中身を次の4行に置き換える。

```swift
                benefitRow(
                    icon: "photo.stack.fill",
                    title: "写真を無制限に保存",
                    caption: "1つの記録に保存できる写真が1枚 → 無制限に。思い出をまとめて残せます"
                )
                benefitRow(
                    icon: "paintpalette.fill",
                    title: "すべてのテーマが使える",
                    caption: "ゆめかわ・16ビットなどのテーマを、追加料金なしで選べます"
                )
                benefitRow(
                    icon: "square.grid.2x2.fill",
                    title: "ホーム画面ウィジェット",
                    caption: "訪問した水族館の数や最近の訪問を、ホーム画面に表示できます"
                )
                benefitRow(
                    icon: "heart.fill",
                    title: "開発を応援",
                    caption: "個人開発のスイログを支え、新機能の開発を後押しします"
                )
```

(e) 商品を読み込めなかったときに「もう一度読み込む」を出す。

```swift
        } else {
            Text("商品情報を取得できませんでした。\n時間をおいて再度お試しください。")
                .font(SuiFont.label)
                .foregroundColor(SuiColor.subText)
                .multilineTextAlignment(.center)
        }
```
→
```swift
        } else {
            VStack(spacing: 12) {
                Text("商品情報を取得できませんでした。\n通信状況を確認して、もう一度お試しください。")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.subText)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await storeManager.loadProducts() }
                } label: {
                    Text("もう一度読み込む")
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(theme.primaryColor)
                }
                .accessibilityIdentifier("pro.reloadButton")
            }
        }
```

(f) 復元ボタンで結果を受け取る。

```swift
        Button {
            Task { await storeManager.restorePurchases() }
        } label: {
```
→
```swift
        Button {
            Task {
                let outcome = await storeManager.restorePurchases()
                restoreMessage = outcome.message
            }
        } label: {
```

- [ ] **Step 5: プロフィールの Pro 行の説明文を直す**

`Suilog/Views/ProfileView.swift` の次の1行を置き換える。

```swift
                        : "写真無制限などの追加機能"
```
→
```swift
                        : "写真無制限・全テーマ・ウィジェット"
```

- [ ] **Step 6: テストを通す**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: コミット**

```bash
git add Suilog/Managers/StoreManager.swift Suilog/Views/ProStoreView.swift Suilog/Views/ProfileView.swift SuilogTests/StoreManagerTests.swift
git commit -m "feat: Proの購入画面を実際の特典に合わせ、再読み込みと復元結果を出す

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: StoreKit の設定ファイルと購入の自動テスト

シミュレータで購入を試せるようにスキームへ設定ファイルをつなぎ、`StoreKitTest` で「Pro を買うと使えるようになる」を自動で確かめる。

**Files:**
- Modify: `Suilog/Configuration.storekit`
- Modify: `Suilog.xcodeproj/xcshareddata/xcschemes/Suilog.xcscheme`
- Create: `SuilogTests/ProPurchaseTests.swift`

**Interfaces:**
- Consumes: Task 1 の `StoreManager.isProUnlocked` / `loadProducts()` / `purchase(_:)` / `product(for:)`
- Produces: なし（検証用）

- [ ] **Step 1: 失敗するテストを書く**

`SuilogTests/ProPurchaseTests.swift` を作る。`Configuration.storekit` にまだゆめかわ・全部入りパックが残っているので、「Pro とチップだけ」のテストは失敗する。

```swift
//
//  ProPurchaseTests.swift
//  SuilogTests
//
//  StoreKitTest を使って、Configuration.storekit の商品で購入の流れを確かめる。
//

import Testing
import Foundation
import StoreKitTest
@testable import Suilog

@Suite(.serialized)
struct ProPurchaseTests {

    /// Configuration.storekit を読み込んだテストセッションを作る
    @MainActor
    private func makeSession() throws -> SKTestSession {
        let storeKitFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SuilogTests
            .deletingLastPathComponent()   // リポジトリ直下
            .appendingPathComponent("Suilog/Configuration.storekit")
        let session = try SKTestSession(contentsOf: storeKitFile)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test("販売する商品は Pro とチップ3つだけ")
    @MainActor
    func testOnlyProAndTipsAreSold() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = StoreManager()
        await manager.loadProducts()

        let ids = Set(manager.products.map(\.id))
        #expect(ids == StoreManager.allProductIds)
        #expect(manager.product(for: StoreManager.proProductId)?.displayPrice.contains("600") == true)
    }

    @Test("購入前は Pro ではなく、Pro を買うと使えるようになる")
    @MainActor
    func testPurchasePro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = StoreManager()
        await manager.loadProducts()
        #expect(manager.isProUnlocked == false)

        let product = try #require(manager.product(for: StoreManager.proProductId))
        let success = await manager.purchase(product)

        #expect(success == true)
        #expect(manager.isProUnlocked == true)
        #expect(manager.hasLoadedEntitlements == true)
    }

    @Test("チップを買っても Pro にはならない")
    @MainActor
    func testTipDoesNotUnlockPro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = StoreManager()
        await manager.loadProducts()

        let tip = try #require(manager.product(for: "com.suilog.tip.small"))
        let success = await manager.purchaseTip(tip)

        #expect(success == true)
        #expect(manager.isProUnlocked == false)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests/ProPurchaseTests 2>&1 | grep -E "error:|✘|✔|\*\* TEST"`
Expected: `testOnlyProAndTipsAreSold` が失敗する（ゆめかわ・全部入りパックが商品に残っているため）。購入系の2件は通るかもしれない。

- [ ] **Step 3: `Configuration.storekit` からテーマ商品を消し、Pro の説明を直す**

```bash
python3 - <<'EOF'
p = "Suilog/Configuration.storekit"
s = open(p, encoding="utf-8").read()
start = s.index('"products" : [\n') + len('"products" : [\n')
pro = s.index('    {\n      "displayPrice" : "600"')
s = s[:start] + s[pro:]
open(p, "w", encoding="utf-8").write(s)
EOF
python3 -c "import json; d = json.load(open('Suilog/Configuration.storekit')); print([p['productID'] for p in d['products']])"
```
Expected: `['com.suilog.pro', 'com.suilog.tip.small', 'com.suilog.tip.medium', 'com.suilog.tip.large']`

Pro の説明文を実際の特典に合わせる（Edit ツール）。

```
          "description" : "写真無制限など、すべてのPro機能が使える買い切りプラン",
```
→
```
          "description" : "写真の無制限保存・すべてのテーマ・ホーム画面ウィジェットが使える買い切りプラン",
```

```
          "description" : "One-time purchase unlocking unlimited photos and all Pro features",
```
→
```
          "description" : "One-time purchase: unlimited photos, all themes, and the home screen widget",
```

- [ ] **Step 4: スキームの Run に StoreKit 設定ファイルをつなぐ**

`Suilog.xcodeproj/xcshareddata/xcschemes/Suilog.xcscheme` の `LaunchAction` の終わりに足す（Edit ツール）。

```xml
            ReferencedContainer = "container:Suilog.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
```
→
```xml
            ReferencedContainer = "container:Suilog.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "../../Suilog/Configuration.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
```

このパスの書き方はスキームファイルの場所からの相対で、こちらでは実際に Xcode で開いて確かめられない。**ユーザーに確認してもらう**（Task 9 の最終確認にも入れてある）: Xcode で Product → Scheme → Edit Scheme → Run → Options の「StoreKit Configuration」が `Configuration.storekit` になっているか。空のままなら、そこで選び直す（Xcode がスキームのパスを正しく書き直す）。

- [ ] **Step 5: テストを通す**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`（`ProPurchaseTests` の3件を含む）

もし `SKTestSession` の作成自体が失敗する（ファイルが見つからない等）ときは、`#filePath` の階層（`SuilogTests` → リポジトリ直下）が合っているかを確認する。

- [ ] **Step 6: コミット**

```bash
git add Suilog/Configuration.storekit Suilog.xcodeproj/xcshareddata/xcschemes/Suilog.xcscheme SuilogTests/ProPurchaseTests.swift
git commit -m "test: StoreKit設定をProとチップだけにして購入の流れを自動テストする

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: ウィジェットの共有データ `WidgetSnapshot`（モデルと保存）

**Files:**
- Create: `Suilog/Shared/WidgetSnapshot.swift`（アプリとウィジェットの両方に含める）
- Test: `SuilogTests/WidgetSnapshotTests.swift`
- Modify: `docs/superpowers/specs/2026-10-01-pro-monetization-design.md`（差分の追記）

**Interfaces:**
- Consumes: なし
- Produces:
  - `WidgetSnapshot`（`nonisolated struct`, `Codable, Equatable, Sendable`）: `visitedAquariumCount: Int`, `visitCount: Int`, `recentVisits: [RecentVisit]`, `primaryHex: String`, `tankTopHex: String`, `tankBottomHex: String`, `isPro: Bool`, `updatedAt: Date`
  - `WidgetSnapshot.RecentVisit`: `aquariumName: String`, `visitDate: Date`, `isLocationCheckIn: Bool`
  - `WidgetSnapshot.withoutTimestamp: WidgetSnapshot`（`updatedAt` を固定した複製。変化の検出用）
  - `WidgetSnapshot.placeholder` / `WidgetSnapshot.placeholderLocked`（プレビュー用）
  - `WidgetSnapshotStore`（`nonisolated struct`）: `static let appGroupId`, `static let key`, `init(defaults: UserDefaults = …)`, `save(_:)`, `load() -> WidgetSnapshot?`

- [ ] **Step 1: 失敗するテストを書く**

`SuilogTests/WidgetSnapshotTests.swift` を作る。

```swift
//
//  WidgetSnapshotTests.swift
//  SuilogTests
//
//  ウィジェットとの共有データ（WidgetSnapshot / WidgetSnapshotStore）のテスト。
//

import Testing
import Foundation
@testable import Suilog

@Suite
struct WidgetSnapshotTests {

    /// テストごとに独立した UserDefaults を使う
    private func makeStore() -> (store: WidgetSnapshotStore, defaults: UserDefaults) {
        let suite = "WidgetSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (WidgetSnapshotStore(defaults: defaults), defaults)
    }

    /// 秒未満を含まない日時（JSON は ISO 8601 で秒単位のため）
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSnapshot(isPro: Bool = true, updatedAt: Date? = nil) -> WidgetSnapshot {
        WidgetSnapshot(
            visitedAquariumCount: 12,
            visitCount: 30,
            recentVisits: [
                .init(aquariumName: "海遊館", visitDate: date, isLocationCheckIn: true),
                .init(aquariumName: "サンシャイン水族館", visitDate: date.addingTimeInterval(-86_400), isLocationCheckIn: false)
            ],
            primaryHex: "#3FA8CB",
            tankTopHex: "#A8D8EF",
            tankBottomHex: "#6BBBD8",
            isPro: isPro,
            updatedAt: updatedAt ?? date
        )
    }

    @Test("保存したスナップショットをそのまま読み戻せる")
    func testRoundTrip() {
        let (store, _) = makeStore()
        let snapshot = makeSnapshot()
        store.save(snapshot)
        #expect(store.load() == snapshot)
    }

    @Test("何も保存していなければ nil")
    func testLoadWithoutSave() {
        let (store, _) = makeStore()
        #expect(store.load() == nil)
    }

    @Test("壊れたデータなら落ちずに nil")
    func testLoadCorruptedData() {
        let (store, defaults) = makeStore()
        defaults.set(Data("これはJSONではない".utf8), forKey: WidgetSnapshotStore.key)
        #expect(store.load() == nil)
    }

    @Test("古い形式（項目が足りない）のデータなら落ちずに nil")
    func testLoadIncompatibleData() {
        let (store, defaults) = makeStore()
        defaults.set(Data(#"{"visitCount": 3}"#.utf8), forKey: WidgetSnapshotStore.key)
        #expect(store.load() == nil)
    }

    @Test("上書き保存すると新しい内容が読める")
    func testOverwrite() {
        let (store, _) = makeStore()
        store.save(makeSnapshot(isPro: true))
        store.save(makeSnapshot(isPro: false))
        #expect(store.load()?.isPro == false)
    }

    @Test("withoutTimestamp: 更新日時だけが違うスナップショットは同じ中身とみなせる")
    func testWithoutTimestamp() {
        let a = makeSnapshot(updatedAt: date)
        let b = makeSnapshot(updatedAt: date.addingTimeInterval(3600))
        #expect(a != b)
        #expect(a.withoutTimestamp == b.withoutTimestamp)
    }

    @Test("withoutTimestamp: 中身が違えば別物")
    func testWithoutTimestampDetectsChange() {
        #expect(makeSnapshot(isPro: true).withoutTimestamp != makeSnapshot(isPro: false).withoutTimestamp)
    }

    @Test("プレビュー用のデータ: placeholder は Pro、placeholderLocked は Pro ではない")
    func testPlaceholders() {
        #expect(WidgetSnapshot.placeholder.isPro == true)
        #expect(WidgetSnapshot.placeholderLocked.isPro == false)
        #expect(WidgetSnapshot.placeholder.recentVisits.count == 3)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests/WidgetSnapshotTests 2>&1 | grep -E "error:|\*\* TEST"`
Expected: `WidgetSnapshot` が見つからないというエラー

- [ ] **Step 3: 共有ファイルを実装する**

`Suilog/Shared/WidgetSnapshot.swift` を作る。**SwiftData・`Theme`・SwiftUI に依存させない**（ウィジェットのターゲットにも入れるため）。

```swift
//
//  WidgetSnapshot.swift
//  Suilog
//
//  ホーム画面ウィジェットに表示するデータ。アプリが書き出し、ウィジェットは読むだけ。
//  アプリとウィジェットの両ターゲットに含めるため、SwiftData や Theme には依存させない。
//

import Foundation

/// ウィジェットに表示する内容のスナップショット
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {

    /// 最近の訪問 1 件分
    nonisolated struct RecentVisit: Codable, Equatable, Sendable {
        var aquariumName: String
        var visitDate: Date
        /// true = 位置情報チェックイン（ゴールド）、false = 手動（シルバー）
        var isLocationCheckIn: Bool
    }

    /// 訪問した水族館の数
    var visitedAquariumCount: Int
    /// 訪問回数
    var visitCount: Int
    /// 最近の訪問（新しい順・最大3件）
    var recentVisits: [RecentVisit]
    /// ウィジェットの配色（テーマの色を16進数で持つ。ウィジェット側で Theme を使わないため）
    var primaryHex: String
    var tankTopHex: String
    var tankBottomHex: String
    /// スイログ Pro を購入済みか。false のウィジェットは「Pro で使えます」を表示する
    var isPro: Bool
    var updatedAt: Date

    /// 更新日時を固定した複製。「中身が変わったか」の判定に使う
    var withoutTimestamp: WidgetSnapshot {
        var copy = self
        copy.updatedAt = .distantPast
        return copy
    }
}

extension WidgetSnapshot {
    /// Xcode のプレビューやウィジェットギャラリー用のサンプル
    nonisolated static let placeholder = WidgetSnapshot(
        visitedAquariumCount: 12,
        visitCount: 30,
        recentVisits: [
            RecentVisit(aquariumName: "海遊館", visitDate: Date(timeIntervalSince1970: 1_700_000_000), isLocationCheckIn: true),
            RecentVisit(aquariumName: "サンシャイン水族館", visitDate: Date(timeIntervalSince1970: 1_699_900_000), isLocationCheckIn: false),
            RecentVisit(aquariumName: "美ら海水族館", visitDate: Date(timeIntervalSince1970: 1_699_800_000), isLocationCheckIn: true)
        ],
        primaryHex: "#3FA8CB",
        tankTopHex: "#A8D8EF",
        tankBottomHex: "#6BBBD8",
        isPro: true,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    /// Pro ではない状態のサンプル
    nonisolated static var placeholderLocked: WidgetSnapshot {
        var snapshot = placeholder
        snapshot.isPro = false
        return snapshot
    }
}

/// App Group の共有 UserDefaults にスナップショットを JSON で保存・読み込みする
nonisolated struct WidgetSnapshotStore {
    static let appGroupId = "group.jp.dancho.Suilog"
    static let key = "widgetSnapshot.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: WidgetSnapshotStore.appGroupId) ?? .standard) {
        self.defaults = defaults
    }

    func save(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// 保存がない・壊れている・古い形式のときは nil
    func load() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
```

- [ ] **Step 4: テストを通す**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 設計書に差分を追記する**

`docs/superpowers/specs/2026-10-01-pro-monetization-design.md` の「2. ホーム画面ウィジェット」の「共有データ `WidgetSnapshot`」の箇条書きを、次のとおり直す（Edit ツール）。

```
  - `themeId: String`
```
→
```
  - `primaryHex` / `tankTopHex` / `tankBottomHex: String`（テーマの色。ウィジェット側で `Theme` を使わないため、`themeId` ではなく色を直接持つ）
```

「ウィジェット本体」の次の行を直す。

```
  このため `Theme.swift` をウィジェットのターゲットにも含める。
```
→
```
  色は `WidgetSnapshot` の16進数から作る（`Theme.swift` はウィジェットに含めない）。
```

「手作業（ユーザー）」に1項目を足す。

```
2. アプリとウィジェットの両ターゲットに App Groups を追加し、`group.jp.dancho.Suilog` を登録。
```
→
```
2. アプリとウィジェットの両ターゲットに App Groups を追加し、`group.jp.dancho.Suilog` を登録。
3. `Suilog/Shared/WidgetSnapshot.swift` のターゲットメンバーシップに `SuilogWidget` を追加。
```

「購入の流れとエラー処理」の末尾に足す。

```
- 起動直後は購入状態が空のため、購入状態（権利）の読み込みが終わるまで、テーマの巻き戻しとウィジェットの書き出しを行わない（`StoreManager.hasLoadedEntitlements`）。
- テーマストアの「購入を復元」ボタンは削除し、復元は Pro の購入画面に一本化する。
```

- [ ] **Step 6: コミット**

```bash
git add Suilog/Shared/WidgetSnapshot.swift SuilogTests/WidgetSnapshotTests.swift docs/superpowers/specs/2026-10-01-pro-monetization-design.md
git commit -m "feat: ウィジェットと共有するWidgetSnapshotと保存処理を追加

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 訪問記録から `WidgetSnapshot` を作る

**Files:**
- Create: `Suilog/Managers/WidgetSnapshotBuilder.swift`（アプリのみ）
- Test: `SuilogTests/WidgetSnapshotBuilderTests.swift`

**Interfaces:**
- Consumes: Task 4 の `WidgetSnapshot` / `WidgetSnapshot.RecentVisit`、`Theme`（`primaryColorHex` / `tankTopHex` / `tankBottomHex` / `primaryLightHex`）、`VisitRecord`（`visitDate` / `checkInType` / `aquarium`）、`Aquarium`（`id` / `name`）
- Produces: `WidgetSnapshot.init(visits: [VisitRecord], theme: Theme, isPro: Bool, now: Date = Date())`（`@MainActor`）、`WidgetSnapshot.recentVisitLimit`（`= 3`）

- [ ] **Step 1: 失敗するテストを書く**

`SuilogTests/WidgetSnapshotBuilderTests.swift` を作る。

```swift
//
//  WidgetSnapshotBuilderTests.swift
//  SuilogTests
//
//  訪問記録からウィジェット用のスナップショットを作る処理のテスト。
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

@Suite(.serialized)
struct WidgetSnapshotBuilderTests {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Aquarium.self, VisitRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    private func makeAquarium(_ name: String, in context: ModelContext) -> Aquarium {
        let aquarium = Aquarium(name: name, latitude: 35.0, longitude: 139.0, description: "", region: "関東")
        context.insert(aquarium)
        return aquarium
    }

    @MainActor
    private func makeVisit(
        _ aquarium: Aquarium?,
        daysAgo: Int,
        type: CheckInType = .manual,
        id: UUID = UUID(),
        in context: ModelContext
    ) -> VisitRecord {
        let date = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(TimeInterval(-daysAgo * 86_400))
        let visit = VisitRecord(id: id, visitDate: date, checkInType: type, aquarium: aquarium)
        context.insert(visit)
        return visit
    }

    private let now = Date(timeIntervalSince1970: 1_700_100_000)

    @Test("訪問が 0 件でも作れる（件数 0・最近の訪問は空）")
    @MainActor
    func testEmpty() {
        let snapshot = WidgetSnapshot(visits: [], theme: .defaultTheme, isPro: true, now: now)
        #expect(snapshot.visitedAquariumCount == 0)
        #expect(snapshot.visitCount == 0)
        #expect(snapshot.recentVisits.isEmpty)
        #expect(snapshot.updatedAt == now)
    }

    @Test("訪問館数は重複しない水族館の数、訪問回数は記録の数")
    @MainActor
    func testCounts() throws {
        let context = try makeContext()
        let kaiyukan = makeAquarium("海遊館", in: context)
        let sunshine = makeAquarium("サンシャイン水族館", in: context)
        let visits = [
            makeVisit(kaiyukan, daysAgo: 1, in: context),
            makeVisit(kaiyukan, daysAgo: 2, in: context),
            makeVisit(sunshine, daysAgo: 3, in: context)
        ]

        let snapshot = WidgetSnapshot(visits: visits, theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.visitedAquariumCount == 2)
        #expect(snapshot.visitCount == 3)
    }

    @Test("最近の訪問は新しい順に最大3件")
    @MainActor
    func testRecentVisitsAreNewestFirstAndLimited() throws {
        let context = try makeContext()
        let names = ["A館", "B館", "C館", "D館", "E館"]
        // daysAgo が小さいほど新しい。わざと順不同で渡す
        let order = [3, 0, 4, 1, 2]
        let visits = order.map { index in
            makeVisit(makeAquarium(names[index], in: context), daysAgo: index, in: context)
        }

        let snapshot = WidgetSnapshot(visits: visits, theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.recentVisits.map(\.aquariumName) == ["A館", "B館", "C館"])
    }

    @Test("チェックインの種類（ゴールド/シルバー）が引き継がれる")
    @MainActor
    func testCheckInType() throws {
        let context = try makeContext()
        let aquarium = makeAquarium("海遊館", in: context)
        let visits = [
            makeVisit(aquarium, daysAgo: 0, type: .location, in: context),
            makeVisit(aquarium, daysAgo: 1, type: .manual, in: context)
        ]

        let snapshot = WidgetSnapshot(visits: visits, theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.recentVisits.map(\.isLocationCheckIn) == [true, false])
    }

    @Test("水族館が消えた記録は名前を「水族館」にし、訪問館数には数えない")
    @MainActor
    func testVisitWithoutAquarium() throws {
        let context = try makeContext()
        let visit = makeVisit(nil, daysAgo: 0, in: context)

        let snapshot = WidgetSnapshot(visits: [visit], theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.visitCount == 1)
        #expect(snapshot.visitedAquariumCount == 0)
        #expect(snapshot.recentVisits.map(\.aquariumName) == ["水族館"])
    }

    @Test("同じ日時の記録でも並びが毎回同じ")
    @MainActor
    func testTieBreakIsDeterministic() throws {
        let context = try makeContext()
        let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let a = makeVisit(makeAquarium("A館", in: context), daysAgo: 0, id: idA, in: context)
        let b = makeVisit(makeAquarium("B館", in: context), daysAgo: 0, id: idB, in: context)

        let forward = WidgetSnapshot(visits: [a, b], theme: .defaultTheme, isPro: true, now: now)
        let backward = WidgetSnapshot(visits: [b, a], theme: .defaultTheme, isPro: true, now: now)

        #expect(forward.recentVisits == backward.recentVisits)
    }

    @Test("Pro の有無と、テーマの色が反映される")
    @MainActor
    func testProAndThemeColors() {
        let withPro = WidgetSnapshot(visits: [], theme: .sixteenBit, isPro: true, now: now)
        let withoutPro = WidgetSnapshot(visits: [], theme: .sixteenBit, isPro: false, now: now)

        #expect(withPro.isPro == true)
        #expect(withoutPro.isPro == false)
        #expect(withPro.primaryHex == Theme.sixteenBit.primaryColorHex)
        #expect(withPro.tankTopHex == Theme.sixteenBit.tankTopHex ?? Theme.sixteenBit.primaryColorHex)
        #expect(withPro.tankBottomHex == Theme.sixteenBit.tankBottomHex ?? Theme.sixteenBit.primaryColorHex)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests/WidgetSnapshotBuilderTests 2>&1 | grep -E "error:|\*\* TEST"`
Expected: `init(visits:theme:isPro:now:)` が見つからないというエラー

- [ ] **Step 3: 実装する**

`Suilog/Managers/WidgetSnapshotBuilder.swift` を作る。

```swift
//
//  WidgetSnapshotBuilder.swift
//  Suilog
//
//  訪問記録・テーマ・Pro 状態から、ウィジェットに渡すスナップショットを作る。
//  （SwiftData の VisitRecord に依存するため、ウィジェットのターゲットには含めない）
//

import Foundation

extension WidgetSnapshot {
    /// 最近の訪問として載せる件数
    nonisolated static let recentVisitLimit = 3

    @MainActor
    init(visits: [VisitRecord], theme: Theme, isPro: Bool, now: Date = Date()) {
        // 新しい順。同じ日時でも並びが毎回同じになるよう ID で決める
        let newestFirst = visits.sorted {
            ($0.visitDate, $0.id.uuidString) > ($1.visitDate, $1.id.uuidString)
        }
        let recent = newestFirst.prefix(Self.recentVisitLimit).map { visit in
            RecentVisit(
                aquariumName: visit.aquarium?.name ?? "水族館",
                visitDate: visit.visitDate,
                isLocationCheckIn: visit.checkInType == .location
            )
        }

        self.init(
            visitedAquariumCount: Set(visits.compactMap { $0.aquarium?.id }).count,
            visitCount: visits.count,
            recentVisits: Array(recent),
            primaryHex: theme.primaryColorHex,
            tankTopHex: theme.tankTopHex ?? theme.primaryColorHex,
            tankBottomHex: theme.tankBottomHex ?? theme.primaryColorHex,
            isPro: isPro,
            updatedAt: now
        )
    }
}
```

- [ ] **Step 4: テストを通す**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Suilog/Managers/WidgetSnapshotBuilder.swift SuilogTests/WidgetSnapshotBuilderTests.swift
git commit -m "feat: 訪問記録からウィジェット用スナップショットを作る

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: アプリ側でスナップショットを書き出してウィジェットを更新する

**Files:**
- Create: `Suilog/Managers/WidgetSnapshotSync.swift`
- Modify: `Suilog/ContentView.swift`
- Test: `SuilogTests/WidgetSnapshotSyncTests.swift`

**Interfaces:**
- Consumes: Task 4 の `WidgetSnapshotStore` / `WidgetSnapshot.withoutTimestamp`、Task 5 の `WidgetSnapshot(visits:theme:isPro:now:)`、Task 1 の `StoreManager.hasLoadedEntitlements` / `isProUnlocked`
- Produces:
  - `WidgetSnapshotSync.write(_:entitlementsLoaded:store:reload:) -> Bool`（`@MainActor` の `enum` の static 関数）
  - `View.syncsWidgetSnapshot(visits:theme:isPro:entitlementsLoaded:)`

- [ ] **Step 1: 失敗するテストを書く**

`SuilogTests/WidgetSnapshotSyncTests.swift` を作る。

```swift
//
//  WidgetSnapshotSyncTests.swift
//  SuilogTests
//
//  ウィジェット用スナップショットの書き出し条件のテスト。
//

import Testing
import Foundation
@testable import Suilog

@Suite
struct WidgetSnapshotSyncTests {

    private func makeStore() -> WidgetSnapshotStore {
        let suite = "WidgetSnapshotSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WidgetSnapshotStore(defaults: defaults)
    }

    @Test("権利の読み込み前は書き出さず、ウィジェットの更新も依頼しない")
    @MainActor
    func testDoesNotWriteBeforeEntitlementsLoaded() {
        let store = makeStore()
        var reloadCount = 0

        // 起動直後は isPro = false のまま。ここで保存すると Pro の人のウィジェットがロック表示になってしまう
        let written = WidgetSnapshotSync.write(
            WidgetSnapshot.placeholderLocked,
            entitlementsLoaded: false,
            store: store,
            reload: { reloadCount += 1 }
        )

        #expect(written == false)
        #expect(store.load() == nil)
        #expect(reloadCount == 0)
    }

    @Test("権利の読み込み後は保存して、ウィジェットの更新を1回依頼する")
    @MainActor
    func testWritesAfterEntitlementsLoaded() {
        let store = makeStore()
        var reloadCount = 0

        let written = WidgetSnapshotSync.write(
            WidgetSnapshot.placeholder,
            entitlementsLoaded: true,
            store: store,
            reload: { reloadCount += 1 }
        )

        #expect(written == true)
        #expect(store.load()?.isPro == true)
        #expect(reloadCount == 1)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests/WidgetSnapshotSyncTests 2>&1 | grep -E "error:|\*\* TEST"`
Expected: `WidgetSnapshotSync` が見つからないというエラー

- [ ] **Step 3: 書き出し処理と View の修飾子を実装する**

`Suilog/Managers/WidgetSnapshotSync.swift` を作る。

```swift
//
//  WidgetSnapshotSync.swift
//  Suilog
//
//  訪問記録・テーマ・Pro 状態が変わったら、ウィジェット用のスナップショットを書き出して更新を依頼する。
//

import SwiftUI
import WidgetKit

@MainActor
enum WidgetSnapshotSync {
    /// スナップショットを保存し、ウィジェットの更新を依頼する
    /// - Parameter entitlementsLoaded: 購入状態（権利）の読み込みが終わっているか。
    ///   起動直後は Pro 判定が false のため、読み込み前に書き出すと Pro の人のウィジェットがロック表示になる
    /// - Returns: 書き出したかどうか
    @discardableResult
    static func write(
        _ snapshot: WidgetSnapshot,
        entitlementsLoaded: Bool,
        store: WidgetSnapshotStore = WidgetSnapshotStore(),
        reload: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) -> Bool {
        guard entitlementsLoaded else { return false }
        store.save(snapshot)
        reload()
        return true
    }
}

extension View {
    /// 訪問記録・テーマ・Pro 状態の変化を、ウィジェットに反映する
    func syncsWidgetSnapshot(
        visits: [VisitRecord],
        theme: Theme,
        isPro: Bool,
        entitlementsLoaded: Bool
    ) -> some View {
        modifier(WidgetSnapshotSyncModifier(
            visits: visits,
            theme: theme,
            isPro: isPro,
            entitlementsLoaded: entitlementsLoaded
        ))
    }
}

private struct WidgetSnapshotSyncModifier: ViewModifier {
    let visits: [VisitRecord]
    let theme: Theme
    let isPro: Bool
    let entitlementsLoaded: Bool

    /// 変化の検出用（更新日時は含めない）
    private struct Trigger: Equatable {
        let snapshot: WidgetSnapshot
        let entitlementsLoaded: Bool
    }

    func body(content: Content) -> some View {
        let snapshot = WidgetSnapshot(visits: visits, theme: theme, isPro: isPro)
        let trigger = Trigger(snapshot: snapshot.withoutTimestamp, entitlementsLoaded: entitlementsLoaded)
        content.onChange(of: trigger, initial: true) {
            WidgetSnapshotSync.write(snapshot, entitlementsLoaded: entitlementsLoaded)
        }
    }
}
```

- [ ] **Step 4: ContentView に組み込む**

`Suilog/ContentView.swift` を編集する。

```swift
    @Query private var aquariums: [Aquarium]
```
→
```swift
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord]
```

```swift
        .tint(themeManager.currentTheme.primaryColor)
        .safeAreaInset(edge: .bottom, spacing: 0) {
```
→
```swift
        .tint(themeManager.currentTheme.primaryColor)
        .syncsWidgetSnapshot(
            visits: visitRecords,
            theme: themeManager.currentTheme,
            isPro: storeManager.isProUnlocked,
            entitlementsLoaded: storeManager.hasLoadedEntitlements
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
```

- [ ] **Step 5: テストとビルドを通す**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: シミュレータで書き出しを確かめる**

アプリを入れて起動し、共有 UserDefaults に保存されたことを確認する。

```bash
xcodebuild -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|\*\* BUILD"
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*Suilog-*/Build/Products/Debug-iphonesimulator/Suilog.app" -maxdepth 6 | head -1)
xcrun simctl install booted "$APP" && xcrun simctl launch booted jp.dancho.Suilog
sleep 8
xcrun simctl spawn booted defaults read group.jp.dancho.Suilog 2>&1 | head -5
```
Expected: `widgetSnapshot.v1` というキーが見える（データは Base64 などの形で表示される）。見えなければ、`hasLoadedEntitlements` が true にならない（商品読み込み待ち）か、シミュレータで App Group のサフィックスが違うことが考えられる。その場合は `xcrun simctl spawn booted defaults read` の出力でドメイン名を探す。

- [ ] **Step 7: コミット**

```bash
git add Suilog/Managers/WidgetSnapshotSync.swift Suilog/ContentView.swift SuilogTests/WidgetSnapshotSyncTests.swift
git commit -m "feat: 訪問記録・テーマ・Pro状態の変化をウィジェットに反映する

権利の読み込みが終わるまでは書き出さず、Proの人のウィジェットがロック表示になるのを防ぐ。

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 【手作業・ユーザー】Xcode でウィジェットのターゲットを作る

ウィジェットのターゲットは `project.pbxproj` に登録する必要があり、手で書き換えると壊れやすい。Xcode の画面から作ってもらう。**この作業はユーザーが行う。完了の連絡が来るまで Task 8 には進まない。**

**Files:** （Xcode が生成する）
- Create: `SuilogWidget/`（フォルダと中のファイル）
- Modify: `Suilog.xcodeproj/project.pbxproj`
- Modify: `Suilog/Suilog.entitlements`（App Group が足される）
- Create: `SuilogWidget/SuilogWidgetExtension.entitlements`（名前は Xcode が決める）

- [ ] **Step 1: ユーザーに次の手順を依頼する**

1. Xcode で `Suilog.xcodeproj` を開く。現在のブランチが `claude/pro-monetization` であることを確認する。
2. メニュー File → New → Target… → iOS → **Widget Extension** → Next。
3. Product Name に `SuilogWidget` と入力。Team は今のアプリと同じ。**「Include Live Activity」「Include Control」「Include Configuration App Intent」のチェックは外す**。Finish。
4. 「Activate "SuilogWidgetExtension" scheme?」と聞かれたら **Cancel**（今の `Suilog` スキームのまま使う）。
5. 左のプロジェクトナビゲーターでプロジェクト（青いアイコン）→ TARGETS の `Suilog` を選び、Signing & Capabilities → **+ Capability** → **App Groups** → **+** で `group.jp.dancho.Suilog` を追加。
6. 同じように TARGETS の `SuilogWidgetExtension`（Xcode が付けた名前）にも App Groups の機能を追加し、同じ `group.jp.dancho.Suilog` にチェックを入れる。
7. TARGETS の `SuilogWidgetExtension` → General → Minimum Deployments が **iOS 26.0** になっていることを確認する（違えば直す）。
8. ナビゲーターで `Suilog/Shared/WidgetSnapshot.swift` を選び、右のインスペクタ（File Inspector）の **Target Membership** で `SuilogWidgetExtension` にもチェックを入れる（`Suilog` のチェックは付けたまま）。
9. 終わったら「できた」と伝える。

- [ ] **Step 2: 完了の連絡を受けたら、変更内容を確認する**

Run: `git status --short && ls SuilogWidget && cat Suilog/Suilog.entitlements | grep -A3 "application-groups"`
Expected:
- `SuilogWidget/` フォルダと `project.pbxproj` が変更されている
- `Suilog.entitlements` に `com.apple.security.application-groups` と `group.jp.dancho.Suilog` がある
- ウィジェット用の entitlements ファイルにも同じ App Group がある（`grep -r "group.jp.dancho.Suilog" SuilogWidget *.entitlements Suilog/*.entitlements`）

- [ ] **Step 3: ビルドが通ることを確認する**

Run: `xcodebuild -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`

`WidgetSnapshot.swift` のターゲットメンバーシップが足りないとエラーになるのは Task 8 でウィジェットのコードを書いてから。ここでは Xcode が作ったひな形がビルドできることだけを確かめる。

- [ ] **Step 4: コミット**

```bash
git add SuilogWidget Suilog.xcodeproj/project.pbxproj Suilog/Suilog.entitlements
git status --short
git commit -m "chore: ウィジェットのターゲットとApp Groupを追加

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

（`git status` でウィジェット関係以外の変更が混ざっていないことを確認してからコミットする。ウィジェット用の entitlements ファイルが `SuilogWidget/` の外にある場合は、それも `git add` する。）

---

### Task 8: ウィジェット本体（訪問の記録）

**Files:**
- Modify/Create（`SuilogWidget/` の中）:
  - `SuilogWidgetBundle.swift`
  - `SuilogWidget.swift`
  - `SuilogWidgetView.swift`（新規）
  - `WidgetColor.swift`（新規）
- Delete: Xcode が作ったひな形のうち、上記以外の `.swift`（`SuilogWidgetControl.swift` / `SuilogWidgetLiveActivity.swift` / `AppIntent.swift` など。あれば）

**Interfaces:**
- Consumes: Task 4 の `WidgetSnapshot` / `WidgetSnapshot.RecentVisit` / `WidgetSnapshot.placeholder` / `WidgetSnapshot.placeholderLocked` / `WidgetSnapshotStore`
- Produces: `SuilogWidget`（kind = `"SuilogWidget"`、小・中サイズ）

- [ ] **Step 1: ひな形を整理する**

```bash
ls SuilogWidget
```

`SuilogWidgetBundle.swift` と `SuilogWidget.swift` 以外の `.swift` ファイルがあれば削除する（`Assets.xcassets` と `Info.plist` は残す）。`project.pbxproj` は同期フォルダ方式なので編集しなくてよい。

```bash
cd SuilogWidget && for f in *.swift; do case "$f" in SuilogWidgetBundle.swift|SuilogWidget.swift) ;; *) echo "delete $f"; rm "$f";; esac; done; cd ..
```

- [ ] **Step 2: ウィジェットのコードを書く**

`SuilogWidget/SuilogWidgetBundle.swift` を次の内容で置き換える。

```swift
//
//  SuilogWidgetBundle.swift
//  SuilogWidget
//

import WidgetKit
import SwiftUI

@main
struct SuilogWidgetBundle: WidgetBundle {
    var body: some Widget {
        SuilogWidget()
    }
}
```

`SuilogWidget/SuilogWidget.swift` を次の内容で置き換える。

```swift
//
//  SuilogWidget.swift
//  SuilogWidget
//
//  ホーム画面に「訪問の記録」を表示するウィジェット（スイログ Pro の特典）。
//  表示するデータは、アプリが App Group に書き出した WidgetSnapshot を読むだけ。
//

import WidgetKit
import SwiftUI

struct SuilogWidgetEntry: TimelineEntry {
    let date: Date
    /// nil = アプリがまだスナップショットを書き出していない（または読めなかった）
    let snapshot: WidgetSnapshot?
}

struct SuilogWidgetProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> SuilogWidgetEntry {
        SuilogWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SuilogWidgetEntry) -> Void) {
        // ウィジェットギャラリーのプレビューにはサンプルを使う
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder : store.load()
        completion(SuilogWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuilogWidgetEntry>) -> Void) {
        // 更新はアプリからの reloadAllTimelines が中心。念のため 6 時間後にも読み直す
        let entry = SuilogWidgetEntry(date: Date(), snapshot: store.load())
        let nextUpdate = Date().addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct SuilogWidget: Widget {
    let kind = "SuilogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuilogWidgetProvider()) { entry in
            SuilogWidgetView(entry: entry)
        }
        .configurationDisplayName("訪問の記録")
        .description("訪問した水族館の数や、最近の訪問を表示します。（スイログ Pro）")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("小", as: .systemSmall) {
    SuilogWidget()
} timeline: {
    SuilogWidgetEntry(date: Date(), snapshot: .placeholder)
    SuilogWidgetEntry(date: Date(), snapshot: .placeholderLocked)
    SuilogWidgetEntry(date: Date(), snapshot: nil)
}

#Preview("中", as: .systemMedium) {
    SuilogWidget()
} timeline: {
    SuilogWidgetEntry(date: Date(), snapshot: .placeholder)
    SuilogWidgetEntry(date: Date(), snapshot: .placeholderLocked)
    SuilogWidgetEntry(date: Date(), snapshot: nil)
}
```

`SuilogWidget/WidgetColor.swift` を作る。

```swift
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
```

`SuilogWidget/SuilogWidgetView.swift` を作る。

```swift
//
//  SuilogWidgetView.swift
//  SuilogWidget
//

import WidgetKit
import SwiftUI

struct SuilogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SuilogWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if snapshot.isPro {
                    content(snapshot)
                } else {
                    message(icon: "crown.fill", text: "スイログ Pro で使えます")
                }
            } else {
                message(icon: "fish.fill", text: "アプリを開くと表示されます")
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { background }
    }

    // MARK: - 背景（テーマの水槽の色）

    private var background: some View {
        LinearGradient(
            colors: [
                Color(widgetHex: entry.snapshot?.tankTopHex ?? "#A8D8EF"),
                Color(widgetHex: entry.snapshot?.tankBottomHex ?? "#6BBBD8")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Pro の人に見せる内容

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        if family == .systemMedium {
            HStack(alignment: .top, spacing: 16) {
                stats(snapshot)
                Divider().overlay(Color.white.opacity(0.4))
                recentVisits(snapshot)
            }
        } else {
            stats(snapshot)
        }
    }

    private func stats(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("訪問した水族館")
                .font(.caption2)
                .opacity(0.85)
            Text("\(snapshot.visitedAquariumCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("訪問 \(snapshot.visitCount) 回")
                .font(.caption.weight(.medium))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recentVisits(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("最近の訪問")
                .font(.caption2)
                .opacity(0.85)
            if snapshot.recentVisits.isEmpty {
                Text("まだ訪問記録がありません")
                    .font(.caption)
            } else {
                ForEach(Array(snapshot.recentVisits.enumerated()), id: \.offset) { _, visit in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(visit.aquariumName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(visit.visitDate, format: .dateTime.year().month().day())
                            .font(.caption2)
                            .opacity(0.85)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pro ではない / まだデータがない

    private func message(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(text)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: ビルドが通ることと、ウィジェットがアプリに組み込まれたことを確認する**

Run: `xcodebuild -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|warning:.*SuilogWidget|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`

Run: `find ~/Library/Developer/Xcode/DerivedData -path "*Suilog-*/Build/Products/Debug-iphonesimulator/Suilog.app/PlugIns/*.appex" -maxdepth 7`
Expected: `SuilogWidgetExtension.appex`（Xcode が付けた名前）が1つ出る

もしここで `WidgetSnapshot` が見つからないエラーが出たら、Task 7 の手順8（`WidgetSnapshot.swift` のターゲットメンバーシップ）が抜けている。ユーザーに依頼して追加してもらう。

- [ ] **Step 4: ユニットテストが壊れていないことを確認する**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add SuilogWidget
git status --short
git commit -m "feat: ホーム画面ウィジェット「訪問の記録」を追加

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: 最終確認とドキュメントの更新

**Files:**
- Modify: `CLAUDE.md`（テーマの追加手順・ウィジェットの説明）
- Test: 既存のユニットテスト全部、UI テスト1件

**Interfaces:**
- Consumes: Task 1〜8 すべて
- Produces: なし

- [ ] **Step 1: CLAUDE.md を更新する**

`CLAUDE.md` の「Adding New Themes」の節を次のとおり置き換える（Edit ツール）。

```
#### Adding New Themes
1. Add theme definition in `Theme.allThemes`
2. Add product ID in `StoreManager.themeProductIds`
3. Add theme assets in `Assets.xcassets/Themes/[ThemeName]/`
4. Configure product in App Store Connect
```
→
```
#### Adding New Themes
1. Add theme definition in `Theme.allThemes`（無料にするのはオーシャンブルーだけ。新しいテーマは `requiresPro: true`）
2. Add theme assets in `Assets.xcassets/Themes/[ThemeName]/`

テーマは個別には販売しない。スイログ Pro（`com.suilog.pro`、買い切り）を持っていれば、`requiresPro` のテーマがすべて使える。
```

「Theme System」の `StoreManager.swift` の説明の後ろに、次の節を足す。

```
#### スイログ Pro とウィジェット
- **Pro の判定**: `StoreManager.isProUnlocked`（`com.suilog.pro` の所有）だけを入口にする。写真の上限・テーマ・ウィジェットはすべてこれを見る
- **ウィジェット**: `SuilogWidget` ターゲット。表示データはアプリが `WidgetSnapshot`（`Suilog/Shared/WidgetSnapshot.swift`）にして App Group `group.jp.dancho.Suilog` の共有 UserDefaults に書き出し、ウィジェットは読むだけ（SwiftData・`Theme.swift` には依存しない）
- **書き出し**: `ContentView` の `.syncsWidgetSnapshot(...)`。購入状態（権利）の読み込みが終わるまでは書き出さない（`StoreManager.hasLoadedEntitlements`）
- **ローカルでの購入テスト**: `Suilog/Configuration.storekit` をスキームの Run に設定済み。自動テストは `ProPurchaseTests`（StoreKitTest）
```

- [ ] **Step 2: ユニットテスト全部と、テーマストアの UI テストを通す**

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests 2>&1 | grep -E "error:|✘|Test run with|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

Run: `xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogUITests/SuilogUITests/testThemeStoreButton_opensSheet 2>&1 | grep -E "error:|✘|Test Case|\*\* TEST"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: シミュレータでの見た目を確認する**

アプリを入れて起動し、次を目で確認する（`mcp__Claude_Code_iOS_Simulator__control` で操作。商品は読み込めない環境なので、購入そのものは Step 4 でユーザーが確認する）。

- プロフィール → 「テーマを変える」: オーシャンブルーは「使用中」、ゆめかわと16ビットは「Pro」のバッジ。「お得なセット」と「購入を復元」は出ない
- ゆめかわをタップ → プレビューの下に「Pro で使えるようになります」。押すと Pro の購入画面が開き、特典が4つ並ぶ。商品が読み込めない環境では「もう一度読み込む」が出る
- プロフィール → 「スイログ Pro」の説明文が「写真無制限・全テーマ・ウィジェット」

- [ ] **Step 4: ユーザーに Xcode からの動作確認を依頼する**

シミュレータから直接起動したアプリは StoreKit の設定ファイルを使わないため、購入の一連の流れは Xcode の Run で確かめてもらう。

1. Product → Scheme → Edit Scheme → Run → Options の「StoreKit Configuration」が `Configuration.storekit` になっているか確認（空なら選ぶ）。
2. Xcode で `Suilog` を iPhone 17 Pro シミュレータに Run。
3. プロフィール → 「スイログ Pro」→ 600円の購入ボタンが出ること。購入する。
4. 購入後に確認: テーマストアの鍵が外れてゆめかわが選べる / 記録で写真を2枚以上追加できる / ホーム画面を長押し → 「+」→ スイログ →「訪問の記録」が追加できて数字が出る。
5. Xcode のメニュー Debug → StoreKit → Manage Transactions… で購入を取り消す（Refund）。アプリに戻ると、テーマがオーシャンブルーに戻り、ウィジェットが「スイログ Pro で使えます」になる。
6. 「購入を復元」を押すと「復元できる購入が見つかりませんでした」が出る（取り消し後）。

- [ ] **Step 5: コミット**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.mdにProとウィジェットの構成を追記

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: App Store Connect で必要な作業をユーザーに伝える（設計書「リリース準備」と同じ内容）**

- 「スイログ Pro」（`com.suilog.pro`・非消耗型・600円）とチップ3つを登録し、表示名・説明・審査用スクリーンショットを入れる。
- はじめての App 内課金は、アプリ本体と一緒に審査へ提出する（バージョンのページで App 内課金を追加）。
- ゆめかわ・全部入りパックの商品を登録済みなら「販売しない」にする。
- App Group は Xcode の自動署名で登録される想定。Xcode Cloud で署名エラーが出たら、Apple Developer のページで App Group `group.jp.dancho.Suilog` が登録されているかを確認する。

PR は、ユーザーに頼まれてから作る。

---

## Self-Review

**Spec coverage**（設計書の節 → タスク）

| 設計書 | タスク |
|---|---|
| 1. Pro 判定の一本化、`StoreManager` のテーマ商品削除 | Task 1 |
| 1. `Theme.requiresPro`、`ThemeManager.isPro`、Pro が外れたら戻す | Task 1 |
| 1. テーマストア（鍵・Pro への案内・全部入りパック削除） | Task 1 |
| 1. Pro 購入画面の特典の文言 | Task 2 |
| 2. `WidgetSnapshot` とストア | Task 4 |
| 2. 訪問記録からの作成 | Task 5 |
| 2. アプリ側の書き出し（`ContentView` の更新役） | Task 6 |
| 2. ウィジェット本体（小・中・ロック・データなし） | Task 8 |
| 2. 手作業（ターゲット・App Group・メンバーシップ） | Task 7 |
| 3. 再読み込みボタン・復元結果 | Task 2 |
| 3. StoreKit 設定・スキーム・購入テスト | Task 3 |
| 3. App Store Connect の作業 | Task 9 Step 6 |
| 差分（色・復元ボタン・権利の読み込み待ち） | 冒頭「Spec との差分」、Task 1 / 4 / 6 |

**型と名前の整合**: `ThemeManager.updatePro` / `applyEntitlements`（Task 1）→ `SuilogApp`（Task 1）。`StoreManager.hasLoadedEntitlements`（Task 1）→ `ContentView`（Task 6）。`RestoreOutcome`（Task 2）。`WidgetSnapshot` の項目（Task 4）→ 作成（Task 5）→ 書き出し（Task 6）→ 表示（Task 8）で `primaryHex` / `tankTopHex` / `tankBottomHex` / `isPro` / `recentVisits` / `visitedAquariumCount` / `visitCount` を同じ名前で使っている。

**前提として確認できていないこと**
- `StoreKitConfigurationFileReference` の `identifier` のパスの書き方（Task 3 Step 4 と Task 9 Step 4 でユーザーに確認してもらう）
- Xcode 26 のウィジェット拡張のひな形のファイル名とターゲット名（`SuilogWidgetExtension` と想定。Task 7 で実際の名前に合わせる）
- `StoreKitTest` がユニットテストのホスト（アプリ）で動くこと（Task 3 Step 5 で確認する）
- ウィジェットの見た目は、シミュレータで自動では確かめられない（ホーム画面へのウィジェット追加は手操作）。Task 9 Step 4 でユーザーに確認してもらう
