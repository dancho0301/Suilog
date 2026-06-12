//
//  ReviewRequestHelperTests.swift
//  SuilogTests
//
//  Created by Claude on 2026/06/12.
//

import Testing
import Foundation
@testable import Suilog

/// レビュー依頼タイミング判定のテスト
@Suite
struct ReviewRequestHelperTests {

    @Test("節目の訪問数（3・10・25・50）で依頼する", arguments: [3, 10, 25, 50])
    func testRequestsAtMilestones(count: Int) {
        #expect(ReviewRequestHelper.shouldRequestReview(visitCount: count, lastRequestedMilestone: 0))
    }

    @Test("節目以外の訪問数では依頼しない", arguments: [0, 1, 2, 4, 9, 11, 24, 26, 49, 51, 100])
    func testDoesNotRequestOffMilestones(count: Int) {
        #expect(!ReviewRequestHelper.shouldRequestReview(visitCount: count, lastRequestedMilestone: 0))
    }

    @Test("同じ節目では二度依頼しない")
    func testDoesNotRequestSameMilestoneTwice() {
        #expect(!ReviewRequestHelper.shouldRequestReview(visitCount: 3, lastRequestedMilestone: 3))
        #expect(!ReviewRequestHelper.shouldRequestReview(visitCount: 10, lastRequestedMilestone: 10))
    }

    @Test("次の節目に達したら再び依頼する")
    func testRequestsAtNextMilestone() {
        #expect(ReviewRequestHelper.shouldRequestReview(visitCount: 10, lastRequestedMilestone: 3))
        #expect(ReviewRequestHelper.shouldRequestReview(visitCount: 25, lastRequestedMilestone: 10))
        #expect(ReviewRequestHelper.shouldRequestReview(visitCount: 50, lastRequestedMilestone: 25))
    }

    @Test("過去の節目より少ない訪問数では依頼しない（記録削除後など）")
    func testDoesNotRequestBelowLastMilestone() {
        #expect(!ReviewRequestHelper.shouldRequestReview(visitCount: 3, lastRequestedMilestone: 10))
    }
}
