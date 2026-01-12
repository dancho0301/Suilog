//
//  DataSeeder.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData

@MainActor
class DataSeeder {
    // データバージョン管理用のキー
    private static let dataVersionKey = "AquariumDataVersion"

    static func seedAquariums(context: ModelContext) async {
        // 既存の水族館データを取得
        let descriptor = FetchDescriptor<Aquarium>()
        let existingAquariums = (try? context.fetch(descriptor)) ?? []

        // Webから最新のデータを取得
        guard let response = await AquariumJSONLoader.fetchAquariums() else {
            // Web取得失敗時の処理
            if existingAquariums.isEmpty {
                // 初回起動時（データベースが空）の場合はエラー
                print("❌ 初回起動時のデータ取得に失敗しました。オンライン環境で再起動してください。")
            } else {
                // 既存データがある場合は静かにスキップ（オフライン対応）
                print("ℹ️ オフラインのため更新をスキップしました。既存データで起動します。")
            }
            return
        }

        // 保存されているデータバージョンを取得
        let savedVersion = UserDefaults.standard.integer(forKey: dataVersionKey)
        let latestVersion = response.version

        // データバージョンが最新の場合は何もしない
        if savedVersion >= latestVersion {
            print("✅ 水族館データは最新です (v\(savedVersion))")
            return
        }

        // 既存データがある場合は更新、ない場合は新規追加
        if !existingAquariums.isEmpty {
            print("🔄 水族館データを更新します (v\(savedVersion) → v\(latestVersion))")
            updateAquariums(context: context, existing: existingAquariums, newData: response.aquariums)
        } else {
            print("➕ 水族館データを新規追加します (v\(latestVersion))")
            insertAquariums(context: context, aquariumData: response.aquariums)
        }

        // データバージョンを更新
        UserDefaults.standard.set(latestVersion, forKey: dataVersionKey)
    }

    /// 既存の水族館データを更新（訪問記録を保持）
    private static func updateAquariums(context: ModelContext, existing: [Aquarium], newData: [AquariumData]) {
        // 名前をキーにした辞書を作成
        var existingDict: [String: Aquarium] = [:]
        for aquarium in existing {
            existingDict[aquarium.name] = aquarium
        }

        for newAquarium in newData {
            if let existingAquarium = existingDict[newAquarium.name] {
                // 既存データの場合は、位置情報と説明のみ更新（訪問記録は保持）
                existingAquarium.latitude = newAquarium.latitude
                existingAquarium.longitude = newAquarium.longitude
                existingAquarium.aquariumDescription = newAquarium.description
                existingAquarium.region = newAquarium.region
                existingAquarium.representativeFish = newAquarium.representativeFish
                existingAquarium.fishIconSize = newAquarium.fishIconSize
                existingAquarium.address = newAquarium.address
                existingAquarium.affiliateLink = newAquarium.affiliateLink
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
                    affiliateLink: newAquarium.affiliateLink
                )
                context.insert(aquarium)
                print("  ➕ 追加: \(newAquarium.name)")
            }
            existingDict.removeValue(forKey: newAquarium.name)
        }

        // 削除された水族館の処理（訪問記録がある場合は保持、ない場合は削除）
        for (name, aquarium) in existingDict {
            if aquarium.visits.isEmpty {
                context.delete(aquarium)
                print("  🗑️ 削除: \(name)")
            } else {
                print("  ⚠️ 訪問記録があるため保持: \(name)")
            }
        }

        do {
            try context.save()
            print("✅ 水族館データの更新が完了しました")
        } catch {
            print("❌ データの更新に失敗しました: \(error)")
        }
    }

    /// 新規に水族館データを挿入
    private static func insertAquariums(context: ModelContext, aquariumData: [AquariumData]) {
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
                affiliateLink: data.affiliateLink
            )
            context.insert(aquarium)
        }

        do {
            try context.save()
            print("✅ \(aquariumData.count)件の水族館データを追加しました")
        } catch {
            print("❌ データの保存に失敗しました: \(error)")
        }
    }

    /// 水族館データの取得（JSONファイルから読み込み）
    private static func getAquariumData() -> [(name: String, latitude: Double, longitude: Double, description: String, region: String, representativeFish: String, fishIconSize: Int, address: String, affiliateLink: String?)] {
        let aquariumDataArray = AquariumJSONLoader.loadAquariums()

        return aquariumDataArray.map { aquarium in
            (
                name: aquarium.name,
                latitude: aquarium.latitude,
                longitude: aquarium.longitude,
                description: aquarium.description,
                region: aquarium.region,
                representativeFish: aquarium.representativeFish,
                fishIconSize: aquarium.fishIconSize,
                address: aquarium.address,
                affiliateLink: aquarium.affiliateLink
            )
        }
    }
}
