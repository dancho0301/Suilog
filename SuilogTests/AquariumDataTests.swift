//
//  AquariumDataTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/01/14.
//

import Testing
import Foundation
@testable import Suilog

/// AquariumDataのJSONデコードをテストする
@Suite
struct AquariumDataTests {

    // MARK: - JSONデコードテスト

    @Test("stableIdありのJSONをデコード")
    func testDecodeWithStableId() throws {
        let json = """
        {
            "name": "サンシャイン水族館",
            "latitude": 35.72,
            "longitude": 139.72,
            "description": "都会のオアシス",
            "region": "関東",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "東京都豊島区",
            "affiliateLink": "https://example.com",
            "stableId": "sunshine-aquarium"
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.name == "サンシャイン水族館")
        #expect(aquarium.stableId == "sunshine-aquarium")
        #expect(aquarium.latitude == 35.72)
        #expect(aquarium.longitude == 139.72)
        #expect(aquarium.region == "関東")
        #expect(aquarium.affiliateLink == "https://example.com")
    }

    @Test("stableIdなしのJSONをデコード（後方互換性）")
    func testDecodeWithoutStableId() throws {
        let json = """
        {
            "name": "海遊館",
            "latitude": 34.65,
            "longitude": 135.43,
            "description": "世界最大級",
            "region": "近畿",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "大阪府大阪市",
            "affiliateLink": null
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.name == "海遊館")
        #expect(aquarium.stableId == nil) // オプショナルなのでnilになる
        #expect(aquarium.affiliateLink == nil)
    }

    @Test("AquariumResponseをデコード")
    func testDecodeResponse() throws {
        let json = """
        {
            "version": 14,
            "aquariums": [
                {
                    "name": "水族館A",
                    "latitude": 35.0,
                    "longitude": 139.0,
                    "description": "説明A",
                    "region": "関東",
                    "representativeFish": "fish.fill",
                    "fishIconSize": 3,
                    "address": "住所A",
                    "affiliateLink": null,
                    "stableId": "aquarium-a"
                },
                {
                    "name": "水族館B",
                    "latitude": 34.0,
                    "longitude": 135.0,
                    "description": "説明B",
                    "region": "近畿",
                    "representativeFish": "seal.fill",
                    "fishIconSize": 4,
                    "address": "住所B",
                    "affiliateLink": "https://example.com"
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AquariumResponse.self, from: data)

        #expect(response.version == 14)
        #expect(response.aquariums.count == 2)
        #expect(response.aquariums[0].stableId == "aquarium-a")
        #expect(response.aquariums[1].stableId == nil)
    }

    @Test("空のstableIdをデコード")
    func testDecodeEmptyStableId() throws {
        let json = """
        {
            "name": "テスト水族館",
            "latitude": 35.0,
            "longitude": 139.0,
            "description": "テスト",
            "region": "関東",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "テスト住所",
            "affiliateLink": null,
            "stableId": ""
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.stableId == "") // 空文字として読み込まれる
    }

    // MARK: - officialUrl Tests

    @Test("officialUrlありのJSONをデコード")
    func testDecodeWithOfficialUrl() throws {
        let json = """
        {
            "name": "新江ノ島水族館",
            "latitude": 35.31,
            "longitude": 139.48,
            "description": "湘南の海を体感",
            "region": "関東",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "神奈川県藤沢市",
            "affiliateLink": null,
            "stableId": "enoshima",
            "officialUrl": "https://www.enosui.com/"
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.name == "新江ノ島水族館")
        #expect(aquarium.officialUrl == "https://www.enosui.com/")
    }

    @Test("officialUrlなしのJSONをデコード（後方互換性）")
    func testDecodeWithoutOfficialUrl() throws {
        let json = """
        {
            "name": "海遊館",
            "latitude": 34.65,
            "longitude": 135.43,
            "description": "世界最大級",
            "region": "近畿",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "大阪府大阪市",
            "affiliateLink": null
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.officialUrl == nil)
    }

