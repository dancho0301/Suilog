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
