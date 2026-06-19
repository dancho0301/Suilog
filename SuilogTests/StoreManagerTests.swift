//
//  StoreManagerTests.swift
//  SuilogTests
//
//  StoreManagerの購入判定ロジック（純粋関数部分）のテスト。
//  StoreKit本体はテストセッションが必要なため、ここでは
//  エンタイトルメント判定のロジックのみを検証する。
//

import Testing
import Foundation
@testable import Suilog

@Suite
struct StoreManagerTests {

    // MARK: - resolveIsPurchased

    @Test("個別商品を所有していれば購入済み")
    @MainActor
    func testOwnedDirectly() {
        let owned: Set<String> = ["com.suilog.theme.yumekawa"]
        #expect(StoreManager.resolveIsPurchased("com.suilog.theme.yumekawa", in: owned) == true)
    }

    @Test("未所有の商品は未購入")
    @MainActor
    func testNotOwned() {
        let owned: Set<String> = ["com.suilog.theme.yumekawa"]
        #expect(StoreManager.resolveIsPurchased("com.suilog.theme.other", in: owned) == false)
    }

    @Test("全テーマパック所有時は個別テーマも購入済み扱い")
    @MainActor
    func testAllPackUnlocksIndividualThemes() {
        let owned: Set<String> = ["com.suilog.theme.all_pack"]
        #expect(StoreManager.resolveIsPurchased("com.suilog.theme.yumekawa", in: owned) == true)
        #expect(StoreManager.resolveIsPurchased("com.suilog.theme.any_future", in: owned) == true)
    }

    @Test("全テーマパックでもパック自身は購入済み判定")
    @MainActor
    func testAllPackItself() {
        let owned: Set<String> = ["com.suilog.theme.all_pack"]
        #expect(StoreManager.resolveIsPurchased(StoreManager.allThemesPackId, in: owned) == true)
    }

    @Test("空の所有セットでは何も購入済みでない")
    @MainActor
    func testEmptyOwnership() {
        let owned: Set<String> = []
        #expect(StoreManager.resolveIsPurchased("com.suilog.pro", in: owned) == false)
        #expect(StoreManager.resolveIsPurchased("com.suilog.theme.all_pack", in: owned) == false)
    }

    @Test("全テーマパックのIDが正しい")
    @MainActor
    func testAllThemesPackId() {
        #expect(StoreManager.allThemesPackId == "com.suilog.theme.all_pack")
    }
}
