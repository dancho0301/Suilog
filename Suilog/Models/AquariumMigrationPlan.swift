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
        [AquariumSchemaV1.self, AquariumSchemaV2.self, AquariumSchemaV3.self, AquariumSchemaV4.self, AquariumSchemaV5.self, AquariumSchemaV6.self, AquariumSchemaV7.self, AquariumSchemaV8.self, AquariumSchemaV9.self, AquariumSchemaV10.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8, migrateV8toV9, migrateV9toV10]
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

    // V5→V6: 安定ID対応（stableIdフィールド追加、デフォルト空文字で軽量マイグレーション）
    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV5.self,
        toVersion: AquariumSchemaV6.self
    )

    // V6→V7: 公式HPリンク対応（officialUrlフィールド追加、オプショナルで軽量マイグレーション）
    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV6.self,
        toVersion: AquariumSchemaV7.self
    )

    // V7→V8: 複数写真対応（additionalPhotosDataフィールド追加、オプショナルで軽量マイグレーション）
    static let migrateV7toV8 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV7.self,
        toVersion: AquariumSchemaV8.self
    )

    // V8→V9: 写真の外部ストレージ化＋水族館情報拡充（営業時間・料金・電話番号、軽量マイグレーション）
    static let migrateV8toV9 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV8.self,
        toVersion: AquariumSchemaV9.self
    )

    // V9→V10: 生き物図鑑対応（CreatureSightingモデル追加、軽量マイグレーション）
    static let migrateV9toV10 = MigrationStage.lightweight(
        fromVersion: AquariumSchemaV9.self,
        toVersion: AquariumSchemaV10.self
    )
}
