//
//  WidgetSnapshotBuilder.swift
//  Suilog
//
//  訪問記録・テーマ・Pro 状態から、ウィジェットに渡すスナップショットを作る。
//  （SwiftData の VisitRecord に依存するため、ウィジェットのターゲットには含めない）
//

import Foundation

extension WidgetSnapshot {
    /// 最近の訪問として載せる件数
    nonisolated static let recentVisitLimit = 3

    @MainActor
    init(visits: [VisitRecord], theme: Theme, isPro: Bool, now: Date = Date()) {
        // 新しい順。同じ日時でも並びが毎回同じになるよう ID で決める
        let newestFirst = visits.sorted {
            ($0.visitDate, $0.id.uuidString) > ($1.visitDate, $1.id.uuidString)
        }
        let recent = newestFirst.prefix(Self.recentVisitLimit).map { visit in
            RecentVisit(
                aquariumName: visit.aquarium?.name ?? "水族館",
                visitDate: visit.visitDate,
                isLocationCheckIn: visit.checkInType == .location
            )
        }

        self.init(
            visitedAquariumCount: Set(visits.compactMap { $0.aquarium?.id }).count,
            visitCount: visits.count,
            recentVisits: Array(recent),
            primaryHex: theme.primaryColorHex,
            tankTopHex: theme.tankTopHex ?? theme.primaryColorHex,
            tankBottomHex: theme.tankBottomHex ?? theme.primaryColorHex,
            isPro: isPro,
            updatedAt: now
        )
    }
}
