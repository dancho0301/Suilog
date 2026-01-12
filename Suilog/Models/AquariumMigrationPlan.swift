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
        [AquariumSchemaV1.self, AquariumSchemaV2.self, AquariumSchemaV3.self, AquariumSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4]
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
}
