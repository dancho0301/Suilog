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
        [AquariumSchemaV1.self, AquariumSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV1.self,
        toVersion: AquariumSchemaV2.self
    )
}
