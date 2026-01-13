//
//  AquariumSchemaV5.swift
//  Suilog
//
//  Created by dancho on 2026/01/13.
//
//  CloudKit互換スキーマ: すべての属性にデフォルト値を設定

import Foundation
import SwiftData

enum AquariumSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Aquarium.self, VisitRecord.self]
    }

    enum CheckInTypeV5: String, Codable {
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
            affiliateLink: String? = nil
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
        }
    }

    @Model
    final class VisitRecord {
        // CloudKit互換: すべてのプロパティにデフォルト値を設定
        var id: UUID = UUID()
        var visitDate: Date = Date()
        var memo: String = ""
        var photoData: Data?
        var checkInType: CheckInTypeV5 = AquariumSchemaV5.CheckInTypeV5.manual
        var aquarium: Aquarium?

        init(
            id: UUID = UUID(),
            visitDate: Date = Date(),
            memo: String = "",
            photoData: Data? = nil,
            checkInType: CheckInTypeV5 = .manual,
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
