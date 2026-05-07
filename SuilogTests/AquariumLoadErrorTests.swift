//
//  AquariumLoadErrorTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/02/12.
//

import Testing
import Foundation
@testable import Suilog

/// AquariumLoadErrorのテスト
@Suite
struct AquariumLoadErrorTests {

    // MARK: - Error Message Tests

    @Test("invalidURL のエラーメッセージ")
    func testInvalidURLMessage() {
        let error = AquariumLoadError.invalidURL
        #expect(error.localizedMessage == "データの取得先URLが無効です")
    }

    @Test("networkError のエラーメッセージ")
    func testNetworkErrorMessage() {
        let underlyingError = NSError(domain: "test", code: -1009, userInfo: nil)
        let error = AquariumLoadError.networkError(underlyingError)
        #expect(error.localizedMessage == "ネットワークに接続できません。インターネット接続を確認してください")
    }

    @Test("httpError のエラーメッセージにステータスコードが含まれる")
    func testHttpErrorMessage() {
        let error404 = AquariumLoadError.httpError(404)
        #expect(error404.localizedMessage == "サーバーエラーが発生しました（コード: 404）")

        let error500 = AquariumLoadError.httpError(500)
        #expect(error500.localizedMessage == "サーバーエラーが発生しました（コード: 500）")
    }

    @Test("decodingError のエラーメッセージ")
    func testDecodingErrorMessage() {
        let json = "invalid".data(using: .utf8)!
        do {
            _ = try JSONDecoder().decode(AquariumResponse.self, from: json)
        } catch {
            let loadError = AquariumLoadError.decodingError(error)
            #expect(loadError.localizedMessage == "データの読み込みに失敗しました")
        }
    }

    // MARK: - StoreError Tests

    @Test("StoreError.verificationFailed のエラーメッセージ")
    func testStoreErrorVerificationFailed() {
        let error = StoreError.verificationFailed
        #expect(error.errorDescription == "購入の検証に失敗しました")
    }

    // MARK: - SeedResult Tests

    @Test("SeedResult の各ケースが存在する")
    func testSeedResultCases() {
        let success = SeedResult.success
        let skipped = SeedResult.skippedOffline
        let errorNoData = SeedResult.errorNoData("テストエラー")
        let errorSave = SeedResult.errorSaveFailed("保存エラー")

        // パターンマッチングで各ケースを確認
        if case .success = success {} else {
            Issue.record("success case failed")
        }
        if case .skippedOffline = skipped {} else {
            Issue.record("skippedOffline case failed")
        }
        if case .errorNoData(let msg) = errorNoData {
            #expect(msg == "テストエラー")
        } else {
            Issue.record("errorNoData case failed")
        }
        if case .errorSaveFailed(let msg) = errorSave {
            #expect(msg == "保存エラー")
        } else {
            Issue.record("errorSaveFailed case failed")
        }
    }
}
