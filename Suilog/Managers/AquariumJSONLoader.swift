//
//  AquariumJSONLoader.swift
//  Suilog
//
//  Created by dancho on 2026/01/02.
//

import Foundation

@MainActor
struct AquariumJSONLoader {
    private static let jsonURL = "https://suilog-3a94e.web.app/aquariums.json"

    /// Webから水族館データを非同期で取得
    static func fetchAquariums() async -> AquariumResponse? {
        guard let url = URL(string: jsonURL) else {
            print("❌ 無効なURL: \(jsonURL)")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ HTTPエラー: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }

            let decoder = JSONDecoder()
            let aquariumResponse = try decoder.decode(AquariumResponse.self, from: data)
            print("✅ Webから水族館データを取得しました (バージョン: \(aquariumResponse.version), \(aquariumResponse.aquariums.count)件)")
            return aquariumResponse
        } catch {
            print("❌ 水族館データの取得に失敗しました: \(error)")
            return nil
        }
    }

    /// バージョン番号のみを取得（軽量チェック用）
    static func fetchVersion() async -> Int? {
        guard let response = await fetchAquariums() else {
            return nil
        }
        return response.version
    }
}
