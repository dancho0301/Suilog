//
//  AquariumJSONLoader.swift
//  Suilog
//
//  Created by dancho on 2026/01/02.
//

import Foundation

/// 水族館データ取得時のエラー
enum AquariumLoadError: Error {
    case invalidURL
    case networkError(Error)
    case httpError(Int)
    case decodingError(Error)

    var localizedMessage: String {
        switch self {
        case .invalidURL:
            return "データの取得先URLが無効です"
        case .networkError:
            return "ネットワークに接続できません。インターネット接続を確認してください"
        case .httpError(let code):
            return "サーバーエラーが発生しました（コード: \(code)）"
        case .decodingError:
            return "データの読み込みに失敗しました"
        }
    }
}

struct AquariumJSONLoader {
    private static let defaultURL = "https://suilog-3a94e.web.app/aquariums.json"

    private static var jsonURL: String {
        #if DEBUG
        let settings = DebugSettings.shared
        if settings.isCustomDataURLActive {
            return settings.customDataURL
        }
        #endif
        return defaultURL
    }

    /// Webから水族館データを非同期で取得（バックグラウンドで実行）
    @MainActor
    static func fetchAquariums() async -> Result<AquariumResponse, AquariumLoadError> {
        let urlString = jsonURL
        guard let url = URL(string: urlString) else {
            print("❌ 無効なURL: \(urlString)")
            return .failure(.invalidURL)
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("❌ HTTPエラー: \(code)")
                return .failure(.httpError(code))
            }

            let decoder = JSONDecoder()
            let aquariumResponse = try decoder.decode(AquariumResponse.self, from: data)
            print("✅ Webから水族館データを取得しました (バージョン: \(aquariumResponse.version), \(aquariumResponse.aquariums.count)件)")
            return .success(aquariumResponse)
        } catch let error as DecodingError {
            print("❌ JSONデコードエラー: \(error)")
            return .failure(.decodingError(error))
        } catch {
            print("❌ ネットワークエラー: \(error)")
            return .failure(.networkError(error))
        }
    }

    /// バージョン番号のみを取得（軽量チェック用）
    static func fetchVersion() async -> Int? {
        switch await fetchAquariums() {
        case .success(let response):
            return response.version
        case .failure:
            return nil
        }
    }
}
