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

    // MARK: - isWithinRange Tests

    @Test func isWithinRange_withinRadius_returnsTrue() {
        // 水族館の座標
        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト",
            region: "東京"
        )

        // 水族館からほぼ同じ位置（数メートル）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)
        #expect(result == true)
    }

    @Test func isWithinRange_outsideRadius_returnsFalse() {
        // 水族館の座標
        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト",
            region: "東京"
        )

        // 水族館から約10km離れた位置
        let coordinate = CLLocationCoordinate2D(latitude: 35.7812, longitude: 139.7671)
        let result = PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)
        #expect(result == false)
    }

    @Test func isWithinRange_exactlyAtRadius_returnsTrue() {
        // 水族館の座標
        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト",
            region: "東京"
        )

        // 約1km離れた位置（緯度で約0.009度が1km）
        let coordinate = CLLocationCoordinate2D(latitude: 35.6902, longitude: 139.7671)
        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 1km以内であれば有効
        #expect(distance <= 1000)
    }

    // MARK: - distance Tests

    @Test func distance_sameLocation_returnsZero() {
        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト",
            region: "東京"
        )

        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)
        #expect(distance < 1) // 1メートル未満
    }

    @Test func distance_differentLocations_returnsCorrectDistance() {
        let aquarium = Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト",
            region: "東京"
        )

        // 約1km北
        let coordinate = CLLocationCoordinate2D(latitude: 35.6902, longitude: 139.7671)
        let distance = PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)

        // 約1km（900m〜1100mの範囲）
        #expect(distance > 900 && distance < 1100)
    }

    // MARK: - extractMetadata Tests

    @Test func extractMetadata_emptyData_returnsNilValues() {
        let emptyData = Data()
        let metadata = PhotoMetadataExtractor.extractMetadata(from: emptyData)

        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
        #expect(metadata.hasLocation == false)
    }

    @Test func extractMetadata_invalidData_returnsNilValues() {
        let invalidData = "not an image".data(using: .utf8)!
        let metadata = PhotoMetadataExtractor.extractMetadata(from: invalidData)

        #expect(metadata.coordinate == nil)
        #expect(metadata.dateTaken == nil)
        #expect(metadata.hasLocation == false)
    }

    // MARK: - PhotoMetadata Tests

    @Test func photoMetadata_withCoordinate_hasLocationIsTrue() {
        let metadata = PhotoMetadata(
            coordinate: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
            dateTaken: nil
        )
        #expect(metadata.hasLocation == true)
    }

    @Test func photoMetadata_withoutCoordinate_hasLocationIsFalse() {
        let metadata = PhotoMetadata(
            coordinate: nil,
            dateTaken: Date()
        )
        #expect(metadata.hasLocation == false)
    }
}
