//
//  AquariumFilteringTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/01/12.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// 水族館のフィルタリング機能をテストする
@Suite(.serialized)
struct AquariumFilteringTests {

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

    /// テスト用の水族館データを作成
    @MainActor
    private func createTestAquariums(context: ModelContext) -> [Aquarium] {
        let aquariums = [
            Aquarium(
                id: UUID(),
                name: "サンシャイン水族館",
                latitude: 35.72,
                longitude: 139.72,
                description: "都会のオアシス",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "東京都豊島区",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "新江ノ島水族館",
                latitude: 35.30,
                longitude: 139.48,
                description: "湘南の海",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "神奈川県藤沢市",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "海遊館",
                latitude: 34.65,
                longitude: 135.43,
                description: "世界最大級",
                region: "近畿",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "大阪府大阪市",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "旭山動物園",
                latitude: 43.77,
                longitude: 142.48,
                description: "行動展示",
                region: "北海道",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "北海道旭川市",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "美ら海水族館",
                latitude: 26.69,
                longitude: 127.88,
                description: "ジンベエザメ",
                region: "九州・沖縄",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "沖縄県本部町",
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
    private func createTestVisitRecords(context: ModelContext, aquariums: [Aquarium]) {
        // サンシャイン水族館と海遊館に訪問記録を追加
        if aquariums.count >= 3 {
            let visit1 = VisitRecord(
                id: UUID(),
                visitDate: Date(),
                memo: "訪問1",
                photoData: nil,
                checkInType: .location,
                aquarium: aquariums[0] // サンシャイン
            )
            let visit2 = VisitRecord(
                id: UUID(),
                visitDate: Date(),
                memo: "訪問2",
                photoData: nil,
                checkInType: .manual,
                aquarium: aquariums[2] // 海遊館
            )
            context.insert(visit1)
            context.insert(visit2)
        }
    }

    /// フィルタリング用のヘルパー関数
    private func applyFilters(
        aquariums: [Aquarium],
        visitRecords: [VisitRecord],
        searchText: String = "",
        selectedRegions: Set<String> = [],
        visitStatusFilter: VisitStatusFilter = .all
    ) -> [Aquarium] {
        return aquariums
            .filter { aquarium in
                // 検索テキストフィルタ
                if !searchText.isEmpty {
                    return aquarium.name.localizedCaseInsensitiveContains(searchText)
                }
                return true
            }
            .filter { aquarium in
                // 地域フィルタ
                if !selectedRegions.isEmpty {
                    return selectedRegions.contains(aquarium.region)
                }
                return true
            }
            .filter { aquarium in
                // 訪問ステータスフィルタ
                let hasVisited = visitRecords.contains { $0.aquarium?.id == aquarium.id }
                switch visitStatusFilter {
                case .all:
                    return true
                case .visited:
                    return hasVisited
                case .notVisited:
                    return !hasVisited
                }
            }
    }

    /// テスト用の訪問ステータスフィルタ列挙型
    enum VisitStatusFilter {
        case all
        case visited
        case notVisited
    }

    // MARK: - Search Text Filter Tests

    @Test("検索フィルタ: 水族館名で検索")
    @MainActor
    func testSearchByName() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // "サンシャイン"で検索
        let result = applyFilters(aquariums: aquariums, visitRecords: visitRecords, searchText: "サンシャイン")
        #expect(result.count == 1)
        #expect(result.first?.name == "サンシャイン水族館")
    }

    @Test("検索フィルタ: マッチなし")
    @MainActor
    func testSearchNoMatch() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        let result = applyFilters(aquariums: aquariums, visitRecords: visitRecords, searchText: "存在しない水族館")
        #expect(result.isEmpty)
    }

    // MARK: - Region Filter Tests

    @Test("地域フィルタ: 単一地域で絞り込み")
    @MainActor
    func testFilterBySingleRegion() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // 関東のみ
        let result1 = applyFilters(aquariums: aquariums, visitRecords: visitRecords, selectedRegions: ["関東"])
        #expect(result1.count == 2) // サンシャイン、新江ノ島

        // 北海道のみ
        let result2 = applyFilters(aquariums: aquariums, visitRecords: visitRecords, selectedRegions: ["北海道"])
        #expect(result2.count == 1)
        #expect(result2.first?.name == "旭山動物園")

        // 九州・沖縄のみ
        let result3 = applyFilters(aquariums: aquariums, visitRecords: visitRecords, selectedRegions: ["九州・沖縄"])
        #expect(result3.count == 1)
        #expect(result3.first?.name == "美ら海水族館")
    }

    @Test("地域フィルタ: 複数地域で絞り込み")
    @MainActor
    func testFilterByMultipleRegions() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // 関東と近畿
        let result = applyFilters(aquariums: aquariums, visitRecords: visitRecords, selectedRegions: ["関東", "近畿"])
        #expect(result.count == 3) // サンシャイン、新江ノ島、海遊館

