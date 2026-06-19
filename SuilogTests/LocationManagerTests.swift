//
//  LocationManagerTests.swift
//  SuilogTests
//
//  チェックイン可否の中核である距離計算・範囲判定ロジックのテスト。
//

import Testing
import Foundation
import CoreLocation
@testable import Suilog

@Suite
struct LocationManagerTests {

    /// デバッグ用の位置偽装・常時許可がテストに干渉しないようにする
    @MainActor
    private func makeManager() -> LocationManager {
        #if DEBUG
        DebugSettings.shared.isDebugModeEnabled = false
        #endif
        return LocationManager()
    }

    // 東京駅付近を基準点とする
    private let tokyo = CLLocation(latitude: 35.6812, longitude: 139.7671)

    @Test("現在地が未取得なら距離はnil")
    @MainActor
    func testDistanceNilWhenNoLocation() {
        let manager = makeManager()
        let coordinate = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        #expect(manager.distance(to: coordinate) == nil)
    }

    @Test("同一座標までの距離はほぼ0")
    @MainActor
    func testDistanceToSamePoint() {
        let manager = makeManager()
        manager.currentLocation = tokyo
        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let distance = manager.distance(to: coordinate)
        #expect(distance != nil)
        #expect((distance ?? .infinity) < 1.0)
    }

    @Test("離れた座標までの距離が妥当（東京〜横浜は約25-30km）")
    @MainActor
    func testDistanceToFarPoint() {
        let manager = makeManager()
        manager.currentLocation = tokyo
        // 横浜駅付近
        let yokohama = CLLocationCoordinate2D(latitude: 35.4660, longitude: 139.6224)
        let distance = manager.distance(to: yokohama)
        #expect(distance != nil)
        let km = (distance ?? 0) / 1000
        #expect(km > 20 && km < 35)
    }

    @Test("1km以内の水族館は範囲内")
    @MainActor
    func testWithinRangeTrue() {
        let manager = makeManager()
        manager.currentLocation = tokyo
        // 基準点から約500m（緯度0.0045度 ≒ 500m）
        let aquarium = Aquarium(
            name: "近くの水族館",
            latitude: 35.6812 + 0.0045,
            longitude: 139.7671
        )
        #expect(manager.isWithinRange(of: aquarium, radius: 1000) == true)
    }

    @Test("1kmより遠い水族館は範囲外")
    @MainActor
    func testWithinRangeFalse() {
        let manager = makeManager()
        manager.currentLocation = tokyo
        // 基準点から約3km（緯度0.027度 ≒ 3km）
        let aquarium = Aquarium(
            name: "遠くの水族館",
            latitude: 35.6812 + 0.027,
            longitude: 139.7671
        )
        #expect(manager.isWithinRange(of: aquarium, radius: 1000) == false)
    }

    @Test("半径を広げれば範囲内になる")
    @MainActor
    func testWithinRangeWithLargerRadius() {
        let manager = makeManager()
        manager.currentLocation = tokyo
        let aquarium = Aquarium(
            name: "やや遠い水族館",
            latitude: 35.6812 + 0.027,
            longitude: 139.7671
        )
        #expect(manager.isWithinRange(of: aquarium, radius: 1000) == false)
        #expect(manager.isWithinRange(of: aquarium, radius: 5000) == true)
    }

    @Test("現在地が未取得なら範囲外と判定")
    @MainActor
    func testWithinRangeFalseWhenNoLocation() {
        let manager = makeManager()
        let aquarium = Aquarium(name: "水族館", latitude: 35.6812, longitude: 139.7671)
        #expect(manager.isWithinRange(of: aquarium, radius: 1000) == false)
    }
}
