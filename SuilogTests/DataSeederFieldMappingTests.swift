//
//  DataSeederFieldMappingTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/11.
//
//  DataSeederの実際の挿入・更新関数を使い、JSONフィールド（営業時間・料金・
//  電話番号を含む）がモデルへ正しくマッピングされることをテストする。
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

@Suite(.serialized)
struct DataSeederFieldMappingTests {

    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeData(
        name: String,
        stableId: String? = nil,
        businessHours: String? = nil,
        admissionFee: String? = nil,
        phoneNumber: String? = nil
    ) -> AquariumData {
        AquariumData(
            name: name,
            latitude: 35.0,
            longitude: 139.0,
            description: "テスト用",
            region: "関東",
            representativeFish: "fish.fill",
            fishIconSize: 3,
            address: "テスト住所",
            affiliateLink: "https://example.com/ticket",
            stableId: stableId,
            officialUrl: "https://example.com",
            businessHours: businessHours,
            admissionFee: admissionFee,
            phoneNumber: phoneNumber
        )
    }

    // MARK: - insertAquariums

    @Test("挿入時に全フィールド（営業時間・料金・電話番号を含む）が反映される")
    @MainActor
    func testInsertMapsAllFields() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let data = makeData(
            name: "テスト水族館",
            stableId: "test-aquarium",
            businessHours: "9:00〜17:00",
            admissionFee: "大人 2,400円",
            phoneNumber: "03-1234-5678"
        )

        let error = DataSeeder.insertAquariums(context: context, aquariumData: [data])
        #expect(error == nil)

        let aquariums = try context.fetch(FetchDescriptor<Aquarium>())
        let aquarium = try #require(aquariums.first)

        #expect(aquarium.name == "テスト水族館")
        #expect(aquarium.stableId == "test-aquarium")
        #expect(aquarium.address == "テスト住所")
        #expect(aquarium.affiliateLink == "https://example.com/ticket")
        #expect(aquarium.officialUrl == "https://example.com")
        #expect(aquarium.businessHours == "9:00〜17:00")
        #expect(aquarium.admissionFee == "大人 2,400円")
        #expect(aquarium.phoneNumber == "03-1234-5678")
    }

    @Test("新フィールドがないデータでは nil のまま")
    @MainActor
    func testInsertWithoutNewFields() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let error = DataSeeder.insertAquariums(
            context: context,
            aquariumData: [makeData(name: "旧形式水族館")]
        )
        #expect(error == nil)

        let aquarium = try #require(try context.fetch(FetchDescriptor<Aquarium>()).first)
        #expect(aquarium.businessHours == nil)
        #expect(aquarium.admissionFee == nil)
        #expect(aquarium.phoneNumber == nil)
    }

    // MARK: - updateAquariums

    @Test("更新時に新フィールドが既存の水族館へ反映され、訪問記録は保持される")
    @MainActor
    func testUpdateMapsNewFieldsAndKeepsVisits() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ（新フィールドなし）と訪問記録を用意
        let existing = Aquarium(
            name: "テスト水族館",
            latitude: 35.0,
            longitude: 139.0,
            description: "旧説明",
            region: "関東",
            stableId: "test-aquarium"
        )
        context.insert(existing)
        let visit = VisitRecord(memo: "訪問済み", checkInType: .location, aquarium: existing)
        context.insert(visit)
        try context.save()

        // 新フィールド付きデータで更新
        let newData = makeData(
            name: "テスト水族館",
            stableId: "test-aquarium",
            businessHours: "10:00〜18:00",
            admissionFee: "大人 3,000円",
            phoneNumber: "098-765-4321"
        )
        let error = DataSeeder.updateAquariums(context: context, existing: [existing], newData: [newData])
        #expect(error == nil)

        #expect(existing.businessHours == "10:00〜18:00")
        #expect(existing.admissionFee == "大人 3,000円")
        #expect(existing.phoneNumber == "098-765-4321")
        #expect(existing.safeVisits.count == 1) // 訪問記録は保持される
    }

    @Test("更新時に新規の水族館が追加され、訪問記録のない削除対象は消える")
    @MainActor
    func testUpdateAddsNewAndRemovesUnvisited() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存: JSONから消える水族館（訪問記録なし）
        let removed = Aquarium(
            name: "閉館した水族館",
            latitude: 35.0,
            longitude: 139.0,
            description: "",
            region: "関東",
            stableId: "closed"
        )
        context.insert(removed)
        try context.save()

        let newData = makeData(name: "新しい水族館", stableId: "new-aquarium")
        let error = DataSeeder.updateAquariums(context: context, existing: [removed], newData: [newData])
        #expect(error == nil)

        let aquariums = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(aquariums.count == 1)
        #expect(aquariums.first?.name == "新しい水族館")
    }
}
