# スイログ Pro を課金の柱にする設計

- 日付: 2026-10-01
- 状態: 承認済み（実装計画待ち）

## 目的

課金要素を「実際に売れて、払う価値がある」状態にしてから App Store に提出する。
課金の柱は買い切りの **スイログ Pro** に一本化する。

### 決めたこと

| 項目 | 決定 |
|---|---|
| 課金の柱 | スイログ Pro（買い切り・600円のまま） |
| Pro の特典 | 写真を無制限に保存（既存）／すべてのテーマ／ホーム画面ウィジェット（訪問の記録） |
| テーマの販売 | Pro に一本化。個別テーマ（ゆめかわ）と全部入りパックは販売しない |
| 無料のテーマ | オーシャンブルーのみ。ゆめかわ・16ビットは Pro で解放 |
| 既存利用者への配慮 | 不要（テーマを無料で配ったバージョンはストア未公開） |
| チップ（応援課金） | 現状のまま残す（160円・370円・700円の消耗型） |
| ウィジェットのデータ共有 | 案A: アプリが表示用データを App Group の共有 UserDefaults に書き出す |

### やらないこと

- 生き物図鑑の上級機能
- マイ水槽のカスタマイズ（生き物の選択・表示数の上限変更）
- mint・coral テーマの再有効化（現状どおり無効のまま）
- サブスクリプション

## 1. Pro の判定とテーマの解放

### Pro の判定

- `StoreManager.isProUnlocked`（`com.suilog.pro` を所有しているか）を Pro 判定の唯一の入口にする。
  写真の上限・テーマ・ウィジェットはすべてこれを参照する。
- `StoreManager` から次を削除する: `themeProductIds`、`allThemesPackId`、`resolveIsPurchased`、`isPurchased(_:)`。
  `allProductIds` は Pro とチップのみになる。

### テーマのモデル

- `Theme` の `productId` と `isDefault` を廃止し、`requiresPro: Bool` に置き換える。
  - オーシャンブルー: `false`
  - ゆめかわ・16ビット（・無効中の mint・coral）: `true`
- `Theme` は `Codable` だが、永続化しているのはテーマ ID のみのため、プロパティ変更による移行は不要。
- `ThemeManager` は購入済み Product ID の一覧ではなく `isPro: Bool` を受け取る。
  - `isUnlocked(_:)` は `!theme.requiresPro || isPro`。
  - `updatePro(_:)`（旧 `updatePurchasedProducts(_:)`）で Pro 状態を更新し、選択中のテーマがロックされていればオーシャンブルーに戻す。
  - iCloud から Pro テーマへの変更が届いても、ロック中なら反映しない（現状と同じ）。
- `SuilogApp` は `storeManager.$purchasedProductIds` の変化を受けて `themeManager.updatePro(storeManager.isProUnlocked)` を呼ぶ。

### テーマストア画面（ThemeStoreView）

- ロック中のテーマもタップでプレビューできる（現状どおり）。
- ロック中のテーマのプレビューでは、「このテーマを使用する」の代わりに「Pro で使えるようになります」ボタンを表示し、押すと ProStoreView を開く。
- 全部入りパックの行を削除する。

### Pro の購入画面（ProStoreView）

- 特典の説明を実際の中身に合わせる:
  - 写真を無制限に保存
  - すべてのテーマが使える
  - ホーム画面ウィジェット
  - 開発を応援
- 「今後の Pro 機能をすべて利用（ウィジェットや図鑑の上級機能など）」は削除する。

## 2. ホーム画面ウィジェット（訪問の記録）

### 共有データ `WidgetSnapshot`

- `Codable` な値型。中身:
  - `visitedAquariumCount: Int`（訪問した水族館の数）
  - `visitCount: Int`（訪問回数）
  - `recentVisits: [RecentVisit]`（最近の訪問 最大3件。水族館名・訪問日・チェックインの種類）
  - `themeId: String`
  - `isPro: Bool`
  - `updatedAt: Date`
