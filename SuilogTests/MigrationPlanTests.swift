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

    @Test("スキーマバージョンが7つ定義されている")
    func testSchemaVersionCount() {
        #expect(AquariumMigrationPlan.schemas.count == 7)
    }

    @Test("マイグレーションステージが6つ定義されている")
    func testMigrationStageCount() {
        #expect(AquariumMigrationPlan.stages.count == 6)
    }

    @Test("最新スキーマがV7")
    func testLatestSchemaVersion() {
        let latestSchema = AquariumMigrationPlan.schemas.last
        #expect(latestSchema == AquariumSchemaV7.self)
    }

    @Test("V7のバージョン識別子が7.0.0")
    func testV7VersionIdentifier() {
        #expect(AquariumSchemaV7.versionIdentifier == Schema.Version(7, 0, 0))
    }

    @Test("V7のモデルにAquariumとVisitRecordが含まれる")
    func testV7Models() {
        let models = AquariumSchemaV7.models
        #expect(models.count == 2)
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
