//
//  AquariumModelTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/02/12.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// Aquariumモデル拡張のテスト
@Suite(.serialized)
struct AquariumModelTests {

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

    // MARK: - safeVisits Tests

    @Test("safeVisits: visitsがnilの場合は空配列を返す")
    @MainActor
    func testSafeVisitsNil() throws {
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
        try context.save()

        // visits は nil（初期状態）
        #expect(aquarium.safeVisits.isEmpty)
    }

    @Test("safeVisits: 訪問記録がある場合はそのまま返す")
    @MainActor
    func testSafeVisitsWithRecords() throws {
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

        let visit = VisitRecord(
            visitDate: Date(),
            memo: "テスト訪問",
            checkInType: .location,
            aquarium: aquarium
        )
        context.insert(visit)
        try context.save()

        #expect(aquarium.safeVisits.count == 1)
    }

    // MARK: - hasVisited Tests

    @Test("hasVisited: 未訪問の場合はfalse")
    @MainActor
    func testHasVisitedFalse() throws {
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
        try context.save()

        #expect(aquarium.hasVisited == false)
    }

    @Test("hasVisited: 訪問済みの場合はtrue")
    @MainActor
    func testHasVisitedTrue() throws {
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

        let visit = VisitRecord(
            visitDate: Date(),
            memo: "テスト",
            checkInType: .manual,
            aquarium: aquarium
        )
        context.insert(visit)
        try context.save()

        #expect(aquarium.hasVisited == true)
    }

    // MARK: - visitCount Tests

    @Test("visitCount: 訪問記録なしは0")
    @MainActor
    func testVisitCountZero() throws {
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
        try context.save()

        #expect(aquarium.visitCount == 0)
    }

    @Test("visitCount: 複数の訪問記録がある場合")
    @MainActor
    func testVisitCountMultiple() throws {
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

        for i in 0..<3 {
            let visit = VisitRecord(
                visitDate: Date().addingTimeInterval(Double(i) * 86400),
                memo: "訪問\(i + 1)",
                checkInType: i % 2 == 0 ? .location : .manual,
                aquarium: aquarium
            )
            context.insert(visit)
        }
        try context.save()

        #expect(aquarium.visitCount == 3)
    }

    // MARK: - lastVisitDate Tests

    @Test("lastVisitDate: 訪問記録なしはnil")
    @MainActor
    func testLastVisitDateNil() throws {
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
        try context.save()

        #expect(aquarium.lastVisitDate == nil)
    }

    @Test("lastVisitDate: 最新の訪問日を返す")
    @MainActor
    func testLastVisitDateReturnsLatest() throws {
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

        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        let newDate = Date(timeIntervalSince1970: 2_000_000)

        let visit1 = VisitRecord(
            visitDate: oldDate,
            memo: "古い訪問",
            checkInType: .manual,
            aquarium: aquarium
        )
        let visit2 = VisitRecord(
            visitDate: newDate,
            memo: "新しい訪問",
            checkInType: .location,
            aquarium: aquarium
        )
        context.insert(visit1)
        context.insert(visit2)
        try context.save()

        #expect(aquarium.lastVisitDate == newDate)
    }

    // MARK: - Aquarium Init Tests

    @Test("Aquarium初期化: すべてのフィールドが正しく設定される")
    @MainActor
    func testAquariumInit() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquarium = Aquarium(
            name: "サンシャイン水族館",
            latitude: 35.72,
            longitude: 139.72,
            description: "都会のオアシス",
            region: "関東",
            representativeFish: "tropicalfish.fill",
            fishIconSize: 4,
            address: "東京都豊島区",
            affiliateLink: "https://example.com",
            stableId: "sunshine",
            officialUrl: "https://sunshinecity.jp/aquarium/"
        )
        context.insert(aquarium)
        try context.save()

        #expect(aquarium.name == "サンシャイン水族館")
        #expect(aquarium.latitude == 35.72)
        #expect(aquarium.longitude == 139.72)
        #expect(aquarium.aquariumDescription == "都会のオアシス")
        #expect(aquarium.region == "関東")
        #expect(aquarium.representativeFish == "tropicalfish.fill")
        #expect(aquarium.fishIconSize == 4)
        #expect(aquarium.address == "東京都豊島区")
        #expect(aquarium.affiliateLink == "https://example.com")
        #expect(aquarium.stableId == "sunshine")
        #expect(aquarium.officialUrl == "https://sunshinecity.jp/aquarium/")
    }

    @Test("Aquarium初期化: デフォルト値")
    @MainActor
    func testAquariumDefaultValues() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let aquarium = Aquarium()
        context.insert(aquarium)
        try context.save()

        #expect(aquarium.name == "")
        #expect(aquarium.latitude == 0.0)
        #expect(aquarium.longitude == 0.0)
        #expect(aquarium.aquariumDescription == "")
        #expect(aquarium.region == "")
        #expect(aquarium.representativeFish == "fish.fill")
        #expect(aquarium.fishIconSize == 3)
        #expect(aquarium.address == nil)
        #expect(aquarium.affiliateLink == nil)
        #expect(aquarium.stableId == "")
        #expect(aquarium.officialUrl == nil)
    }
}
