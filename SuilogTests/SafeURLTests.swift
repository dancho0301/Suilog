//
//  SafeURLTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/11.
//

import Testing
import Foundation
@testable import Suilog

/// SafeURL（外部データ由来URLの検証）のテスト
@Suite
struct SafeURLTests {

    // MARK: - webURL: 許可されるスキーム

    @Test("httpsのURLは許可される")
    func testHttpsAllowed() {
        let url = SafeURL.webURL(from: "https://www.enosui.com/")
        #expect(url?.absoluteString == "https://www.enosui.com/")
    }

    @Test("httpのURLは許可される")
    func testHttpAllowed() {
        let url = SafeURL.webURL(from: "http://example.com")
        #expect(url != nil)
    }

    @Test("大文字スキーム（HTTPS）も許可される")
    func testUppercaseSchemeAllowed() {
        let url = SafeURL.webURL(from: "HTTPS://example.com")
        #expect(url != nil)
    }

    // MARK: - webURL: 拒否されるスキーム

    @Test("危険・無関係なスキームは拒否される", arguments: [
        "javascript://alert(1)",
        "file:///etc/passwd",
        "tel://0312345678",
        "sms://0312345678",
        "data:text/html,<script>alert(1)</script>",
        "myapp://open",
        "ftp://example.com"
    ])
    func testDangerousSchemesRejected(urlString: String) {
        #expect(SafeURL.webURL(from: urlString) == nil)
    }

    @Test("nil・空文字・スキームなしは拒否される")
    func testInvalidInputsRejected() {
        #expect(SafeURL.webURL(from: nil) == nil)
        #expect(SafeURL.webURL(from: "") == nil)
        #expect(SafeURL.webURL(from: "www.example.com") == nil) // スキームなし
        #expect(SafeURL.webURL(from: "そもそもURLではない 文字列") == nil)
    }

    // MARK: - telURL

    @Test("ハイフン付き電話番号からtel URLを生成")
    func testTelURLWithHyphens() {
        let url = SafeURL.telURL(from: "03-1234-5678")
        #expect(url?.absoluteString == "tel://0312345678")
    }

    @Test("国際表記（+81）の電話番号からtel URLを生成")
    func testTelURLInternational() {
        let url = SafeURL.telURL(from: "+81 3-1234-5678")
        #expect(url?.absoluteString == "tel://+81312345678")
    }

    @Test("数字を含まない文字列はnil")
    func testTelURLNoDigits() {
        #expect(SafeURL.telURL(from: "電話番号なし") == nil)
        #expect(SafeURL.telURL(from: "") == nil)
        #expect(SafeURL.telURL(from: nil) == nil)
    }
}
