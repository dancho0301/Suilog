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
}
