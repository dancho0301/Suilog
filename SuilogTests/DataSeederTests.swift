//
//  DataSeederTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/01/14.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// DataSeederの更新ロジックをテストする
@Suite(.serialized)
struct DataSeederTests {

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

    /// テスト用の水族館を作成
    @MainActor
    private func createAquarium(
        context: ModelContext,
        name: String,
        stableId: String = "",
        region: String = "関東"
    ) -> Aquarium {
        let aquarium = Aquarium(
            name: name,
            latitude: 35.0,
            longitude: 139.0,
            description: "テスト用",
            region: region,
            representativeFish: "fish.fill",
            fishIconSize: 3,
            address: "テスト住所",
            affiliateLink: nil,
            stableId: stableId
        )
        context.insert(aquarium)
        return aquarium
    }

    /// テスト用のAquariumDataを作成
    private func createAquariumData(
        name: String,
        stableId: String? = nil,
        region: String = "関東"
    ) -> AquariumData {
        return AquariumData(
            name: name,
            latitude: 35.0,
            longitude: 139.0,
            description: "テスト用",
            region: region,
            representativeFish: "fish.fill",
            fishIconSize: 3,
            address: "テスト住所",
            affiliateLink: nil,
            stableId: stableId
        )
    }

    /// 更新ロジックを直接テストするためのヘルパー（DataSeederの内部ロジックを再現）
    @MainActor
    private func applyUpdates(
        context: ModelContext,
        existing: [Aquarium],
        newData: [AquariumData]
    ) {
        var existingByStableId: [String: Aquarium] = [:]
        var existingByName: [String: Aquarium] = [:]

        for aquarium in existing {
            if !aquarium.stableId.isEmpty {
                existingByStableId[aquarium.stableId] = aquarium
            }
            existingByName[aquarium.name] = aquarium
        }

        var matchedAquariumIds: Set<UUID> = []

        for newAquarium in newData {
            var existingAquarium: Aquarium?

            if let stableId = newAquarium.stableId, !stableId.isEmpty {
                existingAquarium = existingByStableId[stableId]
            }

            if existingAquarium == nil {
                existingAquarium = existingByName[newAquarium.name]
            }

            if let existingAquarium = existingAquarium {
                existingAquarium.name = newAquarium.name
                existingAquarium.latitude = newAquarium.latitude
                existingAquarium.longitude = newAquarium.longitude
                existingAquarium.aquariumDescription = newAquarium.description
                existingAquarium.region = newAquarium.region
                if let stableId = newAquarium.stableId, !stableId.isEmpty {
                    existingAquarium.stableId = stableId
                }
                matchedAquariumIds.insert(existingAquarium.id)
            } else {
                let aquarium = Aquarium(
                    name: newAquarium.name,
                    latitude: newAquarium.latitude,
                    longitude: newAquarium.longitude,
                    description: newAquarium.description,
                    region: newAquarium.region,
                    representativeFish: newAquarium.representativeFish,
                    fishIconSize: newAquarium.fishIconSize,
                    address: newAquarium.address,
                    affiliateLink: newAquarium.affiliateLink,
                    stableId: newAquarium.stableId ?? ""
                )
                context.insert(aquarium)
            }
        }

        for aquarium in existing {
            if !matchedAquariumIds.contains(aquarium.id) {
                if aquarium.safeVisits.isEmpty {
                    context.delete(aquarium)
                }
            }
        }

        try? context.save()
    }

    // MARK: - stableIdマッチングテスト

    @Test("stableIdでマッチング: 名前が変わってもstableIdで追跡")
    @MainActor
    func testMatchByStableId() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ（stableIdあり）
        let existing = createAquarium(
            context: context,
            name: "旧名称水族館",
            stableId: "aquarium-001"
        )
        let existingId = existing.id
        try context.save()

        // 新データ（同じstableId、異なる名前）
        let newData = [
            createAquariumData(name: "新名称水族館", stableId: "aquarium-001")
        ]

        // 更新を適用
        let existingList = try context.fetch(FetchDescriptor<Aquarium>())
        applyUpdates(context: context, existing: existingList, newData: newData)

