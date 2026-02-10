//
//  DebugSettings.swift
//  Suilog
//
//  Created by Claude on 2026/02/10.
//

#if DEBUG
import Foundation
import Combine
import CoreLocation

@MainActor
final class DebugSettings: ObservableObject {
    static let shared = DebugSettings()

    /// デバッグモードのマスタースイッチ
    @Published var isDebugModeEnabled = false

    // MARK: - チェックイン設定

    /// 距離判定を常にtrueにする
    @Published var alwaysAllowCheckIn = false

    /// カスタム距離閾値を使用する
    @Published var useCustomRadius = false

    /// カスタム距離閾値（メートル）
    @Published var customRadius: Double = 1000

    // MARK: - 位置偽装

    /// GPS位置を偽装する
    @Published var useFakeLocation = false

    /// 偽装する緯度
    @Published var fakeLatitude: Double = 35.6762

    /// 偽装する経度
    @Published var fakeLongitude: Double = 139.6503

    /// 偽装位置のCLLocation
    var fakeLocation: CLLocation {
        CLLocation(latitude: fakeLatitude, longitude: fakeLongitude)
    }

    // MARK: - Computed

    /// 常時チェックインが有効か（マスタースイッチ & 個別設定の両方がON）
    var isAlwaysAllowCheckInActive: Bool {
        isDebugModeEnabled && alwaysAllowCheckIn
    }

    /// カスタム距離閾値が有効か
    var isCustomRadiusActive: Bool {
        isDebugModeEnabled && useCustomRadius && !alwaysAllowCheckIn
    }

    /// 位置偽装が有効か
    var isFakeLocationActive: Bool {
        isDebugModeEnabled && useFakeLocation
    }

    /// 有効な距離閾値を返す
    var effectiveRadius: Double {
        if isCustomRadiusActive {
            return customRadius
        }
        return 1000 // デフォルト1km
    }

    private init() {}
}

/// 水族館の位置プリセット
struct DebugLocationPreset: Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double

    static let presets: [DebugLocationPreset] = [
        DebugLocationPreset(name: "新江ノ島水族館", latitude: 35.3101, longitude: 139.4790),
        DebugLocationPreset(name: "美ら海水族館", latitude: 26.6936, longitude: 127.8778),
        DebugLocationPreset(name: "海遊館", latitude: 34.6545, longitude: 135.4290),
        DebugLocationPreset(name: "すみだ水族館", latitude: 35.7101, longitude: 139.8107),
        DebugLocationPreset(name: "鳥羽水族館", latitude: 34.4839, longitude: 136.8430),
        DebugLocationPreset(name: "アクアパーク品川", latitude: 35.6206, longitude: 139.7319),
    ]
}
#endif
