//
//  AquariumSortingTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/01/12.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// 水族館のソート機能をテストする
struct AquariumSortingTests {

    // MARK: - Test Helpers

    /// テスト用のインメモリModelContainerを作成
    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// テスト用の水族館データを作成（ソート用）
    @MainActor
    private func createSortTestAquariums(context: ModelContext) -> [Aquarium] {
        let aquariums = [
            // 北海道（未訪問）
            Aquarium(
                id: UUID(),
                name: "札幌水族館",
                latitude: 43.06,
                longitude: 141.35,
                aquariumDescription: "テスト",
                region: "北海道",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: nil,
                affiliateLink: nil
            ),
            // 関東（訪問済み）
            Aquarium(
                id: UUID(),
                name: "サンシャイン水族館",
                latitude: 35.72,
                longitude: 139.72,
                aquariumDescription: "テスト",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: nil,
                affiliateLink: nil
            ),
            // 関東（未訪問）
            Aquarium(
                id: UUID(),
                name: "新江ノ島水族館",
                latitude: 35.30,
                longitude: 139.48,
                aquariumDescription: "テスト",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: nil,
                affiliateLink: nil
            ),
            // 九州・沖縄（訪問済み）
            Aquarium(
                id: UUID(),
                name: "美ら海水族館",
                latitude: 26.69,
                longitude: 127.88,
                aquariumDescription: "テスト",
                region: "九州・沖縄",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: nil,
                affiliateLink: nil
            ),
            // 近畿（未訪問）
            Aquarium(
                id: UUID(),
                name: "海遊館",
                latitude: 34.65,
                longitude: 135.43,
                aquariumDescription: "テスト",
                region: "近畿",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: nil,
                affiliateLink: nil
            ),
            // 関東（訪問済み） - アルファベット順で先
            Aquarium(
                id: UUID(),
                name: "アクアパーク品川",
                latitude: 35.62,
                longitude: 139.74,
                aquariumDescription: "テスト",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: nil,
                affiliateLink: nil
            )
        ]

        for aquarium in aquariums {
            context.insert(aquarium)
        }

        return aquariums
    }

    /// テスト用の訪問記録を作成
    @MainActor
    private func createSortTestVisitRecords(context: ModelContext, aquariums: [Aquarium]) {
        // サンシャイン、美ら海、アクアパークに訪問記録を追加
        let visitedIndices = [1, 3, 5] // サンシャイン、美ら海、アクアパーク

        for index in visitedIndices where index < aquariums.count {
            let visit = VisitRecord(
                id: UUID(),
                visitDate: Date(),
                memo: "訪問",
                photoData: nil,
                checkInType: .location,
                aquarium: aquariums[index]
            )
            context.insert(visit)
        }
    }

    /// ソート用のヘルパー関数
    private func sortAquariums(
        aquariums: [Aquarium],
        visitRecords: [VisitRecord]
    ) -> [Aquarium] {
        let regionOrder = ["北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"]

        return aquariums.sorted { a, b in
            let aVisited = visitRecords.contains { $0.aquarium?.id == a.id }
            let bVisited = visitRecords.contains { $0.aquarium?.id == b.id }

            // 1. 訪問済みを上に
            if aVisited != bVisited {
                return aVisited
            }

            // 2. 地域順（北から南へ）
            let aRegionIndex = regionOrder.firstIndex(of: a.region) ?? Int.max
            let bRegionIndex = regionOrder.firstIndex(of: b.region) ?? Int.max

            if aRegionIndex != bRegionIndex {
                return aRegionIndex < bRegionIndex
            }

            // 3. 同じ地域内では名前順
            return a.name < b.name
        }
    }

    // MARK: - Visit Status Sort Tests

