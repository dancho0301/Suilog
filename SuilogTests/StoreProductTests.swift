//
//  StoreProductTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/12.
//

import Testing
import Foundation
@testable import Suilog

/// 課金商品ID定義のテスト
@Suite
struct StoreProductTests {

    @Test("Pro のProduct IDが正しい")
    @MainActor
    func testProProductId() {
        #expect(StoreManager.proProductId == "com.suilog.pro")
    }

    @Test("チップ商品が3種類定義されている")
    @MainActor
    func testTipProductIds() {
        #expect(StoreManager.tipProductIds.count == 3)
        #expect(StoreManager.tipProductIds.allSatisfy { $0.hasPrefix("com.suilog.tip.") })
    }

    @Test("テーマ商品IDが従来どおり（回帰防止）")
    @MainActor
    func testThemeProductIdsUnchanged() {
        #expect(StoreManager.themeProductIds == [
            "com.suilog.theme.yumekawa",
            "com.suilog.theme.all_pack"
        ])
    }

    @Test("全Product IDにテーマ・Pro・チップがすべて含まれ重複しない")
    @MainActor
    func testAllProductIds() {
        let all = StoreManager.allProductIds
        #expect(all.count == 6) // テーマ2 + Pro1 + チップ3
        #expect(all.isSuperset(of: StoreManager.themeProductIds))
        #expect(all.isSuperset(of: StoreManager.tipProductIds))
        #expect(all.contains(StoreManager.proProductId))
    }
}
