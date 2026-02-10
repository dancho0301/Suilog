//
//  PhotoMetadataExtractor.swift
//  Suilog
//
//  Created by Claude on 2026/01/16.
//

import Foundation
import CoreLocation
import ImageIO
import UIKit

/// 写真のメタデータ情報
struct PhotoMetadata {
    /// 撮影位置の座標
    let coordinate: CLLocationCoordinate2D?
    /// 撮影日時
    let dateTaken: Date?

    /// 位置情報が含まれているかどうか
    var hasLocation: Bool {
        coordinate != nil
    }
}

/// 写真からEXIFメタデータを抽出するユーティリティ
enum PhotoMetadataExtractor {

    /// 画像データからメタデータを抽出
    /// - Parameter data: 画像データ
    /// - Returns: 抽出されたメタデータ（抽出できない場合は座標・日時ともにnil）
    static func extractMetadata(from data: Data) -> PhotoMetadata {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return PhotoMetadata(coordinate: nil, dateTaken: nil)
        }

        let coordinate = extractCoordinate(from: properties)
        let dateTaken = extractDateTaken(from: properties)

        return PhotoMetadata(coordinate: coordinate, dateTaken: dateTaken)
    }

    /// GPS情報から座標を抽出
    private static func extractCoordinate(from properties: [String: Any]) -> CLLocationCoordinate2D? {
        guard let gpsInfo = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }

        guard let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
              let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
              let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }

        // 南緯・西経の場合は負の値に変換
        let lat = latitudeRef == "S" ? -latitude : latitude
        let lon = longitudeRef == "W" ? -longitude : longitude

        // 有効な座標範囲かチェック
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// EXIF情報から撮影日時を抽出
    private static func extractDateTaken(from properties: [String: Any]) -> Date? {
        // EXIFの撮影日時を優先
        if let exifInfo = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exifInfo[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            return parseExifDate(dateString)
        }

        // TIFFの日時をフォールバック
        if let tiffInfo = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateString = tiffInfo[kCGImagePropertyTIFFDateTime as String] as? String {
            return parseExifDate(dateString)
        }

        // GPS日時をフォールバック
        if let gpsInfo = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let dateStamp = gpsInfo[kCGImagePropertyGPSDateStamp as String] as? String,
           let timeStamp = gpsInfo[kCGImagePropertyGPSTimeStamp as String] as? String {
            return parseGpsDateTime(dateStamp: dateStamp, timeStamp: timeStamp)
        }

        return nil
    }

    /// EXIF形式の日時文字列をパース（例: "2024:01:15 14:30:00"）
    private static func parseExifDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    /// GPS日時をパース
    private static func parseGpsDateTime(dateStamp: String, timeStamp: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: "\(dateStamp) \(timeStamp)")
    }

    /// 指定した座標が水族館の範囲内（1km以内）かを判定
    /// - Parameters:
    ///   - coordinate: チェックする座標
    ///   - aquarium: 対象の水族館
    ///   - radius: 許容範囲（メートル）デフォルトは1000m
    /// - Returns: 範囲内ならtrue
    static func isWithinRange(
        coordinate: CLLocationCoordinate2D,
        of aquarium: Aquarium,
        radius: CLLocationDistance = 1000
    ) -> Bool {
        #if DEBUG
        let debug = DebugSettings.shared
        if debug.isAlwaysAllowCheckInActive {
            return true
        }
        #endif
        let photoLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let aquariumLocation = CLLocation(latitude: aquarium.latitude, longitude: aquarium.longitude)
        let distance = photoLocation.distance(from: aquariumLocation)
        #if DEBUG
        if debug.isCustomRadiusActive {
            return distance <= debug.effectiveRadius
        }
        #endif
        return distance <= radius
    }

    /// 座標から水族館までの距離を計算
    /// - Parameters:
    ///   - coordinate: 写真の座標
    ///   - aquarium: 対象の水族館
    /// - Returns: 距離（メートル）
    static func distance(
        from coordinate: CLLocationCoordinate2D,
        to aquarium: Aquarium
    ) -> CLLocationDistance {
        let photoLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let aquariumLocation = CLLocation(latitude: aquarium.latitude, longitude: aquarium.longitude)
        return photoLocation.distance(from: aquariumLocation)
    }
}
