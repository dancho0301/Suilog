//
//  AquariumData.swift
//  Suilog
//
//  Created by dancho on 2026/01/02.
//

import Foundation

struct AquariumData: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let description: String
    let region: String
    let representativeFish: String
    let fishIconSize: Int
}
