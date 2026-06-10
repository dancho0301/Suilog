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

struct AquariumResponse: Codable {
    let version: Int
    let aquariums: [AquariumData]
}