        // 検証
        let result = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(result.count == 1)
        #expect(result.first?.id == existingId) // 同じレコードが更新された
        #expect(result.first?.name == "新名称水族館") // 名前が更新された
        #expect(result.first?.stableId == "aquarium-001")
    }

    @Test("名前でフォールバック: stableIdがない既存データは名前でマッチ")
    @MainActor
    func testFallbackToName() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ（stableIdなし）
        let existing = createAquarium(
            context: context,
            name: "サンシャイン水族館",
            stableId: ""
        )
        let existingId = existing.id
        try context.save()

        // 新データ（stableIdあり、同じ名前）
        let newData = [
            createAquariumData(name: "サンシャイン水族館", stableId: "sunshine")
        ]

        // 更新を適用
        let existingList = try context.fetch(FetchDescriptor<Aquarium>())
        applyUpdates(context: context, existing: existingList, newData: newData)

        // 検証
        let result = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(result.count == 1)
        #expect(result.first?.id == existingId) // 同じレコードが更新された
        #expect(result.first?.stableId == "sunshine") // stableIdが設定された
    }

    @Test("新規追加: マッチしないデータは新規追加")
    @MainActor
    func testAddNewAquarium() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ
        _ = createAquarium(context: context, name: "既存水族館", stableId: "existing")
        try context.save()

        // 新データ（新規）
        let newData = [
            createAquariumData(name: "既存水族館", stableId: "existing"),
            createAquariumData(name: "新規水族館", stableId: "new-aquarium")
        ]

        // 更新を適用
        let existingList = try context.fetch(FetchDescriptor<Aquarium>())
        applyUpdates(context: context, existing: existingList, newData: newData)

        // 検証
        let result = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(result.count == 2)

        let names = result.map { $0.name }.sorted()
        #expect(names == ["新規水族館", "既存水族館"])
    }

    @Test("削除: JSONから消えた水族館は削除（訪問記録なし）")
    @MainActor
    func testDeleteUnmatchedWithoutVisits() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ
        _ = createAquarium(context: context, name: "残す水族館", stableId: "keep")
        _ = createAquarium(context: context, name: "消す水族館", stableId: "delete")
        try context.save()

        // 新データ（1つだけ）
        let newData = [
            createAquariumData(name: "残す水族館", stableId: "keep")
        ]

        // 更新を適用
        let existingList = try context.fetch(FetchDescriptor<Aquarium>())
        applyUpdates(context: context, existing: existingList, newData: newData)

        // 検証
        let result = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(result.count == 1)
        #expect(result.first?.name == "残す水族館")
    }

    @Test("保持: 訪問記録がある水族館はJSONから消えても保持")
    @MainActor
    func testKeepWithVisitRecords() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ
        let keepAquarium = createAquarium(context: context, name: "残す水族館", stableId: "keep")
        let deleteCandidate = createAquarium(context: context, name: "訪問済み水族館", stableId: "visited")

        // 訪問記録を追加
        let visit = VisitRecord(
            visitDate: Date(),
            memo: "テスト訪問",
            checkInType: .manual,
            aquarium: deleteCandidate
        )
        context.insert(visit)
        try context.save()

        // 新データ（訪問済み水族館が含まれていない）
        let newData = [
            createAquariumData(name: "残す水族館", stableId: "keep")
        ]

        // 更新を適用
        let existingList = try context.fetch(FetchDescriptor<Aquarium>())
        applyUpdates(context: context, existing: existingList, newData: newData)

        // 検証
        let result = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(result.count == 2) // 訪問記録があるので保持

        let names = result.map { $0.name }.sorted()
        #expect(names.contains("訪問済み水族館"))
    }

    @Test("stableId優先: stableIdと名前の両方がマッチする場合はstableId優先")
    @MainActor
    func testStableIdPriority() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 既存データ
        let aquarium1 = createAquarium(context: context, name: "水族館A", stableId: "id-a")
        let aquarium2 = createAquarium(context: context, name: "水族館B", stableId: "id-b")
        let id1 = aquarium1.id
        let id2 = aquarium2.id
        try context.save()

        // 新データ（名前が入れ替わっているが、stableIdで追跡）
        let newData = [
            createAquariumData(name: "水族館B", stableId: "id-a"), // id-aの名前がBに変更
            createAquariumData(name: "水族館A", stableId: "id-b")  // id-bの名前がAに変更
        ]

        // 更新を適用
        let existingList = try context.fetch(FetchDescriptor<Aquarium>())
        applyUpdates(context: context, existing: existingList, newData: newData)

        // 検証
        let result = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(result.count == 2)

        let resultById1 = result.first { $0.id == id1 }
        let resultById2 = result.first { $0.id == id2 }

        #expect(resultById1?.name == "水族館B") // stableId "id-a" のレコードが "水族館B" に更新
        #expect(resultById2?.name == "水族館A") // stableId "id-b" のレコードが "水族館A" に更新
    }
}
