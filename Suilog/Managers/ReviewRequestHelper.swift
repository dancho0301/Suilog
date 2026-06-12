//
//  ReviewRequestHelper.swift
//  Suilog
//
//  App Storeレビュー依頼のタイミング判定。
//  チェックインの節目（嬉しい瞬間）でのみ依頼し、同じ節目では二度依頼しない。
//

import Foundation

enum ReviewRequestHelper {
    /// レビューを依頼する訪問数の節目
    static let milestones = [3, 10, 25, 50]

    /// 最後にレビューを依頼した節目を保存するUserDefaultsキー
    static let lastRequestedMilestoneKey = "LastReviewRequestMilestone"

    /// レビューを依頼すべきかを判定する
    /// - Parameters:
    ///   - visitCount: 現在の訪問記録数
    ///   - lastRequestedMilestone: 最後に依頼した節目（未依頼なら0）
    /// - Returns: 節目に達しており、その節目でまだ依頼していなければ true
    static func shouldRequestReview(visitCount: Int, lastRequestedMilestone: Int) -> Bool {
        milestones.contains(visitCount) && visitCount > lastRequestedMilestone
    }
}
