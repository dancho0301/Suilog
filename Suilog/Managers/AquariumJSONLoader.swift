//
//  AquariumJSONLoader.swift
//  Suilog
//
//  Created by dancho on 2026/01/02.
//

import Foundation

struct AquariumJSONLoader {
    static func loadAquariums() -> [AquariumData] {
        guard let url = Bundle.main.url(forResource: "aquariums", withExtension: "json") else {
            print("⚠️ aquariums.jsonが見つかりません")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let aquariums = try decoder.decode([AquariumData].self, from: data)
            print("✅ JSONから\(aquariums.count)件の水族館データを読み込みました")
            return aquariums
        } catch {
            print("❌ JSONの読み込みに失敗しました: \(error)")
            return []
        }
    }
}