        let resultNames = result.map { $0.name }.sorted()
        #expect(resultNames.contains("サンシャイン水族館"))
        #expect(resultNames.contains("新江ノ島水族館"))
        #expect(resultNames.contains("海遊館"))
    }

    // MARK: - Visit Status Filter Tests

    @Test("訪問ステータスフィルタ: 訪問済みのみ")
    @MainActor
    func testFilterByVisitedStatus() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        let result = applyFilters(aquariums: aquariums, visitRecords: visitRecords, visitStatusFilter: .visited)
        #expect(result.count == 2) // サンシャイン、海遊館

        let resultNames = result.map { $0.name }.sorted()
        #expect(resultNames.contains("サンシャイン水族館"))
        #expect(resultNames.contains("海遊館"))
    }

    @Test("訪問ステータスフィルタ: 未訪問のみ")
    @MainActor
    func testFilterByNotVisitedStatus() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        let result = applyFilters(aquariums: aquariums, visitRecords: visitRecords, visitStatusFilter: .notVisited)
        #expect(result.count == 3) // 新江ノ島、旭山、美ら海

        let resultNames = result.map { $0.name }.sorted()
        #expect(resultNames.contains("新江ノ島水族館"))
        #expect(resultNames.contains("旭山動物園"))
        #expect(resultNames.contains("美ら海水族館"))
    }

    @Test("訪問ステータスフィルタ: すべて表示")
    @MainActor
    func testFilterByAllStatus() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        let result = applyFilters(aquariums: aquariums, visitRecords: visitRecords, visitStatusFilter: .all)
        #expect(result.count == 5) // すべて
    }

    // MARK: - Combined Filter Tests

    @Test("複合フィルタ: 検索 + 地域")
    @MainActor
    func testCombinedSearchAndRegion() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // "水族館"で検索 + 関東地域
        let result = applyFilters(
            aquariums: aquariums,
            visitRecords: visitRecords,
            searchText: "水族館",
            selectedRegions: ["関東"]
        )
        #expect(result.count == 2) // サンシャイン、新江ノ島

        let resultNames = result.map { $0.name }.sorted()
        #expect(resultNames.contains("サンシャイン水族館"))
        #expect(resultNames.contains("新江ノ島水族館"))
    }

    @Test("複合フィルタ: 検索 + 訪問ステータス")
    @MainActor
    func testCombinedSearchAndVisitStatus() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // "水族館"で検索 + 訪問済み
        let result = applyFilters(
            aquariums: aquariums,
            visitRecords: visitRecords,
            searchText: "水族館",
            visitStatusFilter: .visited
        )
        #expect(result.count == 1) // サンシャインのみ（海遊館は"水族館"を含まない）
        #expect(result.first?.name == "サンシャイン水族館")
    }

    @Test("複合フィルタ: 地域 + 訪問ステータス")
    @MainActor
    func testCombinedRegionAndVisitStatus() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // 関東 + 訪問済み
        let result1 = applyFilters(
            aquariums: aquariums,
            visitRecords: visitRecords,
            selectedRegions: ["関東"],
            visitStatusFilter: .visited
        )
        #expect(result1.count == 1) // サンシャインのみ
        #expect(result1.first?.name == "サンシャイン水族館")

        // 関東 + 未訪問
        let result2 = applyFilters(
            aquariums: aquariums,
            visitRecords: visitRecords,
            selectedRegions: ["関東"],
            visitStatusFilter: .notVisited
        )
        #expect(result2.count == 1) // 新江ノ島のみ
        #expect(result2.first?.name == "新江ノ島水族館")
    }

    @Test("複合フィルタ: 検索 + 地域 + 訪問ステータス")
    @MainActor
    func testCombinedAllFilters() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // "サンシャイン"で検索 + 関東 + 訪問済み
        let result = applyFilters(
            aquariums: aquariums,
            visitRecords: visitRecords,
            searchText: "サンシャイン",
            selectedRegions: ["関東"],
            visitStatusFilter: .visited
        )
        #expect(result.count == 1)
        #expect(result.first?.name == "サンシャイン水族館")
    }

    @Test("複合フィルタ: すべてのフィルタでマッチなし")
    @MainActor
    func testCombinedFiltersNoMatch() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        createTestVisitRecords(context: context, aquariums: aquariums)
        try context.save()

        let visitRecords = try context.fetch(FetchDescriptor<VisitRecord>())

        // "水族館"で検索 + 北海道 + 訪問済み（旭山動物園は未訪問）
        let result = applyFilters(
            aquariums: aquariums,
            visitRecords: visitRecords,
            searchText: "水族館",
            selectedRegions: ["北海道"],
            visitStatusFilter: .visited
        )
        #expect(result.isEmpty)
    }
}
