//
//  CreatureCollection.swift
//  Suilog
//
//  生き物の「会った」記録（CreatureSighting）の集計・更新ロジック。
//  ビューから切り出してテスト可能にする。
//

import Foundation
import SwiftData

enum CreatureCollection {
    /// 目撃済みの生き物IDの集合
    static func seenIds(from sightings: [CreatureSighting]) -> Set<String> {
        Set(sightings.map(\.creatureId))
    }

    /// 指定の生き物が目撃済みか
    static func isSeen(_ creatureId: String, in sightings: [CreatureSighting]) -> Bool {
        sightings.contains { $0.creatureId == creatureId }
    }

    /// コレクション達成率（0.0〜1.0）
    static func completionRate(seenCount: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return min(Double(seenCount) / Double(totalCount), 1.0)
    }

    /// 生き物を「会った」として記録する（既に記録済みなら何もしない）
    /// - Returns: 新たに記録した場合 true
    @discardableResult
    static func markSeen(
        creatureId: String,
        aquariumName: String = "",
        date: Date = Date(),
        context: ModelContext,
        existing: [CreatureSighting]
    ) -> Bool {
        guard !isSeen(creatureId, in: existing) else { return false }
        let sighting = CreatureSighting(
            creatureId: creatureId,
            firstSeenDate: date,
            aquariumName: aquariumName
        )
        context.insert(sighting)
        return true
    }

    /// 生き物の「会った」記録を取り消す（同一IDの記録をすべて削除）
    static func unmark(
        creatureId: String,
        context: ModelContext,
        existing: [CreatureSighting]
    ) {
        for sighting in existing where sighting.creatureId == creatureId {
            context.delete(sighting)
        }
    }
}
