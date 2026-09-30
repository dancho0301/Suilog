//
//  StoreManagerTests.swift
//  SuilogTests
//
//  StoreManagerの購入判定ロジック（純粋関数部分）のテスト。
//  StoreKit本体を使う購入のテストは ProPurchaseTests にある。
//

import Testing
import Foundation
@testable import Suilog

@Suite
struct StoreManagerTests {

    // MARK: - isPro(in:)

    @Test("Pro を所有していれば Pro 扱い")
    @MainActor
    func testOwnedPro() {
        #expect(StoreManager.isPro(in: ["com.suilog.pro"]) == true)
    }

    @Test("空の所有セットでは Pro ではない")
    @MainActor
    func testEmptyOwnership() {
        #expect(StoreManager.isPro(in: []) == false)
    }

    @Test("チップだけでは Pro ではない")
    @MainActor
    func testTipsAreNotPro() {
        #expect(StoreManager.isPro(in: StoreManager.tipProductIds) == false)
    }

    @Test("販売をやめたテーマ商品を持っていても Pro 扱いにならない")
    @MainActor
    func testRetiredThemeProductsAreNotPro() {
        let retired: Set<String> = ["com.suilog.theme.yumekawa", "com.suilog.theme.all_pack"]
        #expect(StoreManager.isPro(in: retired) == false)
    }
}
