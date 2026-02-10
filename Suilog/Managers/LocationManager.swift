//
//  LocationManager.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLocationEnabled = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        isLocationEnabled = true
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isLocationEnabled = false
    }

    /// 距離計算に使用する現在位置（デバッグ時は偽装位置を使用）
    private var effectiveLocation: CLLocation? {
        #if DEBUG
        let debug = DebugSettings.shared
        if debug.isFakeLocationActive {
            return debug.fakeLocation
        }
        #endif
        return currentLocation
    }

    /// 指定された座標までの距離をメートルで返す
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let location = effectiveLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: targetLocation)
    }

    /// 指定された水族館が訪問可能範囲内にあるかを判定
    /// - Parameters:
    ///   - aquarium: 対象の水族館
    ///   - radius: 許容範囲（メートル）デフォルトは1000m（1km）
    func isWithinRange(of aquarium: Aquarium, radius: CLLocationDistance = 1000) -> Bool {
        #if DEBUG
        let debug = DebugSettings.shared
        if debug.isAlwaysAllowCheckInActive {
            return true
        }
        #endif
        let coordinate = CLLocationCoordinate2D(latitude: aquarium.latitude, longitude: aquarium.longitude)
        guard let distance = distance(to: coordinate) else { return false }
        #if DEBUG
        if debug.isCustomRadiusActive {
            return distance <= debug.effectiveRadius
        }
        #endif
        return distance <= radius
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 位置情報の取得に失敗: \(error.localizedDescription)")
    }
}