    // MARK: - v21形式（idキー）の互換性 Tests

    @Test("stableIdの代わりにidキーを持つJSON（v21形式）をデコード")
    func testDecodeWithIdKeyFallback() throws {
        let json = """
        {
            "name": "新さっぽろサンピアザ水族館",
            "latitude": 43.037,
            "longitude": 141.47,
            "description": "都市型水族館",
            "region": "北海道",
            "representativeFish": "Seal",
            "fishIconSize": 3,
            "address": "北海道札幌市厚別区",
            "affiliateLink": null,
            "id": "sunpiazza-aquarium",
            "creatureIds": ["clione", "goldfish"]
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        // idキーがstableIdとして読み込まれる
        #expect(aquarium.stableId == "sunpiazza-aquarium")
        // 未知のフィールド（creatureIds）は無視される
        #expect(aquarium.name == "新さっぽろサンピアザ水族館")
    }

    @Test("stableIdとidの両方がある場合はstableIdを優先")
    func testStableIdTakesPrecedenceOverId() throws {
        let json = """
        {
            "name": "テスト水族館",
            "latitude": 35.0,
            "longitude": 139.0,
            "description": "テスト",
            "region": "関東",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "テスト住所",
            "affiliateLink": null,
            "stableId": "stable-id",
            "id": "alternate-id"
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)
        #expect(aquarium.stableId == "stable-id")
    }

    // MARK: - 営業時間・料金・電話番号 Tests

    @Test("営業時間・料金・電話番号ありのJSONをデコード")
    func testDecodeWithFacilityInfo() throws {
        let json = """
        {
            "name": "美ら海水族館",
            "latitude": 26.69,
            "longitude": 127.88,
            "description": "ジンベエザメ",
            "region": "九州・沖縄",
            "representativeFish": "fish.fill",
            "fishIconSize": 5,
            "address": "沖縄県本部町",
            "affiliateLink": null,
            "stableId": "churaumi",
            "officialUrl": "https://churaumi.okinawa/",
            "businessHours": "8:30〜18:30（繁忙期は20:00まで）",
            "admissionFee": "大人 2,180円 / 高校生 1,440円",
            "phoneNumber": "0980-48-3748"
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.businessHours == "8:30〜18:30（繁忙期は20:00まで）")
        #expect(aquarium.admissionFee == "大人 2,180円 / 高校生 1,440円")
        #expect(aquarium.phoneNumber == "0980-48-3748")
    }

    @Test("営業時間・料金・電話番号なしのJSONをデコード（後方互換性）")
    func testDecodeWithoutFacilityInfo() throws {
        let json = """
        {
            "name": "海遊館",
            "latitude": 34.65,
            "longitude": 135.43,
            "description": "世界最大級",
            "region": "近畿",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "大阪府大阪市",
            "affiliateLink": null
        }
        """

        let data = json.data(using: .utf8)!
        let aquarium = try JSONDecoder().decode(AquariumData.self, from: data)

        #expect(aquarium.businessHours == nil)
        #expect(aquarium.admissionFee == nil)
        #expect(aquarium.phoneNumber == nil)
    }

    // MARK: - エラーケース

    @Test("必須フィールドが欠けている場合はエラー")
    func testDecodeMissingRequiredField() {
        let json = """
        {
            "name": "テスト水族館",
            "latitude": 35.0
        }
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(AquariumData.self, from: data)
        }
    }

    @Test("不正な型の場合はエラー")
    func testDecodeInvalidType() {
        let json = """
        {
            "name": "テスト水族館",
            "latitude": "not a number",
            "longitude": 139.0,
            "description": "テスト",
            "region": "関東",
            "representativeFish": "fish.fill",
            "fishIconSize": 3,
            "address": "テスト住所",
            "affiliateLink": null
        }
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(AquariumData.self, from: data)
        }
    }
}
