//
//  AquariumSchemaV3.swift
//  Suilog
//
//  Created by dancho on 2026/01/02.
//

import Foundation
import SwiftData

enum AquariumSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Aquarium.self, VisitRecord.self]
    }

    enum CheckInTypeV3: String, Codable {
        case location
        case manual
    }

    @Model
    final class Aquarium {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var aquariumDescription: String
        var region: String
        var representativeFish: String
        var fishIconSize: Int  // 1-5のサイズ指定（1=最小、5=最大）

        @Relationship(deleteRule: .cascade, inverse: \VisitRecord.aquarium)
        var visits: [VisitRecord] = []

        init(
            id: UUID = UUID(),
            name: String,
            latitude: Double,
            longitude: Double,
            description: String,
            region: String,
            representativeFish: String = "fish.fill",
            fishIconSize: Int = 3
        ) {
            self.id = id
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.aquariumDescription = description
            self.region = region
            self.representativeFish = representativeFish
            self.fishIconSize = fishIconSize
        }
    }

    @Model
    final class VisitRecord {
        var id: UUID
        var visitDate: Date
        var memo: String
        var photoData: Data?
        var checkInType: CheckInTypeV3
        var aquarium: Aquarium?

        init(
            id: UUID = UUID(),
            visitDate: Date = Date(),
            memo: String = "",
            photoData: Data? = nil,
            checkInType: CheckInTypeV3 = .manual,
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
