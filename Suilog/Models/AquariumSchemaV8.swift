//
//  AquariumSchemaV8.swift
//  Suilog
//
//  Created by dancho on 2026/06/11.
//
//  複数写真対応スキーマ: VisitRecordにadditionalPhotosDataフィールドを追加
//  1枚目は後方互換のためphotoDataに保持し、2枚目以降を配列で保存する

import Foundation
import SwiftData

enum AquariumSchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Aquarium.self, VisitRecord.self]
    }

    enum CheckInTypeV8: String, Codable {
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
        var stableId: String = ""

        /// 公式HPのURL
        var officialUrl: String?

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
            stableId: String = "",
            officialUrl: String? = nil
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
            self.officialUrl = officialUrl
        }
    }

    @Model
    final class VisitRecord {
        // CloudKit互換: すべてのプロパティにデフォルト値を設定
        var id: UUID = UUID()
        var visitDate: Date = Date()
        var memo: String = ""
        var photoData: Data?

        /// 2枚目以降の写真（1枚目は後方互換のためphotoDataに保持）
        var additionalPhotosData: [Data]?

        var checkInType: CheckInTypeV8 = AquariumSchemaV8.CheckInTypeV8.manual
        var aquarium: Aquarium?

        init(
            id: UUID = UUID(),
            visitDate: Date = Date(),
            memo: String = "",
            photoData: Data? = nil,
            additionalPhotosData: [Data]? = nil,
            checkInType: CheckInTypeV8 = .manual,
            aquarium: Aquarium? = nil
        ) {
            self.id = id
            self.visitDate = visitDate
            self.memo = memo
            self.photoData = photoData
            self.additionalPhotosData = additionalPhotosData
            self.checkInType = checkInType
            self.aquarium = aquarium
        }
    }
}
