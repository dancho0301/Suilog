//
//  StatisticsTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/01/12.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// 統計計算のロジックをテストする
@Suite(.serialized)
struct StatisticsTests {

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
                name: "北海道水族館",
                latitude: 43.06,
                longitude: 141.35,
                description: "テスト用水族館",
                region: "北海道",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "北海道札幌市",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "東北水族館",
                latitude: 38.26,
                longitude: 140.87,
                description: "テスト用水族館",
                region: "東北",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "宮城県仙台市",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "関東水族館1",
                latitude: 35.68,
                longitude: 139.76,
                description: "テスト用水族館",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "東京都",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "関東水族館2",
                latitude: 35.44,
                longitude: 139.63,
                description: "テスト用水族館",
                region: "関東",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "神奈川県",
                affiliateLink: nil
            ),
            Aquarium(
                id: UUID(),
                name: "九州水族館",
                latitude: 33.59,
                longitude: 130.42,
                description: "テスト用水族館",
                region: "九州・沖縄",
                representativeFish: "fish.fill",
                fishIconSize: 3,
                address: "福岡県",
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
    private func createTestVisitRecords(context: ModelContext, aquariums: [Aquarium]) -> [VisitRecord] {
        let calendar = Calendar.current
        let now = Date()

        var visitRecords: [VisitRecord] = []

        // 北海道水族館: 訪問済み（2回）
        if aquariums.count > 0 {
            let visit1 = VisitRecord(
                id: UUID(),
                visitDate: calendar.date(byAdding: .month, value: -3, to: now)!,
                memo: "初めての訪問",
                photoData: nil,
                checkInType: .location,
                aquarium: aquariums[0]
            )
            let visit2 = VisitRecord(
                id: UUID(),
                visitDate: calendar.date(byAdding: .month, value: -1, to: now)!,
                memo: "2回目の訪問",
                photoData: nil,
                checkInType: .manual,
                aquarium: aquariums[0]
            )
            context.insert(visit1)
            context.insert(visit2)
            visitRecords.append(contentsOf: [visit1, visit2])
        }

        // 関東水族館1: 訪問済み（1回）
        if aquariums.count > 2 {
            let visit3 = VisitRecord(
                id: UUID(),
                visitDate: calendar.date(byAdding: .month, value: -2, to: now)!,
                memo: "関東訪問",
                photoData: nil,
                checkInType: .location,
                aquarium: aquariums[2]
            )
            context.insert(visit3)
            visitRecords.append(visit3)
        }

        return visitRecords
    }

    // MARK: - Achievement Rate Tests

    @Test("達成率計算: 訪問済み水族館あり")
    @MainActor
    func testAchievementRateWithVisits() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        _ = createTestVisitRecords(context: context, aquariums: aquariums)

        try context.save()

        // 5館中2館訪問済み（北海道と関東1）
        let visitedCount = aquariums.filter { !$0.visits.isEmpty }.count
        let achievementRate = Double(visitedCount) / Double(aquariums.count)

        #expect(visitedCount == 2)
        #expect(achievementRate == 0.4) // 40%
    }

    @Test("達成率計算: 訪問記録なし")
    @MainActor
    func testAchievementRateWithoutVisits() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        try context.save()

        let visitedCount = aquariums.filter { !$0.visits.isEmpty }.count
        let achievementRate = Double(visitedCount) / Double(aquariums.count)

        #expect(visitedCount == 0)
        #expect(achievementRate == 0.0) // 0%
    }

    // MARK: - Regional Statistics Tests

    @Test("地域別訪問統計: 正しい地域別カウント")
    @MainActor
    func testRegionalStats() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        _ = createTestVisitRecords(context: context, aquariums: aquariums)

        try context.save()

        let regionOrder = ["北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"]
        let regionalStats = regionOrder.map { region in
            let regionAquariums = aquariums.filter { $0.region == region }
            let visitedInRegion = regionAquariums.filter { !$0.visits.isEmpty }.count
            return (region: region, visitedCount: visitedInRegion, totalCount: regionAquariums.count)
        }

        // 北海道: 1/1 訪問済み
        let hokkaido = regionalStats.first { $0.region == "北海道" }!
        #expect(hokkaido.visitedCount == 1)
        #expect(hokkaido.totalCount == 1)

        // 東北: 0/1 訪問済み
        let tohoku = regionalStats.first { $0.region == "東北" }!
        #expect(tohoku.visitedCount == 0)
        #expect(tohoku.totalCount == 1)

        // 関東: 1/2 訪問済み
        let kanto = regionalStats.first { $0.region == "関東" }!
        #expect(kanto.visitedCount == 1)
        #expect(kanto.totalCount == 2)

        // 九州・沖縄: 0/1 訪問済み
        let kyushu = regionalStats.first { $0.region == "九州・沖縄" }!
        #expect(kyushu.visitedCount == 0)
        #expect(kyushu.totalCount == 1)
    }

    // MARK: - Monthly Statistics Tests

    @Test("月別訪問統計: 正しい月別カウント")
    @MainActor
    func testMonthlyStats() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        let visitRecords = createTestVisitRecords(context: context, aquariums: aquariums)

        try context.save()

        let calendar = Calendar.current
        let now = Date()

        // 3ヶ月前の訪問数をカウント（北海道の1回目）
        guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else {
            Issue.record("Failed to create date")
            return
        }
        let threeMonthsAgoComponents = calendar.dateComponents([.year, .month], from: threeMonthsAgo)

        let visitsThreeMonthsAgo = visitRecords.filter { visit in
            let visitComponents = calendar.dateComponents([.year, .month], from: visit.visitDate)
            return visitComponents.year == threeMonthsAgoComponents.year &&
                   visitComponents.month == threeMonthsAgoComponents.month
        }.count

        #expect(visitsThreeMonthsAgo == 1)

        // 1ヶ月前の訪問数をカウント（北海道の2回目）
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
            Issue.record("Failed to create date")
            return
        }
        let oneMonthAgoComponents = calendar.dateComponents([.year, .month], from: oneMonthAgo)

        let visitsOneMonthAgo = visitRecords.filter { visit in
            let visitComponents = calendar.dateComponents([.year, .month], from: visit.visitDate)
            return visitComponents.year == oneMonthAgoComponents.year &&
                   visitComponents.month == oneMonthAgoComponents.month
        }.count

        #expect(visitsOneMonthAgo == 1)
    }

    // MARK: - Top Aquariums Tests

    @Test("よく訪れる水族館: 訪問回数順にソート")
    @MainActor
    func testTopAquariums() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        _ = createTestVisitRecords(context: context, aquariums: aquariums)

        try context.save()

        let topAquariums = aquariums
            .filter { !$0.visits.isEmpty }
            .map { ($0, $0.visits.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }

        // 北海道水族館が1位（2回訪問）
        #expect(topAquariums.count == 2)
        #expect(topAquariums[0].0.name == "北海道水族館")
        #expect(topAquariums[0].1 == 2)

        // 関東水族館1が2位（1回訪問）
        #expect(topAquariums[1].0.name == "関東水族館1")
        #expect(topAquariums[1].1 == 1)
    }

    // MARK: - Top Region Tests

    @Test("最も訪れた地域: 訪問回数が最多の地域")
    @MainActor
    func testTopRegion() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        let visitRecords = createTestVisitRecords(context: context, aquariums: aquariums)

        try context.save()

        let regionCounts = Dictionary(grouping: visitRecords.compactMap { $0.aquarium?.region }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        guard let topRegion = regionCounts.first else {
            Issue.record("No top region found")
            return
        }

        // 北海道が最多（2回訪問）
        #expect(topRegion.key == "北海道")
        #expect(topRegion.value == 2)
    }

    // MARK: - Check-In Type Statistics Tests

    @Test("チェックイン種別集計: 正しいカウント")
    @MainActor
    func testCheckInTypeStats() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquariums = createTestAquariums(context: context)
        let visitRecords = createTestVisitRecords(context: context, aquariums: aquariums)

        try context.save()

        let locationCheckIns = visitRecords.filter { $0.checkInType == .location }.count
        let manualCheckIns = visitRecords.filter { $0.checkInType == .manual }.count

        // 位置情報: 2回、手動: 1回
        #expect(locationCheckIns == 2)
        #expect(manualCheckIns == 1)
        #expect(visitRecords.count == 3)
    }
}
