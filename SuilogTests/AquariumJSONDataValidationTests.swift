//
//  AquariumJSONDataValidationTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/11.
//
//  firebase/public/aquariums.json（配信データ）の内容を検証するテスト。
//  データ更新ミスによるアプリ側の不具合（地域フィルタの破綻、不正な座標、
//  危険なURLなど）をデプロイ前に検出する。
//

import Testing
import Foundation
@testable import Suilog

@Suite
struct AquariumJSONDataValidationTests {

    /// リポジトリ内の配信用JSONを読み込む
    /// （テストはソースと同じマシンで実行される前提。見つからない場合はスキップ）
    private func loadResponse() throws -> AquariumResponse {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SuilogTests/
            .deletingLastPathComponent() // リポジトリルート
            .appendingPathComponent("firebase/public/aquariums.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TestSkipError(message: "aquariums.json が見つかりません: \(url.path)")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AquariumResponse.self, from: data)
    }

    private struct TestSkipError: Error {
        let message: String
    }

    // MARK: - 基本構造

    @Test("配信JSONがアプリのデータモデルでデコードできる")
    func testDecodable() throws {
        let response = try loadResponse()
        #expect(response.version >= 1)
        #expect(response.aquariums.count >= 100, "水族館データが大幅に減っていないこと")
    }

    @Test("名前が空でなく、重複していない")
    func testNamesValid() throws {
        let response = try loadResponse()
        let names = response.aquariums.map(\.name)

        #expect(names.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(Set(names).count == names.count, "水族館名が重複していないこと")
    }

    @Test("緯度経度が日本周辺の範囲内")
    func testCoordinatesInJapan() throws {
        let response = try loadResponse()
        for aquarium in response.aquariums {
            #expect((24.0...46.0).contains(aquarium.latitude),
                    "\(aquarium.name) の緯度が範囲外: \(aquarium.latitude)")
            #expect((122.0...154.0).contains(aquarium.longitude),
                    "\(aquarium.name) の経度が範囲外: \(aquarium.longitude)")
        }
    }

    @Test("fishIconSizeが1〜5の範囲内")
    func testFishIconSizeRange() throws {
        let response = try loadResponse()
        for aquarium in response.aquariums {
            #expect((1...5).contains(aquarium.fishIconSize),
                    "\(aquarium.name) の fishIconSize が範囲外: \(aquarium.fishIconSize)")
        }
    }

    @Test("URL系フィールドはhttpsのみ（SafeURLの検証を通ること）")
    func testURLFieldsAreSafe() throws {
        let response = try loadResponse()
        for aquarium in response.aquariums {
            if let officialUrl = aquarium.officialUrl, !officialUrl.isEmpty {
                #expect(SafeURL.webURL(from: officialUrl) != nil,
                        "\(aquarium.name) の officialUrl が不正: \(officialUrl)")
            }
            if let affiliateLink = aquarium.affiliateLink, !affiliateLink.isEmpty {
                #expect(SafeURL.webURL(from: affiliateLink) != nil,
                        "\(aquarium.name) の affiliateLink が不正: \(affiliateLink)")
            }
        }
    }

    // MARK: - v21形式対応の検証
    //
    // v21 では region が都道府県名、stableId は "id" キーになっている。
    // アプリ側で RegionMapper による正規化と id フォールバックに対応済みのため、
    // 「正規化後に7地域に収まること」「フォールバック込みでIDが取れること」を検証する。

    @Test("regionが正規化後に7地域のいずれかになる")
    func testRegionsNormalizeToValidRegions() throws {
        let response = try loadResponse()
        for aquarium in response.aquariums {
            let normalized = RegionMapper.normalize(aquarium.region)
            #expect(RegionMapper.validRegions.contains(normalized),
                    "\(aquarium.name) の region が7地域に正規化できない: \(aquarium.region)")
        }
    }

    @Test("全エントリに安定ID（stableIdまたはid）が設定されている")
    func testStableIdsPresent() throws {
        let response = try loadResponse()
        for aquarium in response.aquariums {
            let stableId = aquarium.stableId ?? ""
            #expect(!stableId.isEmpty, "\(aquarium.name) に stableId / id がない")
        }
    }

    @Test("stableIdが設定されている場合は重複していない")
    func testStableIdsUnique() throws {
        let response = try loadResponse()
        let ids = response.aquariums.compactMap(\.stableId).filter { !$0.isEmpty }
        #expect(Set(ids).count == ids.count, "stableId が重複していないこと")
    }
}
