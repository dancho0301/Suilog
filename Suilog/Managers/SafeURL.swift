//
//  SafeURL.swift
//  Suilog
//
//  外部データ由来のURL文字列を安全に扱うためのユーティリティ。
//

import Foundation

enum SafeURL {
    /// 外部データ由来のURL文字列を検証し、http/https のみ許可する
    static func webURL(from string: String?) -> URL? {
        guard let string, !string.isEmpty,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    /// 電話番号から tel: URLを生成する（数字と+のみ抽出）
    static func telURL(from phoneNumber: String?) -> URL? {
        guard let phoneNumber else { return nil }
        let digits = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}
