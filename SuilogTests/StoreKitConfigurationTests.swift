//
//  StoreKitConfigurationTests.swift
//  SuilogTests
//
//  Configuration.storekit の中身が販売方針(Pro + チップ3つ)と合っているかを確かめる。
//

import Testing
import Foundation
@testable import Suilog

struct StoreKitConfigurationTests {

    private struct Config: Decodable {
        struct Localization: Decodable {
            let locale: String
            let description: String
        }
        struct Product: Decodable {
            let productID: String
            let type: String
            let displayPrice: String
            let localizations: [Localization]
        }
        let products: [Product]
    }

    private func loadConfig() throws -> Config {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SuilogTests
            .deletingLastPathComponent()   // リポジトリ直下
            .appendingPathComponent("Suilog/Configuration.storekit")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    @Test("販売する商品は Pro とチップ3つだけ(テーマ商品はない)")
    @MainActor
    func onlyProAndTipsAreListed() throws {
        let config = try loadConfig()
        #expect(Set(config.products.map(\.productID)) == StoreManager.allProductIds)
        #expect(config.products.count == 4)
    }

    @Test("Pro は買い切りの600円")
    @MainActor
    func proIsNonConsumableAt600() throws {
        let config = try loadConfig()
        let pro = try #require(config.products.first { $0.productID == StoreManager.proProductId })
        #expect(pro.type == "NonConsumable")
        #expect(pro.displayPrice == "600")
    }

    @Test("チップは消耗型")
    func tipsAreConsumable() throws {
        let config = try loadConfig()
        let tips = config.products.filter { $0.productID.hasPrefix("com.suilog.tip.") }
        #expect(tips.count == 3)
        #expect(tips.allSatisfy { $0.type == "Consumable" })
    }

    @Test("Pro の日本語説明は実際の特典(写真・テーマ・ウィジェット)に触れている")
    @MainActor
    func proDescriptionMentionsBenefits() throws {
        let config = try loadConfig()
        let pro = try #require(config.products.first { $0.productID == StoreManager.proProductId })
        let ja = try #require(pro.localizations.first { $0.locale == "ja" })
        #expect(ja.description.contains("写真"))
        #expect(ja.description.contains("テーマ"))
        #expect(ja.description.contains("ウィジェット"))
    }
}
