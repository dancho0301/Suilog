//
//  PhotoMetadataExtractorTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/01/16.
//

import Testing
import CoreLocation
@testable import Suilog

struct PhotoMetadataExtractorTests {

    // MARK: - テスト用ヘルパー

    /// テスト用の水族館を作成
    private func makeAquarium(
        name: String = "テスト水族館",
        latitude: Double = 35.6812,
        longitude: Double = 139.7671
    ) -> Aquarium {
        Aquarium(
            name: name,
            latitude: latitude,
            longitude: longitude,
            description: "テスト用",
            region: "テスト"
        )
    }

    // MARK: - isWithinRange Tests（基本）

    @Test func isWithinRange_sameLocation_returnsTrue() {
        let aquarium = makeAquarium()
        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == true)
    }

    @Test func isWithinRange_withinDefaultRadius_returnsTrue() {
        let aquarium = makeAquarium()
        // 約500m北（緯度で約0.0045度）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6857, longitude: 139.7671)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == true)
    }

    @Test func isWithinRange_outsideDefaultRadius_returnsFalse() {
        let aquarium = makeAquarium()
        // 約2km北（緯度で約0.018度）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6992, longitude: 139.7671)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == false)
    }

    // MARK: - isWithinRange Tests（カスタム半径）

    @Test func isWithinRange_customRadius500m_withinRange_returnsTrue() {
        let aquarium = makeAquarium()
        // 約400m離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.6848, longitude: 139.7671)

        let result = PhotoMetadataExtractor.isWithinRange(
            coordinate: coordinate,
            of: aquarium,
            radius: 500
        )

        #expect(result == true)
    }

    @Test func isWithinRange_customRadius500m_outsideRange_returnsFalse() {
        let aquarium = makeAquarium()
        // 約800m離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.6884, longitude: 139.7671)

        let result = PhotoMetadataExtractor.isWithinRange(
            coordinate: coordinate,
            of: aquarium,
            radius: 500
        )

        #expect(result == false)
    }

    @Test func isWithinRange_customRadius2km_withinRange_returnsTrue() {
        let aquarium = makeAquarium()
        // 約1.5km離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.6947, longitude: 139.7671)

        let result = PhotoMetadataExtractor.isWithinRange(
            coordinate: coordinate,
            of: aquarium,
            radius: 2000
        )

        #expect(result == true)
    }

    // MARK: - isWithinRange Tests（境界値）

    @Test func isWithinRange_exactlyAtBoundary_returnsTrue() {
        let aquarium = makeAquarium()
        // ちょうど1000m（境界上）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6902, longitude: 139.7671)
        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 境界値（1000m以内）であれば有効
        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(distance <= 1000)
        #expect(result == true)
    }

    @Test func isWithinRange_slightlyOverBoundary_returnsFalse() {
        let aquarium = makeAquarium()
        // 約1.1km離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.6912, longitude: 139.7671)
        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(distance > 1000)
        #expect(result == false)
    }

    // MARK: - isWithinRange Tests（日本各地の水族館）

    @Test func isWithinRange_okinawaChuraumi_withinRange() {
        // 美ら海水族館（沖縄）
        let aquarium = makeAquarium(
            name: "沖縄美ら海水族館",
            latitude: 26.6942,
            longitude: 127.8779
        )
        // 近くの座標
        let coordinate = CLLocationCoordinate2D(latitude: 26.6950, longitude: 127.8785)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == true)
    }

    @Test func isWithinRange_hokkaidoOtaru_withinRange() {
        // 小樽水族館（北海道）
        let aquarium = makeAquarium(
            name: "おたる水族館",
            latitude: 43.2314,
            longitude: 140.9747
        )
        // 近くの座標
        let coordinate = CLLocationCoordinate2D(latitude: 43.2320, longitude: 140.9750)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == true)
    }

    // MARK: - distance Tests（基本）

    @Test func distance_sameLocation_returnsZero() {
        let aquarium = makeAquarium()
        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        #expect(distance < 1) // 1メートル未満
    }

    @Test func distance_latitudeOnly_returnsCorrectDistance() {
        let aquarium = makeAquarium()
        // 緯度のみ変化（約1km北）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6902, longitude: 139.7671)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 約1km（±100m）
        #expect(distance > 900 && distance < 1100)
    }

    @Test func distance_longitudeOnly_returnsCorrectDistance() {
        let aquarium = makeAquarium()
        // 経度のみ変化（約1km東）- 緯度35度付近では経度0.011度が約1km
        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7781)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 約1km（±100m）
        #expect(distance > 900 && distance < 1100)
    }

    @Test func distance_diagonal_returnsCorrectDistance() {
        let aquarium = makeAquarium()
        // 斜め方向（北東へ約1.4km = √2 km）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6902, longitude: 139.7781)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 約1.4km（±200m）
        #expect(distance > 1200 && distance < 1600)
    }

    @Test func distance_largeDistance_returnsCorrectDistance() {
        // 東京の水族館
        let aquarium = makeAquarium(latitude: 35.6812, longitude: 139.7671)
        // 大阪（約400km）
        let coordinate = CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 約400km（±50km）
        #expect(distance > 350_000 && distance < 450_000)
    }

    // MARK: - extractMetadata Tests

    @Test func extractMetadata_emptyData_returnsNilValues() {
        let emptyData = Data()

        let metadata = PhotoMetadataExtractor.extractMetadata(from: emptyData)

        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
        #expect(metadata.hasLocation == false)
    }

    @Test func extractMetadata_invalidTextData_returnsNilValues() {
        let invalidData = "not an image".data(using: .utf8)!

        let metadata = PhotoMetadataExtractor.extractMetadata(from: invalidData)

        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
        #expect(metadata.hasLocation == false)
    }

    @Test func extractMetadata_randomBinaryData_returnsNilValues() {
        var randomBytes = [UInt8](repeating: 0, count: 1024)
        for i in 0..<randomBytes.count {
            randomBytes[i] = UInt8.random(in: 0...255)
        }
        let randomData = Data(randomBytes)

        let metadata = PhotoMetadataExtractor.extractMetadata(from: randomData)

        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
    }

    @Test func extractMetadata_minimalJpegWithoutExif_returnsNilValues() {
        // 最小限のJPEGヘッダー（EXIFなし）
        let jpegHeader: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]
        let jpegData = Data(jpegHeader)

        let metadata = PhotoMetadataExtractor.extractMetadata(from: jpegData)

        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
    }

    // MARK: - PhotoMetadata Tests

    @Test func photoMetadata_withValidCoordinate_hasLocationIsTrue() {
        let metadata = PhotoMetadata(
            coordinate: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
            dateTaken: nil
        )

        #expect(metadata.hasLocation == true)
    }

    @Test func photoMetadata_withNilCoordinate_hasLocationIsFalse() {
        let metadata = PhotoMetadata(
            coordinate: nil,
            dateTaken: Date()
        )

        #expect(metadata.hasLocation == false)
    }

    @Test func photoMetadata_withBothValues_hasCorrectProperties() {
        let testDate = Date()
        let testCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        let metadata = PhotoMetadata(
            coordinate: testCoordinate,
            dateTaken: testDate
        )

        #expect(metadata.hasLocation == true)
        #expect(metadata.coordinate?.latitude == 35.6812)
        #expect(metadata.coordinate?.longitude == 139.7671)
        #expect(metadata.dateTaken == testDate)
    }

    @Test func photoMetadata_withNilValues_hasCorrectProperties() {
        let metadata = PhotoMetadata(
            coordinate: nil,
            dateTaken: nil
        )

        #expect(metadata.hasLocation == false)
        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
    }

    // MARK: - 座標の境界値テスト

    @Test func isWithinRange_extremeLatitude_north_works() {
        // 北海道北端付近
        let aquarium = makeAquarium(latitude: 45.5, longitude: 141.9)
        let coordinate = CLLocationCoordinate2D(latitude: 45.5, longitude: 141.9)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == true)
    }

    @Test func isWithinRange_extremeLatitude_south_works() {
        // 沖縄南端付近
        let aquarium = makeAquarium(latitude: 24.0, longitude: 123.8)
        let coordinate = CLLocationCoordinate2D(latitude: 24.0, longitude: 123.8)

        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)

        #expect(result == true)
    }

    // MARK: - 距離計算の精度テスト

    @Test func distance_verySmallDistance_isAccurate() {
        let aquarium = makeAquarium()
        // 約100m離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.6821, longitude: 139.7671)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 100m ± 20m
        #expect(distance > 80 && distance < 120)
    }

    @Test func distance_mediumDistance_isAccurate() {
        let aquarium = makeAquarium()
        // 約5km離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.7262, longitude: 139.7671)

        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 5km ± 500m
        #expect(distance > 4500 && distance < 5500)
    }
}
