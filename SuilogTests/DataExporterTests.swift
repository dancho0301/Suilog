//
//  DataExporterTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/11.
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

/// 訪問記録JSONエクスポートのテスト
@Suite(.serialized)
struct DataExporterTests {

    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// エクスポートしたJSONを辞書として読み込むヘルパー
    private func exportAndParse(_ records: [VisitRecord]) throws -> [String: Any] {
        let url = try DataExporter.exportVisitRecords(records)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try #require(json)
    }

    // MARK: - 基本構造

    @Test("エクスポートファイルが生成され、基本構造を持つ")
    @MainActor
    func testExportBasicStructure() throws {
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
            visitDate: Date(timeIntervalSince1970: 1_700_000_000),
            memo: "楽しかった",
            checkInType: .location,
            aquarium: aquarium
        )
        context.insert(visit)
        try context.save()

        let json = try exportAndParse([visit])

        #expect(json["appName"] as? String == "Suilog")
        #expect(json["recordCount"] as? Int == 1)

        let visits = try #require(json["visitRecords"] as? [[String: Any]])
        #expect(visits.count == 1)
        #expect(visits[0]["aquariumName"] as? String == "テスト水族館")
        #expect(visits[0]["region"] as? String == "関東")
        #expect(visits[0]["memo"] as? String == "楽しかった")
        #expect(visits[0]["checkInType"] as? String == "location")
        #expect(visits[0]["photoCount"] as? Int == 0)
    }

    @Test("ファイル名がsuilog-visits-プレフィックスのjson")
    func testExportFileName() throws {
        let url = try DataExporter.exportVisitRecords([])
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent.hasPrefix("suilog-visits-"))
        #expect(url.pathExtension == "json")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - 内容の検証

    @Test("訪問日はISO8601形式で出力される")
    @MainActor
    func testExportDateFormat() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let visit = VisitRecord(visitDate: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(visit)
        try context.save()

        let json = try exportAndParse([visit])
        let visits = try #require(json["visitRecords"] as? [[String: Any]])
        let dateString = try #require(visits[0]["visitDate"] as? String)

        let parsed = ISO8601DateFormatter().date(from: dateString)
        #expect(parsed == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("新しい順にソートされて出力される")
    @MainActor
    func testExportSortedByDateDescending() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let old = VisitRecord(visitDate: Date(timeIntervalSince1970: 1_000_000), memo: "古い記録")
        let new = VisitRecord(visitDate: Date(timeIntervalSince1970: 2_000_000), memo: "新しい記録")
        context.insert(old)
        context.insert(new)
        try context.save()

        // 古い順に渡してもエクスポートは新しい順
        let json = try exportAndParse([old, new])
        let visits = try #require(json["visitRecords"] as? [[String: Any]])

        #expect(visits[0]["memo"] as? String == "新しい記録")
        #expect(visits[1]["memo"] as? String == "古い記録")
    }

    @Test("写真枚数が1枚目＋追加写真の合計になる")
    @MainActor
    func testExportPhotoCount() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let visit = VisitRecord(
            photoData: Data([0x01]),
            additionalPhotosData: [Data([0x02]), Data([0x03])]
        )
        context.insert(visit)
        try context.save()

        let json = try exportAndParse([visit])
        let visits = try #require(json["visitRecords"] as? [[String: Any]])
        #expect(visits[0]["photoCount"] as? Int == 3)
    }

    @Test("水族館が削除済み（nil）の記録は「不明」として出力される")
    @MainActor
    func testExportOrphanRecord() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let visit = VisitRecord(memo: "孤立した記録")
        context.insert(visit)
        try context.save()

        let json = try exportAndParse([visit])
        let visits = try #require(json["visitRecords"] as? [[String: Any]])
        #expect(visits[0]["aquariumName"] as? String == "不明")
        #expect(visits[0]["region"] as? String == "")
    }

    @Test("記録0件でもエクスポートできる")
    func testExportEmpty() throws {
        let json = try exportAndParse([])
        #expect(json["recordCount"] as? Int == 0)
        let visits = try #require(json["visitRecords"] as? [[String: Any]])
        #expect(visits.isEmpty)
    }
}
