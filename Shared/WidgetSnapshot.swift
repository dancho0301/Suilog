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
