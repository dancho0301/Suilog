//
//  AquariumSchemaV11.swift
//  Suilog
//
//  水族館ごとの生き物候補スキーマ:
//  - Aquarium に creatureIds（その水族館で会える生き物のID一覧）を追加
//  - VisitRecord / CreatureSighting はV10から変更なし

import Foundation
import SwiftData

enum AquariumSchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Aquarium.self, VisitRecord.self, CreatureSighting.self]
    }

    enum CheckInTypeV11: String, Codable {
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

        /// この水族館で会える生き物のID一覧（creatures.json の id）
        var creatureIds: [String] = []

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
            phoneNumber: String? = nil,
            creatureIds: [String] = []
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
            self.creatureIds = creatureIds
        }
    }

    @Model
    final class VisitRecord {
        // CloudKit互換: すべてのプロパティにデフォルト値を設定
        var id: UUID = UUID()
        var visitDate: Date = Date()
        var memo: String = ""

        @Attribute(.externalStorage)
        var photoData: Data?

        @Attribute(.externalStorage)
        var additionalPhotosData: [Data]?

        var checkInType: CheckInTypeV11 = AquariumSchemaV11.CheckInTypeV11.manual
        var aquarium: Aquarium?

        init(
            id: UUID = UUID(),
            visitDate: Date = Date(),
            memo: String = "",
            photoData: Data? = nil,
            additionalPhotosData: [Data]? = nil,
            checkInType: CheckInTypeV11 = .manual,
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

    /// ユーザーが「会った」生き物の自己申告記録（1生き物につき1件）
    @Model
    final class CreatureSighting {
        var id: UUID = UUID()
        /// creatures.json の生き物ID
        var creatureId: String = ""
        /// 初めて会った日時
        var firstSeenDate: Date = Date()
        /// 初めて会った水族館名（スナップショット。任意）
        var aquariumName: String = ""

        init(
            id: UUID = UUID(),
            creatureId: String = "",
            firstSeenDate: Date = Date(),
            aquariumName: String = ""
        ) {
            self.id = id
            self.creatureId = creatureId
            self.firstSeenDate = firstSeenDate
            self.aquariumName = aquariumName
        }
    }
}
