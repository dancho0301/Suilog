//
//  Creature.swift
//  Suilog
//
//  生き物図鑑のマスターデータモデル（creatures.json）。
//

import Foundation

/// 生き物のカテゴリ
enum CreatureCategory: String, Codable, CaseIterable, Identifiable {
    case fish
    case mammal
    case crustacean
    case mollusk
    case invertebrate
    case echinoderm
    case amphibian
    case reptile
    case bird
    case insect
    case other

    var id: String { rawValue }

    /// 不明なカテゴリ文字列を安全に変換する
    init(raw: String) {
        self = CreatureCategory(rawValue: raw) ?? .other
    }

    /// 図鑑での表示名
    var displayName: String {
        switch self {
        case .fish: return "魚類"
        case .mammal: return "哺乳類"
        case .crustacean: return "甲殻類"
        case .mollusk: return "軟体動物"
        case .invertebrate: return "無脊椎動物"
        case .echinoderm: return "棘皮動物"
        case .amphibian: return "両生類"
        case .reptile: return "は虫類"
        case .bird: return "鳥類"
        case .insect: return "昆虫"
        case .other: return "その他"
        }
    }

    /// 図鑑のセクション表示順
    var sortOrder: Int {
        switch self {
        case .fish: return 0
        case .mammal: return 1
        case .crustacean: return 2
        case .mollusk: return 3
        case .invertebrate: return 4
        case .echinoderm: return 5
        case .amphibian: return 6
        case .reptile: return 7
        case .bird: return 8
        case .insect: return 9
        case .other: return 10
        }
    }
}

/// 生き物マスター1件
struct Creature: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let nameEn: String
    let emoji: String
    let category: CreatureCategory

    private enum CodingKeys: String, CodingKey {
        case id, name, nameEn, emoji, category
    }

    init(id: String, name: String, nameEn: String, emoji: String, category: CreatureCategory) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.emoji = emoji
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn) ?? ""
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🐟"
        // 未知のカテゴリ文字列でもクラッシュせず .other にフォールバック
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "other"
        category = CreatureCategory(raw: rawCategory)
    }
}

/// creatures.json のレスポンス構造
struct CreatureResponse: Codable {
    let version: Int
    let creatures: [Creature]
}
