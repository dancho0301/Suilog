//
//  AquariumSchemaV9.swift
//  Suilog
//
//  Created by dancho on 2026/06/11.
//
//  パフォーマンス・情報拡充スキーマ:
//  - 写真データを外部ストレージ化（@Attribute(.externalStorage)）し、
//    記録一覧表示時のメモリ使用量とDBサイズを削減
//  - Aquariumに営業時間・料金・電話番号フィールドを追加

import Foundation
import SwiftData

enum AquariumSchemaV9: VersionedSchema {
    static var versionIdentifier = Schema.Version(9, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Aquarium.self, VisitRecord.self]
    }

    enum CheckInTypeV9: String, Codable {
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

        /// 営業時間（例: "9:00〜17:00（季節により変動）"）
        var businessHours: String?

        /// 入館料金（例: "大人 2,400円 / 小中学生 1,200円"）
        var admissionFee: String?

        /// 電話番号
        var phoneNumber: String?

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
            officialUrl: String? = nil,
            businessHours: String? = nil,
            admissionFee: String? = nil,
            phoneNumber: String? = nil
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
            self.businessHours = businessHours
            self.admissionFee = admissionFee
            self.phoneNumber = phoneNumber
        }
    }

    @Model
    final class VisitRecord {
        // CloudKit互換: すべてのプロパティにデフォルト値を設定
        var id: UUID = UUID()
        var visitDate: Date = Date()
        var memo: String = ""

        /// 1枚目の写真（外部ストレージに保存）
        @Attribute(.externalStorage)
        var photoData: Data?

        /// 2枚目以降の写真（外部ストレージに保存。1枚目は後方互換のためphotoDataに保持）
        @Attribute(.externalStorage)
        var additionalPhotosData: [Data]?

        var checkInType: CheckInTypeV9 = AquariumSchemaV9.CheckInTypeV9.manual
        var aquarium: Aquarium?

        init(
            id: UUID = UUID(),
            visitDate: Date = Date(),
            memo: String = "",
            photoData: Data? = nil,
            additionalPhotosData: [Data]? = nil,
            checkInType: CheckInTypeV9 = .manual,
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
