//
//  CreatureTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/13.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// 生き物マスター（Creature）のデコードと CreatureStore のテスト
@Suite
struct CreatureTests {

    // MARK: - デコード

    @Test("creatures.json 形式のエントリをデコードできる")
    func testDecodeCreature() throws {
        let json = """
        {
            "id": "african_penguin",
            "name": "ケープペンギン",
            "nameEn": "African Penguin",
            "emoji": "🐧",
            "category": "bird"
        }
        """
        let creature = try JSONDecoder().decode(Creature.self, from: Data(json.utf8))
        #expect(creature.id == "african_penguin")
        #expect(creature.name == "ケープペンギン")
        #expect(creature.category == .bird)
    }

    @Test("未知のカテゴリは .other にフォールバックする")
    func testUnknownCategoryFallback() throws {
        let json = """
        { "id": "x", "name": "謎の生き物", "nameEn": "Unknown", "emoji": "👾", "category": "alien" }
        """
        let creature = try JSONDecoder().decode(Creature.self, from: Data(json.utf8))
        #expect(creature.category == .other)
    }

    @Test("CreatureResponse をデコードできる")
    func testDecodeResponse() throws {
        let json = """
        {
            "version": 4,
            "creatures": [
                { "id": "a", "name": "あ", "nameEn": "A", "emoji": "🐟", "category": "fish" },
                { "id": "b", "name": "い", "nameEn": "B", "emoji": "🦭", "category": "mammal" }
            ]
        }
        """
        let response = try JSONDecoder().decode(CreatureResponse.self, from: Data(json.utf8))
        #expect(response.version == 4)
        #expect(response.creatures.count == 2)
    }

    // MARK: - CreatureStore（バンドルJSON）

    @Test("バンドルされたcreatures.jsonが読み込める")
    @MainActor
    func testStoreLoadsBundledData() {
        let store = CreatureStore()
        // バンドルにJSONが含まれていれば104種前後が読める
        #expect(store.totalCount > 0)
        // IDルックアップが機能する
        if let first = store.creatures.first {
            #expect(store.creature(for: first.id)?.id == first.id)
        }
    }

    @Test("カテゴリ別グループが表示順にソートされている")
    @MainActor
    func testGroupedByCategorySorted() {
        let store = CreatureStore()
        guard !store.creatures.isEmpty else { return }
        let groups = store.groupedByCategory
        let orders = groups.map { $0.category.sortOrder }
        #expect(orders == orders.sorted())
    }
}

/// 生き物コレクション（CreatureSighting）のロジックテスト
@Suite(.serialized)
struct CreatureCollectionTests {

    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([Aquarium.self, VisitRecord.self, CreatureSighting.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("完了率の計算")
    func testCompletionRate() {
        #expect(CreatureCollection.completionRate(seenCount: 0, totalCount: 104) == 0)
        #expect(CreatureCollection.completionRate(seenCount: 52, totalCount: 104) == 0.5)
        #expect(CreatureCollection.completionRate(seenCount: 104, totalCount: 104) == 1.0)
        // 0除算しない
        #expect(CreatureCollection.completionRate(seenCount: 5, totalCount: 0) == 0)
        // 1.0を超えない
        #expect(CreatureCollection.completionRate(seenCount: 200, totalCount: 104) == 1.0)
    }

    @Test("markSeenで記録され、重複追加されない")
    @MainActor
    func testMarkSeenDeduplicates() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        var existing = try context.fetch(FetchDescriptor<CreatureSighting>())
        let added1 = CreatureCollection.markSeen(creatureId: "penguin", aquariumName: "テスト水族館", context: context, existing: existing)
        try context.save()
        #expect(added1 == true)

        // 2回目は重複追加しない
        existing = try context.fetch(FetchDescriptor<CreatureSighting>())
        let added2 = CreatureCollection.markSeen(creatureId: "penguin", context: context, existing: existing)
        try context.save()
        #expect(added2 == false)

        let all = try context.fetch(FetchDescriptor<CreatureSighting>())
        #expect(all.count == 1)
        #expect(all.first?.aquariumName == "テスト水族館")
    }

    @Test("unmarkで記録が削除される")
    @MainActor
    func testUnmark() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        CreatureCollection.markSeen(creatureId: "shark", context: context, existing: [])
        try context.save()

        let existing = try context.fetch(FetchDescriptor<CreatureSighting>())
        #expect(CreatureCollection.isSeen("shark", in: existing))

        CreatureCollection.unmark(creatureId: "shark", context: context, existing: existing)
        try context.save()

        let after = try context.fetch(FetchDescriptor<CreatureSighting>())
        #expect(after.isEmpty)
    }

    @Test("seenIds が目撃済みIDの集合を返す")
    func testSeenIds() {
        let sightings = [
            CreatureSighting(creatureId: "a"),
            CreatureSighting(creatureId: "b"),
            CreatureSighting(creatureId: "a")
        ]
        #expect(CreatureCollection.seenIds(from: sightings) == ["a", "b"])
    }
}
