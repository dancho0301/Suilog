//
//  AquariumSchemaV6.swift
//  Suilog
//
//  Created by dancho on 2026/01/14.
//
//  安定ID対応スキーマ: stableIdフィールドを追加

import Foundation
import SwiftData

enum AquariumSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Aquarium.self, VisitRecord.self]
    }

    enum CheckInTypeV6: String, Codable {
        case location
        case manual
    }

    @Model
    final class Aquarium {
        // CloudKit互換: すべてのプロパティにデフォルト値を設定
        var id: UUID = UUID()
        var name: String = ""
        var latitude: Double = 0.0
        var longitude: Double = 0.0
        var aquariumDescription: String = ""
        var region: String = ""
        var representativeFish: String = "fish.fill"
        var fishIconSize: Int = 3
        var address: String?
        var affiliateLink: String?

        /// 安定ID: JSONで管理される一意識別子（名称変更に対応）
        /// 既存データはnilまたは空文字、次回更新時にJSONから設定される
        var stableId: String = ""

        // CloudKit互換: リレーションシップはオプショナルに
        @Relationship(deleteRule: .cascade, inverse: \VisitRecord.aquarium)
        var visits: [VisitRecord]?

        init(
            id: UUID = UUID(),
            name: String = "",
            latitude: Double = 0.0,
            longitude: Double = 0.0,
            description: String = "",
            region: String = "",
            representativeFish: String = "fish.fill",
            fishIconSize: Int = 3,
            address: String? = nil,
            affiliateLink: String? = nil,
            stableId: String = ""
        ) {
            self.id = id
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.aquariumDescription = description
            self.region = region
            self.representativeFish = representativeFish
            self.fishIconSize = fishIconSize
            self.address = address
            self.affiliateLink = affiliateLink
            self.stableId = stableId
        }
    }

    @Model
    final class VisitRecord {
        // CloudKit互換: すべてのプロパティにデフォルト値を設定
        var id: UUID = UUID()
        var visitDate: Date = Date()
        var memo: String = ""
        var photoData: Data?
        var checkInType: CheckInTypeV6 = AquariumSchemaV6.CheckInTypeV6.manual
        var aquarium: Aquarium?

        init(
            id: UUID = UUID(),
            visitDate: Date = Date(),
            memo: String = "",
            photoData: Data? = nil,
            checkInType: CheckInTypeV6 = .manual,
            aquarium: Aquarium? = nil
        ) {
            self.id = id
            self.visitDate = visitDate
            self.memo = memo
            self.photoData = photoData
            self.checkInType = checkInType
            self.aquarium = aquarium
        }
    }
}
