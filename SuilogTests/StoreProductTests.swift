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

    @Test("全Product IDはProとチップだけで、テーマ商品は含まれない")
    @MainActor
    func testAllProductIds() {
        let all = StoreManager.allProductIds
        #expect(all.count == 4) // Pro1 + チップ3
        #expect(all.isSuperset(of: StoreManager.tipProductIds))
        #expect(all.contains(StoreManager.proProductId))
        #expect(!all.contains("com.suilog.theme.yumekawa"))
        #expect(!all.contains("com.suilog.theme.all_pack"))
    }
}
