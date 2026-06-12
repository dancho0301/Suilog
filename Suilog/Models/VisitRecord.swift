//
//  VisitRecord.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData
import SwiftUI

typealias CheckInType = AquariumSchemaV9.CheckInTypeV9

extension AquariumSchemaV9.CheckInTypeV9 {
    var color: Color {
        switch self {
        case .location:
            return .yellow // ゴールド
        case .manual:
            return .gray   // シルバー
        }
    }

    var displayName: String {
        switch self {
        case .location:
            return "位置情報チェックイン"
        case .manual:
            return "手動チェックイン"
        }
    }
}

typealias VisitRecord = AquariumSchemaV9.VisitRecord

extension VisitRecord {
    /// 無料版で1記録に保存できる写真の上限枚数（スイログ Proは無制限）
    static let freePhotoLimit = 1

    /// すべての写真（1枚目: photoData、2枚目以降: additionalPhotosData）
    var allPhotosData: [Data] {
        var photos: [Data] = []
        if let photoData {
            photos.append(photoData)
        }
        photos.append(contentsOf: additionalPhotosData ?? [])
        return photos
    }

    /// 写真一覧をまとめて設定する（1枚目をphotoDataに、残りをadditionalPhotosDataに振り分け）
    func setPhotos(_ photos: [Data]) {
        photoData = photos.first
        additionalPhotosData = photos.count > 1 ? Array(photos.dropFirst()) : nil
    }
}