    @Test("ソート: 訪問済みが未訪問より上に表示される")
    @MainActor
    func testSortVisitedFirst() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createSortTestAquariums(context: context)
        createSortTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())
        let sorted = sortAquariums(aquariums: aquariums, visitRecords: visitRecords)

        // 最初の3つは訪問済み
        #expect(!sorted[0].visits.isEmpty)
        #expect(!sorted[1].visits.isEmpty)
        #expect(!sorted[2].visits.isEmpty)

        // 残りは未訪問
        #expect(sorted[3].visits.isEmpty)
        #expect(sorted[4].visits.isEmpty)
        #expect(sorted[5].visits.isEmpty)
    }

    // MARK: - Region Sort Tests

    @Test("ソート: 地域順（北から南）にソートされる")
    @MainActor
    func testSortByRegion() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createSortTestAquariums(context: context)
        createSortTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())
        let sorted = sortAquariums(aquariums: aquariums, visitRecords: visitRecords)

        // 訪問済みグループ内での地域順（北から南）
        // アクアパーク品川（関東）、サンシャイン（関東）、美ら海（九州・沖縄）
        let visitedAquariums = sorted.prefix(3).map { $0 }
        #expect(visitedAquariums[0].region == "関東")
        #expect(visitedAquariums[1].region == "関東")
        #expect(visitedAquariums[2].region == "九州・沖縄")

        // 未訪問グループ内での地域順（北から南）
        // 札幌（北海道）、新江ノ島（関東）、海遊館（近畿）
        let notVisitedAquariums = sorted.suffix(3).map { $0 }
        #expect(notVisitedAquariums[0].region == "北海道")
        #expect(notVisitedAquariums[1].region == "関東")
        #expect(notVisitedAquariums[2].region == "近畿")
    }

    // MARK: - Name Sort Tests

    @Test("ソート: 同じ地域内では名前順にソートされる")
    @MainActor
    func testSortByNameWithinRegion() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createSortTestAquariums(context: context)
        createSortTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())
        let sorted = sortAquariums(aquariums: aquariums, visitRecords: visitRecords)

        // 訪問済みの関東水族館（アクアパーク、サンシャイン）
        let visitedKanto = sorted.prefix(2).map { $0 }
        #expect(visitedKanto[0].name == "アクアパーク品川") // アルファベット順で先
        #expect(visitedKanto[1].name == "サンシャイン水族館")
    }

    // MARK: - Complete Sort Tests

    @Test("ソート: 完全なソート順序の確認")
    @MainActor
    func testCompleteSort() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createSortTestAquariums(context: context)
        createSortTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())
        let sorted = sortAquariums(aquariums: aquariums, visitRecords: visitRecords)

        // 期待される順序:
        // 1. アクアパーク品川（訪問済み、関東、名前順）
        // 2. サンシャイン水族館（訪問済み、関東、名前順）
        // 3. 美ら海水族館（訪問済み、九州・沖縄）
        // 4. 札幌水族館（未訪問、北海道）
        // 5. 新江ノ島水族館（未訪問、関東）
        // 6. 海遊館（未訪問、近畿）

        let expectedOrder = [
            "アクアパーク品川",
            "サンシャイン水族館",
            "美ら海水族館",
            "札幌水族館",
            "新江ノ島水族館",
            "海遊館"
        ]

        let actualOrder = sorted.map { $0.name }
        #expect(actualOrder == expectedOrder)
    }

    // MARK: - Edge Cases

    @Test("ソート: すべて訪問済み")
    @MainActor
    func testSortAllVisited() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createSortTestAquariums(context: context)

        // すべての水族館に訪問記録を追加
        for aquarium in aquariums {
            let visit = VisitRecord(
                id: UUID(),
                visitDate: Date(),
                memo: "訪問",
                photoData: nil,
                checkInType: .location,
                aquarium: aquarium
            )
            context.insert(visit)
        }

        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())
        let sorted = sortAquariums(aquariums: aquariums, visitRecords: visitRecords)

        // すべて訪問済みなので、地域順→名前順のみでソート
        // 期待される順序（地域の北から南、同じ地域内は名前順）:
        // 1. 札幌水族館（北海道）
        // 2. アクアパーク品川（関東）
        // 3. サンシャイン水族館（関東）
        // 4. 新江ノ島水族館（関東）
        // 5. 海遊館（近畿）
        // 6. 美ら海水族館（九州・沖縄）

        #expect(sorted[0].name == "札幌水族館")
        #expect(sorted[1].name == "アクアパーク品川")
        #expect(sorted[2].name == "サンシャイン水族館")
        #expect(sorted[3].name == "新江ノ島水族館")
        #expect(sorted[4].name == "海遊館")
        #expect(sorted[5].name == "美ら海水族館")
    }

    @Test("ソート: すべて未訪問")
    @MainActor
    func testSortAllNotVisited() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createSortTestAquariums(context: context)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())
        let sorted = sortAquariums(aquariums: aquariums, visitRecords: visitRecords)

        // すべて未訪問なので、地域順→名前順のみでソート
        #expect(sorted[0].name == "札幌水族館")
        #expect(sorted[1].name == "アクアパーク品川")
        #expect(sorted[2].name == "サンシャイン水族館")
        #expect(sorted[3].name == "新江ノ島水族館")
        #expect(sorted[4].name == "海遊館")
        #expect(sorted[5].name == "美ら海水族館")
    }
}
