//
//  AquariumData.swift
//  Suilog
//
//  Created by dancho on 2026/01/02.
//

import Foundation

struct AquariumData: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let description: String
    let region: String
    let representativeFish: String
    let fishIconSize: Int
    let address: String
    let affiliateLink: String?
    /// 安定ID: 名称変更に対応するための一意識別子（後方互換のためオプショナル）
    let stableId: String?
    /// 公式HPのURL
    let officialUrl: String?
    /// 営業時間
    let businessHours: String?
    /// 入館料金
    let admissionFee: String?
    /// 電話番号
    let phoneNumber: String?
}

// カスタムデコード: stableId が無いJSON（v21形式）では "id" キーをフォールバックとして使う。
// extension に定義することで memberwise イニシャライザを維持する。
extension AquariumData {
    private enum JSONKeys: String, CodingKey {
        case name, latitude, longitude, description, region
        case representativeFish, fishIconSize, address, affiliateLink
        case stableId, id, officialUrl, businessHours, admissionFee, phoneNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKeys.self)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        description = try container.decode(String.self, forKey: .description)
        region = try container.decode(String.self, forKey: .region)
        representativeFish = try container.decode(String.self, forKey: .representativeFish)
        fishIconSize = try container.decode(Int.self, forKey: .fishIconSize)
        address = try container.decode(String.self, forKey: .address)
        affiliateLink = try container.decodeIfPresent(String.self, forKey: .affiliateLink)
        let explicitStableId = try container.decodeIfPresent(String.self, forKey: .stableId)
        let alternateId = try container.decodeIfPresent(String.self, forKey: .id)
        stableId = explicitStableId ?? alternateId
        officialUrl = try container.decodeIfPresent(String.self, forKey: .officialUrl)
        businessHours = try container.decodeIfPresent(String.self, forKey: .businessHours)
        admissionFee = try container.decodeIfPresent(String.self, forKey: .admissionFee)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
    }
}

struct AquariumResponse: Codable {
    let version: Int
    let aquariums: [AquariumData]
}
