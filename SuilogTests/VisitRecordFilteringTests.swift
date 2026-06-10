//
//  VisitRecordFilteringTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/11.
//
//  記録タブ（PassportView）の検索・絞り込みロジックを再現してテストする。
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// 訪問記録の検索・絞り込みロジックのテスト
@Suite(.serialized)
struct VisitRecordFilteringTests {

    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// テスト用の記録セットを作成
    /// - サンシャイン水族館: 2024年・ゴールド・メモ「イルカが最高」
    /// - 海遊館: 2025年・シルバー・メモ「ジンベエザメ」
    /// - 美ら海水族館: 2025年・ゴールド・メモなし
    @MainActor
    private func createTestRecords(context: ModelContext) -> [VisitRecord] {
        let sunshine = Aquarium(name: "サンシャイン水族館", latitude: 35.72, longitude: 139.72, description: "", region: "関東")
        let kaiyukan = Aquarium(name: "海遊館", latitude: 34.65, longitude: 135.43, description: "", region: "近畿")
        let churaumi = Aquarium(name: "美ら海水族館", latitude: 26.69, longitude: 127.88, description: "", region: "九州・沖縄")
        [sunshine, kaiyukan, churaumi].forEach { context.insert($0) }

        var components2024 = DateComponents(year: 2024, month: 6, day: 1)
        var components2025a = DateComponents(year: 2025, month: 3, day: 15)
        var components2025b = DateComponents(year: 2025, month: 8, day: 20)
        components2024.timeZone = TimeZone.current
        components2025a.timeZone = TimeZone.current
        components2025b.timeZone = TimeZone.current
        let calendar = Calendar.current

        let records = [
            VisitRecord(
                visitDate: calendar.date(from: components2024)!,
                memo: "イルカが最高",
                checkInType: .location,
                aquarium: sunshine
            ),
            VisitRecord(
                visitDate: calendar.date(from: components2025a)!,
                memo: "ジンベエザメ",
                checkInType: .manual,
                aquarium: kaiyukan
            ),
            VisitRecord(
                visitDate: calendar.date(from: components2025b)!,
                memo: "",
                checkInType: .location,
                aquarium: churaumi
            )
        ]
        records.forEach { context.insert($0) }
        try? context.save()
        return records
    }

    /// PassportViewのfilteredRecordsと同じロジック
    private func filterRecords(
        _ records: [VisitRecord],
        searchText: String = "",
        checkInType: CheckInType? = nil,
        year: Int? = nil
    ) -> [VisitRecord] {
        records.filter { visit in
            if !searchText.isEmpty {
                let nameMatch = visit.aquarium?.name.localizedCaseInsensitiveContains(searchText) ?? false
                let memoMatch = visit.memo.localizedCaseInsensitiveContains(searchText)
                guard nameMatch || memoMatch else { return false }
            }
            if let checkInType, visit.checkInType != checkInType {
                return false
            }
            if let year,
               Calendar.current.component(.year, from: visit.visitDate) != year {
                return false
            }
            return true
        }
    }

    // MARK: - テキスト検索

    @Test("水族館名で検索できる")
    @MainActor
    func testSearchByAquariumName() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        let result = filterRecords(records, searchText: "海遊館")
        #expect(result.count == 1)
        #expect(result.first?.aquarium?.name == "海遊館")
    }

    @Test("メモで検索できる")
    @MainActor
    func testSearchByMemo() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        let result = filterRecords(records, searchText: "イルカ")
        #expect(result.count == 1)
        #expect(result.first?.aquarium?.name == "サンシャイン水族館")
    }

    @Test("一致しない検索語では0件")
    @MainActor
    func testSearchNoMatch() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        #expect(filterRecords(records, searchText: "ペンギン").isEmpty)
    }

    @Test("空の検索語では全件")
    @MainActor
    func testEmptySearchReturnsAll() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        #expect(filterRecords(records).count == 3)
    }

    // MARK: - チェックイン種別フィルタ

    @Test("ゴールドのみに絞り込める")
    @MainActor
    func testFilterGold() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        let result = filterRecords(records, checkInType: .location)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.checkInType == .location })
    }

    @Test("シルバーのみに絞り込める")
    @MainActor
    func testFilterSilver() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        let result = filterRecords(records, checkInType: .manual)
        #expect(result.count == 1)
        #expect(result.first?.aquarium?.name == "海遊館")
    }

    // MARK: - 年フィルタ

    @Test("年で絞り込める")
    @MainActor
    func testFilterByYear() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        #expect(filterRecords(records, year: 2024).count == 1)
        #expect(filterRecords(records, year: 2025).count == 2)
        #expect(filterRecords(records, year: 2023).isEmpty)
    }

    // MARK: - 複合条件

    @Test("検索語＋種別＋年の複合条件で絞り込める")
    @MainActor
    func testCombinedFilters() throws {
        let container = try createTestContainer()
        let records = createTestRecords(context: container.mainContext)

        // 2025年のゴールドは美ら海のみ
        let result = filterRecords(records, searchText: "美ら海", checkInType: .location, year: 2025)
        #expect(result.count == 1)
        #expect(result.first?.aquarium?.name == "美ら海水族館")

        // 2024年のシルバーは存在しない
        #expect(filterRecords(records, checkInType: .manual, year: 2024).isEmpty)
    }
}
