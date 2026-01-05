//
//  Aquarium.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import Foundation
import SwiftData

typealias Aquarium = AquariumSchemaV3.Aquarium

extension Aquarium {
    var hasVisited: Bool {
        !visits.isEmpty
    }

    var visitCount: Int {
        visits.count
    }

    var lastVisitDate: Date? {
        visits.sorted(by: { $0.visitDate > $1.visitDate }).first?.visitDate
    }

    /// representativeFishをSFSymbolsアイコン名にマッピング
    var sfSymbolName: String {
        switch representativeFish.lowercased() {
        case "seal": return "seal.fill"
        case "penguin": return "ellipsis.circle.fill"  // ペンギンに近いアイコン
        case "sealion": return "seal.fill"
        case "dolphin": return "fish.fill"
        case "salmon": return "fish.fill"
        case "sturgeon": return "fish.fill"
        case "hucho": return "fish.fill"
        default: return representativeFish  // デフォルトは元の値をそのまま使用
        }
    }
}
