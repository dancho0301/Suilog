//
//  CloudSettingsManager.swift
//  Suilog
//
//  Created by Claude on 2026/03/03.
//

import Foundation

/// iCloud Key-Value Storeを使った設定同期マネージャー
/// 機種変更時にUserDefaults設定をiCloud経由で引き継ぐ
final class CloudSettingsManager {
    static let shared = CloudSettingsManager()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let localDefaults = UserDefaults.standard

    // 同期対象のキー
    static let selectedThemeIdKey = "SelectedThemeId"
    static let aquariumDataVersionKey = "AquariumDataVersion"
    static let nicknameKey = "UserNickname"
    static let profileIconKey = "ProfileIcon"

    /// UserDefaultsからの移行済みフラグ
    private let migrationCompletedKey = "CloudSettingsMigrationCompleted"

    private init() {}

    /// 初期化：iCloud KVSの変更通知を登録し、既存のUserDefaultsデータを移行する
    func setup() {
        // iCloud KVSの変更通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )

        // 同期を開始
        kvStore.synchronize()

        // 既存のUserDefaultsデータをiCloud KVSに移行（初回のみ）
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - 読み書き

    /// 文字列を取得（iCloud KVS優先、フォールバックとしてUserDefaults）
    func string(forKey key: String) -> String? {
        if let cloudValue = kvStore.string(forKey: key) {
            return cloudValue
        }
        return localDefaults.string(forKey: key)
    }

    /// 整数を取得（iCloud KVSにデータがあればそちらを優先）
    func integer(forKey key: String) -> Int {
        let cloudValue = kvStore.longLong(forKey: key)
        if cloudValue != 0 {
            return Int(cloudValue)
        }
        return localDefaults.integer(forKey: key)
    }

    /// 文字列を保存（iCloud KVSとUserDefaultsの両方に保存）
    func set(_ value: String?, forKey key: String) {
        kvStore.set(value, forKey: key)
        localDefaults.set(value, forKey: key)
    }

    /// 整数を保存（iCloud KVSとUserDefaultsの両方に保存）
    func set(_ value: Int, forKey key: String) {
        kvStore.set(Int64(value), forKey: key)
        localDefaults.set(value, forKey: key)
    }

    // MARK: - iCloud KVS変更通知

    @objc private func kvStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        // サーバー側の変更（他デバイスからの同期または初回ダウンロード）を反映
        guard reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }

        for key in changedKeys {
            switch key {
            case Self.selectedThemeIdKey:
                if let value = kvStore.string(forKey: key) {
                    localDefaults.set(value, forKey: key)
                    // テーマ変更の通知を送信
                    NotificationCenter.default.post(
                        name: .cloudThemeDidChange,
                        object: nil,
                        userInfo: ["themeId": value]
                    )
                    print("☁️ iCloudからテーマ設定を同期: \(value)")
                }
            case Self.aquariumDataVersionKey:
                let value = kvStore.longLong(forKey: key)
                if value != 0 {
                    localDefaults.set(Int(value), forKey: key)
                    print("☁️ iCloudからデータバージョンを同期: \(value)")
                }
            case Self.nicknameKey:
                if let value = kvStore.string(forKey: key) {
                    localDefaults.set(value, forKey: key)
                    print("☁️ iCloudからニックネームを同期")
                }
            case Self.profileIconKey:
                if let value = kvStore.string(forKey: key) {
                    localDefaults.set(value, forKey: key)
                    print("☁️ iCloudからプロフィールアイコンを同期")
                }
            default:
                break
            }
        }
    }

    // MARK: - UserDefaultsからの移行

    private func migrateFromUserDefaultsIfNeeded() {
        guard !localDefaults.bool(forKey: migrationCompletedKey) else { return }

        // テーマ設定の移行
        if let themeId = localDefaults.string(forKey: Self.selectedThemeIdKey),
           kvStore.string(forKey: Self.selectedThemeIdKey) == nil {
            kvStore.set(themeId, forKey: Self.selectedThemeIdKey)
            print("☁️ テーマ設定をiCloud KVSに移行: \(themeId)")
        }

        // データバージョンの移行
        let dataVersion = localDefaults.integer(forKey: Self.aquariumDataVersionKey)
        if dataVersion > 0 && kvStore.longLong(forKey: Self.aquariumDataVersionKey) == 0 {
            kvStore.set(Int64(dataVersion), forKey: Self.aquariumDataVersionKey)
            print("☁️ データバージョンをiCloud KVSに移行: \(dataVersion)")
        }

        localDefaults.set(true, forKey: migrationCompletedKey)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// iCloudからテーマ設定が同期された時の通知
    static let cloudThemeDidChange = Notification.Name("cloudThemeDidChange")
}
