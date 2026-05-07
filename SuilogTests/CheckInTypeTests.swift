//
//  CheckInTypeTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/02/12.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// CheckInType enumとVisitRecordのテスト
@Suite(.serialized)
struct CheckInTypeTests {

    // MARK: - Test Helpers

    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - CheckInType displayName Tests

    @Test("CheckInType.location の displayName")
    func testLocationDisplayName() {
        let type: CheckInType = .location
        #expect(type.displayName == "位置情報チェックイン")
    }

    @Test("CheckInType.manual の displayName")
    func testManualDisplayName() {
        let type: CheckInType = .manual
        #expect(type.displayName == "手動チェックイン")
    }

    // MARK: - CheckInType rawValue Tests

    @Test("CheckInType.location の rawValue")
    func testLocationRawValue() {
        #expect(CheckInType.location.rawValue == "location")
    }

    @Test("CheckInType.manual の rawValue")
    func testManualRawValue() {
        #expect(CheckInType.manual.rawValue == "manual")
    }

    @Test("CheckInType rawValueからの復元")
    func testCheckInTypeFromRawValue() {
        let location = CheckInType(rawValue: "location")
        let manual = CheckInType(rawValue: "manual")
        let invalid = CheckInType(rawValue: "invalid")

        #expect(location == .location)
        #expect(manual == .manual)
        #expect(invalid == nil)
    }

    // MARK: - VisitRecord Tests

    @Test("VisitRecord初期化: すべてのフィールドが正しく設定される")
    @MainActor
    func testVisitRecordInit() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.0,
            longitude: 139.0,
            description: "テスト",
            region: "関東"
        )
        context.insert(aquarium)

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let photoData = Data([0x01, 0x02, 0x03])

        let record = VisitRecord(
            visitDate: date,
            memo: "素晴らしい水族館でした",
            photoData: photoData,
            checkInType: .location,
            aquarium: aquarium
        )
        context.insert(record)
        try context.save()

        #expect(record.visitDate == date)
        #expect(record.memo == "素晴らしい水族館でした")
        #expect(record.photoData == photoData)
        #expect(record.checkInType == .location)
        #expect(record.aquarium?.name == "テスト水族館")
    }

    @Test("VisitRecord初期化: デフォルト値")
    @MainActor
    func testVisitRecordDefaultValues() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let record = VisitRecord()
        context.insert(record)
        try context.save()

        #expect(record.memo == "")
        #expect(record.photoData == nil)
        #expect(record.checkInType == .manual)
        #expect(record.aquarium == nil)
    }

    @Test("VisitRecord: 水族館との関連")
    @MainActor
    func testVisitRecordAquariumRelationship() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.0,
            longitude: 139.0,
            description: "テスト",
            region: "関東"
        )
        context.insert(aquarium)

        let visit1 = VisitRecord(
            visitDate: Date(),
            memo: "1回目",
            checkInType: .location,
            aquarium: aquarium
        )
        let visit2 = VisitRecord(
            visitDate: Date().addingTimeInterval(86400),
            memo: "2回目",
            checkInType: .manual,
            aquarium: aquarium
        )
        context.insert(visit1)
        context.insert(visit2)
        try context.save()

        #expect(aquarium.safeVisits.count == 2)
        #expect(visit1.aquarium?.id == aquarium.id)
        #expect(visit2.aquarium?.id == aquarium.id)
    }
}
