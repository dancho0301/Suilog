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
