//
//  Aquarium.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData

typealias Aquarium = AquariumSchemaV7.Aquarium

extension Aquarium {
    /// 訪問記録の安全なアクセサ（CloudKit互換のためvisitsがオプショナル）
    var safeVisits: [VisitRecord] {
        visits ?? []
    }

    var hasVisited: Bool {
        !safeVisits.isEmpty
    }

    var visitCount: Int {
        safeVisits.count
    }

    var lastVisitDate: Date? {
        safeVisits.max(by: { $0.visitDate < $1.visitDate })?.visitDate
    }
}
