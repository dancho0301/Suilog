//
//  BadgeTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/11.
//

import Testing
import Foundation
@testable import Suilog

/// バッジ（実績）ロジックのテスト
@Suite
struct BadgeTests {

    /// 指定した値でバッジ一覧を生成するヘルパー（デフォルトはすべて0）
    private func makeBadges(
        visitedCount: Int = 0,
        goldCount: Int = 0,
        silverCount: Int = 0,
        visitedRegions: Int = 0,
        maxVisitsToOneAquarium: Int = 0,
        photoRecordCount: Int = 0,
        visitedThisYear: Int = 0
    ) -> [Badge] {
        Badge.allBadges(
            visitedCount: visitedCount,
            goldCount: goldCount,
            silverCount: silverCount,
            visitedRegions: visitedRegions,
            maxVisitsToOneAquarium: maxVisitsToOneAquarium,
            photoRecordCount: photoRecordCount,
            visitedThisYear: visitedThisYear
        )
    }

    private func badge(_ id: String, in badges: [Badge]) -> Badge? {
        badges.first { $0.id == id }
    }

    // MARK: - 全体構成

    @Test("バッジは12種類定義されている")
    func testBadgeCount() {
        #expect(makeBadges().count == 12)
    }

    @Test("バッジIDに重複がない")
    func testBadgeIdsUnique() {
        let ids = makeBadges().map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("初期状態（すべて0）では獲得バッジがない")
    func testNoBadgesEarnedInitially() {
        let badges = makeBadges()
        #expect(badges.allSatisfy { !$0.isEarned })
    }

    // MARK: - 訪問数系バッジ

    @Test("はじめの一歩: 1館訪問で獲得")
    func testFirstStep() {
        #expect(badge("first_step", in: makeBadges(visitedCount: 1))?.isEarned == true)
        #expect(badge("first_step", in: makeBadges(visitedCount: 0))?.isEarned == false)
    }

    @Test("訪問数バッジの獲得しきい値", arguments: [
        ("five_tanks", 5),
        ("ten_tanks", 10),
        ("twentyfive_tanks", 25),
        ("fifty_tanks", 50),
        ("hundred_tanks", 100)
    ])
    func testVisitCountThresholds(id: String, threshold: Int) {
        // しきい値ちょうどで獲得
        #expect(badge(id, in: makeBadges(visitedCount: threshold))?.isEarned == true)
        // 1つ手前では未獲得
        #expect(badge(id, in: makeBadges(visitedCount: threshold - 1))?.isEarned == false)
    }

    @Test("進捗が上限（1.0）を超えない")
    func testProgressCapped() {
        let badges = makeBadges(visitedCount: 200, goldCount: 100, silverCount: 100)
        #expect(badges.allSatisfy { $0.progress <= 1.0 })
    }

    @Test("進捗テキストが分子をしきい値で頭打ちにする")
    func testProgressTextCapped() {
        let badges = makeBadges(visitedCount: 7)
        #expect(badge("five_tanks", in: badges)?.progressText == "5 / 5")
        #expect(badge("ten_tanks", in: badges)?.progressText == "7 / 10")
    }

    // MARK: - チェックイン種別バッジ

    @Test("ゴールド10: 位置情報チェックイン10回で獲得")
    func testGoldTen() {
        #expect(badge("gold_ten", in: makeBadges(goldCount: 10))?.isEarned == true)
        #expect(badge("gold_ten", in: makeBadges(goldCount: 9))?.isEarned == false)
    }

    @Test("シルバー10: 手動チェックイン10回で獲得")
    func testSilverTen() {
        #expect(badge("silver_ten", in: makeBadges(silverCount: 10))?.isEarned == true)
        #expect(badge("silver_ten", in: makeBadges(silverCount: 9))?.isEarned == false)
    }

    // MARK: - その他のバッジ

    @Test("地域マスター: 全7地域で獲得")
    func testRegionMaster() {
        #expect(badge("region_master", in: makeBadges(visitedRegions: 7))?.isEarned == true)
        #expect(badge("region_master", in: makeBadges(visitedRegions: 6))?.isEarned == false)
    }

    @Test("常連さん: 同じ水族館に5回訪問で獲得")
    func testRepeater() {
        #expect(badge("repeater", in: makeBadges(maxVisitsToOneAquarium: 5))?.isEarned == true)
        #expect(badge("repeater", in: makeBadges(maxVisitsToOneAquarium: 4))?.isEarned == false)
    }

    @Test("フォトグラファー: 写真付き記録10件で獲得")
    func testPhotographer() {
        #expect(badge("photographer", in: makeBadges(photoRecordCount: 10))?.isEarned == true)
        #expect(badge("photographer", in: makeBadges(photoRecordCount: 9))?.isEarned == false)
    }

    @Test("年間パスポート: 1年で10館訪問で獲得")
    func testAnnualPass() {
        #expect(badge("annual_pass", in: makeBadges(visitedThisYear: 10))?.isEarned == true)
        #expect(badge("annual_pass", in: makeBadges(visitedThisYear: 9))?.isEarned == false)
    }

    // MARK: - isEarned 境界

    @Test("isEarned は progress 1.0 以上で true")
    func testIsEarnedBoundary() {
        let earned = Badge(id: "t", icon: "🎯", title: "t", description: "t", progress: 1.0, progressText: "1 / 1")
        let notEarned = Badge(id: "t", icon: "🎯", title: "t", description: "t", progress: 0.99, progressText: "0 / 1")
        #expect(earned.isEarned)
        #expect(!notEarned.isEarned)
    }
}
