//
//  AquariumMigrationPlan.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData

enum AquariumMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AquariumSchemaV1.self, AquariumSchemaV2.self, AquariumSchemaV3.self, AquariumSchemaV4.self, AquariumSchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV1.self,
        toVersion: AquariumSchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV2.self,
        toVersion: AquariumSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV3.self,
        toVersion: AquariumSchemaV4.self
    )

    // V4→V5: CloudKit互換（デフォルト値追加、visitsをオプショナル化）
    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV4.self,
        toVersion: AquariumSchemaV5.self
    )
}
