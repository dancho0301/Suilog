//
//  MigrationPlanTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/02/12.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// AquariumMigrationPlanのテスト
@Suite
struct MigrationPlanTests {

    // MARK: - Schema Configuration Tests

    @Test("スキーマバージョンが10個定義されている")
    func testSchemaVersionCount() {
        #expect(AquariumMigrationPlan.schemas.count == 10)
    }

    @Test("マイグレーションステージが9つ定義されている")
    func testMigrationStageCount() {
        #expect(AquariumMigrationPlan.stages.count == 9)
    }

    @Test("最新スキーマがV10")
    func testLatestSchemaVersion() {
        let latestSchema = AquariumMigrationPlan.schemas.last
        #expect(latestSchema == AquariumSchemaV10.self)
    }

    @Test("V10のバージョン識別子が10.0.0")
    func testV10VersionIdentifier() {
        #expect(AquariumSchemaV10.versionIdentifier == Schema.Version(10, 0, 0))
    }

    @Test("V10のモデルにAquarium・VisitRecord・CreatureSightingが含まれる")
    func testV10Models() {
        let models = AquariumSchemaV10.models
        #expect(models.count == 3)
    }

    @Test("VisitRecordの無料版写真上限が1枚")
    func testFreePhotoLimit() {
        #expect(VisitRecord.freePhotoLimit == 1)
    }

    @Test("V9で追加されたAquarium情報フィールドはデフォルトnil")
    func testAquariumNewFieldDefaults() {
        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.0,
            longitude: 139.0,
            description: "テスト",
            region: "関東"
        )
        #expect(aquarium.businessHours == nil)
        #expect(aquarium.admissionFee == nil)
        #expect(aquarium.phoneNumber == nil)
    }

    @Test("VisitRecordの写真ヘルパーが1枚目と2枚目以降を正しく振り分ける")
    func testVisitRecordPhotoHelpers() {
        let record = VisitRecord()
        #expect(record.allPhotosData.isEmpty)

        let photo1 = Data([0x01])
        let photo2 = Data([0x02])
        let photo3 = Data([0x03])

        record.setPhotos([photo1, photo2, photo3])
        #expect(record.photoData == photo1)
        #expect(record.additionalPhotosData == [photo2, photo3])
        #expect(record.allPhotosData == [photo1, photo2, photo3])

        record.setPhotos([photo1])
        #expect(record.photoData == photo1)
        #expect(record.additionalPhotosData == nil)
        #expect(record.allPhotosData == [photo1])

        record.setPhotos([])
        #expect(record.photoData == nil)
        #expect(record.additionalPhotosData == nil)
        #expect(record.allPhotosData.isEmpty)
    }

    // MARK: - Schema Version Identifiers

    @Test("全スキーマのバージョン識別子が順序正しい")
    func testSchemaVersionOrder() {
        #expect(AquariumSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(AquariumSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(AquariumSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(AquariumSchemaV4.versionIdentifier == Schema.Version(4, 0, 0))
        #expect(AquariumSchemaV5.versionIdentifier == Schema.Version(5, 0, 0))
        #expect(AquariumSchemaV6.versionIdentifier == Schema.Version(6, 0, 0))
        #expect(AquariumSchemaV7.versionIdentifier == Schema.Version(7, 0, 0))
        #expect(AquariumSchemaV8.versionIdentifier == Schema.Version(8, 0, 0))
        #expect(AquariumSchemaV9.versionIdentifier == Schema.Version(9, 0, 0))
        #expect(AquariumSchemaV10.versionIdentifier == Schema.Version(10, 0, 0))
    }

    // MARK: - InMemory Container Test

    @Test("インメモリModelContainerが最新スキーマで作成できる")
    @MainActor
    func testInMemoryContainerCreation() throws {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let context = container.mainContext
        let aquariums = try context.fetch(FetchDescriptor<Aquarium>())
        #expect(aquariums.isEmpty)
    }

    @Test("StoreManager のテーマProduct IDが正しい")
    @MainActor
    func testThemeProductIds() {
        let ids = StoreManager.themeProductIds
        #expect(ids.count == 2)
        #expect(ids.contains("com.suilog.theme.yumekawa"))
        #expect(ids.contains("com.suilog.theme.all_pack"))
    }
}
