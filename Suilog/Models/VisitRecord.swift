//
//  VisitRecord.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData
import SwiftUI

typealias CheckInType = AquariumSchemaV5.CheckInTypeV5

extension AquariumSchemaV5.CheckInTypeV5 {
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

typealias VisitRecord = AquariumSchemaV5.VisitRecord
