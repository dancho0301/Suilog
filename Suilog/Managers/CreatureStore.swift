//
//  CreatureStore.swift
//  Suilog
//
//  生き物マスター（creatures.json）を読み込んで提供するストア。
//  現状はアプリにバンドルしたJSONを読み込む（将来Firebase配信に切替可能）。
//

import Foundation
import Combine

@MainActor
final class CreatureStore: ObservableObject {
    @Published private(set) var creatures: [Creature] = []

    /// IDから生き物を引くための辞書
    private(set) var creaturesById: [String: Creature] = [:]

    init() {
        loadFromBundle()
    }

    /// バンドルされた creatures.json を読み込む
    private func loadFromBundle() {
        guard let url = Bundle.main.url(forResource: "creatures", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ creatures.json が見つかりません")
            return
        }
        do {
            let response = try JSONDecoder().decode(CreatureResponse.self, from: data)
            creatures = response.creatures
            creaturesById = Dictionary(uniqueKeysWithValues: response.creatures.map { ($0.id, $0) })
            print("✅ 生き物マスターを読み込みました（\(creatures.count)種）")
        } catch {
            print("⚠️ creatures.json のデコードに失敗: \(error)")
        }
    }

    /// 全生き物数
    var totalCount: Int { creatures.count }

    /// 指定IDの生き物
    func creature(for id: String) -> Creature? {
        creaturesById[id]
    }

    /// カテゴリ順にグループ化した生き物（図鑑のセクション表示用）
    var groupedByCategory: [(category: CreatureCategory, creatures: [Creature])] {
        Dictionary(grouping: creatures, by: \.category)
            .map { (category: $0.key, creatures: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    /// 重複を除いた絵文字一覧（プロフィールアイコン選択などに使用）
    var uniqueEmojis: [String] {
        var seen = Set<String>()
        return creatures.compactMap { creature in
            guard seen.insert(creature.emoji).inserted else { return nil }
            return creature.emoji
        }
    }
}
