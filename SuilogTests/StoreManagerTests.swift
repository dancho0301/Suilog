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

    // MARK: - RestoreOutcome

    @Test("復元: Pro が見つかれば restored")
    func testRestoreOutcomeRestored() {
        let outcome = RestoreOutcome.resolve(isProUnlocked: true, failed: false)
        #expect(outcome == .restored)
        #expect(outcome.message == "Pro を復元しました")
    }

    @Test("復元: 通信は成功したが Pro がなければ nothingToRestore")
    func testRestoreOutcomeNothingToRestore() {
        let outcome = RestoreOutcome.resolve(isProUnlocked: false, failed: false)
        #expect(outcome == .nothingToRestore)
        #expect(outcome.message == "復元できる購入が見つかりませんでした")
    }

    @Test("復元: 失敗したら failed（メッセージは errorMessage 側で出すので nil）")
    func testRestoreOutcomeFailed() {
        // 失敗時は、たまたま Pro を持っていても failed を優先する
        let outcome = RestoreOutcome.resolve(isProUnlocked: true, failed: true)
        #expect(outcome == .failed)
        #expect(outcome.message == nil)
    }
}