- 訪問記録の配列・テーマ ID・Pro 状態からスナップショットを作る純粋関数を用意する（テスト対象）。
- App Group `group.jp.dancho.Suilog` の共有 UserDefaults に JSON で保存・読み込みする `WidgetSnapshotStore` を用意する。
- これらは `Shared/` フォルダに置き、アプリとウィジェットの両ターゲットに含める。

### アプリ側の書き出し

- `ContentView` に更新役（ビュー修飾子）を1つ置く。訪問記録の `@Query`、現在のテーマ、Pro 状態を監視し、
  スナップショットの中身が変わったときだけ保存して `WidgetCenter.shared.reloadAllTimelines()` を呼ぶ。
- 記録の追加・編集・削除、テーマ変更、購入、アプリ起動中の iCloud 同期による変化をすべてここで拾う。
- 既知の制約: 別端末から同期された記録は、その端末でアプリを開くまでウィジェットに反映されない。

### ウィジェット本体（SuilogWidget ターゲット）

- 対応サイズ:
  - 小: 訪問館数と訪問回数
  - 中: 小の内容 ＋ 最近の訪問3件
- 背景はテーマの水槽の色（`tankTop`〜`tankBottom` のグラデーション）。背景画像は使わない。
  このため `Theme.swift` をウィジェットのターゲットにも含める。
- Pro でない場合は「スイログ Pro で使えます」と表示する。タップでアプリを開く。
- スナップショットがまだない場合（アプリ未起動など）は「アプリを開くと表示されます」と表示する。
- 更新はアプリからの `reloadAllTimelines` が中心。タイムラインは数時間後の再読み込みを指定しておく。

### 手作業（ユーザー）

プロジェクトファイルへのターゲット追加は手編集だと壊れやすいため、Xcode の画面で行う:

1. File → New → Target → Widget Extension で `SuilogWidget` を作成（Live Activity・Configuration Intent は含めない）。
2. アプリとウィジェットの両ターゲットに App Groups を追加し、`group.jp.dancho.Suilog` を登録。

ウィジェットのコードはすべてこちらで実装する。

## 3. 購入の流れ・テスト・リリース準備

### 購入の流れとエラー処理

- `StoreManager` の購入・復元・`Transaction.updates` の監視は現状を利用する。
- 購入画面で商品を読み込めなかったとき、メッセージの下に「もう一度読み込む」ボタンを表示する。
- 復元後に結果を表示する:「Pro を復元しました」／「復元できる購入が見つかりませんでした」。
- Pro 購入の直後に、テーマの解放・写真上限の解除・ウィジェットの表示が反映される（1 と 2 の仕組みで自動的に反映）。

### ローカルでのテスト

- スキームの Run に `Suilog/Configuration.storekit` を設定し、シミュレータで購入・復元を試せるようにする。
- `Configuration.storekit` から ゆめかわ・全部入りパックを削除する（Pro とチップ3つのみ）。
- ユニットテスト:
  - `ThemeTests`: Pro なしではオーシャンブルーのみ、Pro ありでは全テーマ、Pro を失うとオーシャンブルーに戻る。
  - `StoreManagerTests` / `StoreProductTests`: 削除した商品・関数に関するテストを整理し、`allProductIds` が Pro とチップのみであることを確認。
  - `WidgetSnapshotTests`: 件数の数え方、最近3件の選び方（新しい順）、JSON の往復。
- シミュレータでの確認: 購入前はロック → Pro 購入 → テーマ選択・写真の複数追加・ウィジェット表示 → 購入の取り消し → 元に戻る。

### リリース準備（ユーザー作業・App Store Connect）

- 「スイログ Pro」（`com.suilog.pro`・非消耗型・600円）とチップ3つを登録し、表示名・説明・審査用スクリーンショットを入れる。
- はじめての App 内課金はアプリ本体と一緒に審査へ提出する（バージョンのページで App 内課金を追加）。
- ゆめかわ・全部入りパックの商品を登録済みなら「販売しない」にする。
- App Group は Xcode の自動署名で登録される想定。
