//
//  DataSeeder.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData

/// データシード結果
enum SeedResult {
    case success
    case skippedOffline       // オフラインでスキップ（既存データあり）
    case errorNoData(String)  // 初回起動でデータ取得失敗
    case errorSaveFailed(String) // データ保存失敗
}

@MainActor
class DataSeeder {
    // データバージョン管理用のキー
    private static let dataVersionKey = "AquariumDataVersion"

    static func seedAquariums(context: ModelContext) async -> SeedResult {
        // 既存の水族館データを取得
        let descriptor = FetchDescriptor<Aquarium>()
        let existingAquariums = (try? context.fetch(descriptor)) ?? []

        // Webから最新のデータを取得
        let result = await AquariumJSONLoader.fetchAquariums()

        switch result {
        case .failure(let error):
            // Web取得失敗時の処理
            if existingAquariums.isEmpty {
                // 初回起動時（データベースが空）の場合はエラー
                print("❌ 初回起動時のデータ取得に失敗しました。オンライン環境で再起動してください。")
                return .errorNoData(error.localizedMessage)
            } else {
                // 既存データがある場合は静かにスキップ（オフライン対応）
                print("ℹ️ オフラインのため更新をスキップしました。既存データで起動します。")
                return .skippedOffline
            }

        case .success(let response):
            // 保存されているデータバージョンを取得
            let savedVersion = UserDefaults.standard.integer(forKey: dataVersionKey)
            let latestVersion = response.version

            // データバージョンが最新の場合は何もしない
            if savedVersion >= latestVersion {
                print("✅ 水族館データは最新です (v\(savedVersion))")
                return .success
            }

            // 既存データがある場合は更新、ない場合は新規追加
            var saveError: Error?
            if !existingAquariums.isEmpty {
                print("🔄 水族館データを更新します (v\(savedVersion) → v\(latestVersion))")
                saveError = updateAquariums(context: context, existing: existingAquariums, newData: response.aquariums)
            } else {
                print("➕ 水族館データを新規追加します (v\(latestVersion))")
                saveError = insertAquariums(context: context, aquariumData: response.aquariums)
            }

            if let error = saveError {
                return .errorSaveFailed("データの保存に失敗しました: \(error.localizedDescription)")
            }

            // データバージョンを更新
            UserDefaults.standard.set(latestVersion, forKey: dataVersionKey)
            return .success
        }
    }

    /// 既存の水族館データを更新（訪問記録を保持）
    /// - Returns: 保存エラーがあれば返す
    private static func updateAquariums(context: ModelContext, existing: [Aquarium], newData: [AquariumData]) -> Error? {
        // stableIdをキーにした辞書を作成（既存ユーザー用）
        var existingByStableId: [String: Aquarium] = [:]
        // 名前をキーにした辞書を作成（stableIdがない既存データ用のフォールバック）
        var existingByName: [String: Aquarium] = [:]

        for aquarium in existing {
            // stableIdが設定されている場合はそれを優先
            if !aquarium.stableId.isEmpty {
                existingByStableId[aquarium.stableId] = aquarium
            }
            // 名前でも検索できるようにする（フォールバック用）
            existingByName[aquarium.name] = aquarium
        }

        // マッチ済みの水族館を追跡（重複処理を防ぐ）
        var matchedAquariumIds: Set<UUID> = []

        for newAquarium in newData {
            var existingAquarium: Aquarium?

            // 1. まずstableIdでマッチングを試みる
            if let stableId = newAquarium.stableId, !stableId.isEmpty {
                existingAquarium = existingByStableId[stableId]
            }

            // 2. stableIdでマッチしなかった場合は名前でフォールバック
            if existingAquarium == nil {
                existingAquarium = existingByName[newAquarium.name]
            }

            if let existingAquarium = existingAquarium {
                // 既存データの場合は更新（訪問記録は保持）
                existingAquarium.name = newAquarium.name  // 名称変更に対応
                existingAquarium.latitude = newAquarium.latitude
                existingAquarium.longitude = newAquarium.longitude
                existingAquarium.aquariumDescription = newAquarium.description
                existingAquarium.region = newAquarium.region
                existingAquarium.representativeFish = newAquarium.representativeFish
                existingAquarium.fishIconSize = newAquarium.fishIconSize
                existingAquarium.address = newAquarium.address
                existingAquarium.affiliateLink = newAquarium.affiliateLink
                // stableIdを設定（既存データにstableIdがなければ設定）
                if let stableId = newAquarium.stableId, !stableId.isEmpty {
                    existingAquarium.stableId = stableId
                }
                matchedAquariumIds.insert(existingAquarium.id)
                print("  📝 更新: \(newAquarium.name)")
            } else {
                // 新規データの場合は追加
                let aquarium = Aquarium(
                    name: newAquarium.name,
                    latitude: newAquarium.latitude,
                    longitude: newAquarium.longitude,
                    description: newAquarium.description,
                    region: newAquarium.region,
                    representativeFish: newAquarium.representativeFish,
                    fishIconSize: newAquarium.fishIconSize,
                    address: newAquarium.address,
                    affiliateLink: newAquarium.affiliateLink,
                    stableId: newAquarium.stableId ?? ""
                )
                context.insert(aquarium)
                print("  ➕ 追加: \(newAquarium.name)")
            }
        }

        // 削除された水族館の処理（訪問記録がある場合は保持、ない場合は削除）
        for aquarium in existing {
            if !matchedAquariumIds.contains(aquarium.id) {
                if aquarium.safeVisits.isEmpty {
                    context.delete(aquarium)
                    print("  🗑️ 削除: \(aquarium.name)")
                } else {
                    print("  ⚠️ 訪問記録があるため保持: \(aquarium.name)")
                }
            }
        }

        do {
            try context.save()
            print("✅ 水族館データの更新が完了しました")
            return nil
        } catch {
            print("❌ データの更新に失敗しました: \(error)")
            return error
        }
    }

    /// 新規に水族館データを挿入
    /// - Returns: 保存エラーがあれば返す
    private static func insertAquariums(context: ModelContext, aquariumData: [AquariumData]) -> Error? {
        for data in aquariumData {
            let aquarium = Aquarium(
                name: data.name,
                latitude: data.latitude,
                longitude: data.longitude,
                description: data.description,
                region: data.region,
                representativeFish: data.representativeFish,
                fishIconSize: data.fishIconSize,
                address: data.address,
                affiliateLink: data.affiliateLink,
                stableId: data.stableId ?? ""
            )
            context.insert(aquarium)
        }

        do {
            try context.save()
            print("✅ \(aquariumData.count)件の水族館データを追加しました")
            return nil
        } catch {
            print("❌ データの保存に失敗しました: \(error)")
            return error
        }
    }
}
