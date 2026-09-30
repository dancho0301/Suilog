//
//  WidgetSnapshotSync.swift
//  Suilog
//
//  訪問記録・テーマ・Pro 状態が変わったら、ウィジェット用のスナップショットを書き出して更新を依頼する。
//

import SwiftUI
import WidgetKit

@MainActor
enum WidgetSnapshotSync {
    /// スナップショットを保存し、ウィジェットの更新を依頼する
    /// - Parameter entitlementsLoaded: 購入状態（権利）の読み込みが終わっているか。
    ///   起動直後は Pro 判定が false のため、読み込み前に書き出すと Pro の人のウィジェットがロック表示になる
    /// - Returns: 書き出したかどうか
    @discardableResult
    static func write(
        _ snapshot: WidgetSnapshot,
        entitlementsLoaded: Bool,
        store: WidgetSnapshotStore = WidgetSnapshotStore(),
        reload: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) -> Bool {
        guard entitlementsLoaded else { return false }
        store.save(snapshot)
        reload()
        return true
    }
}

extension View {
    /// 訪問記録・テーマ・Pro 状態の変化を、ウィジェットに反映する
    func syncsWidgetSnapshot(
        visits: [VisitRecord],
        theme: Theme,
        isPro: Bool,
        entitlementsLoaded: Bool
    ) -> some View {
        modifier(WidgetSnapshotSyncModifier(
            visits: visits,
            theme: theme,
            isPro: isPro,
            entitlementsLoaded: entitlementsLoaded
        ))
    }
}

private struct WidgetSnapshotSyncModifier: ViewModifier {
    let visits: [VisitRecord]
    let theme: Theme
    let isPro: Bool
    let entitlementsLoaded: Bool

    /// 変化の検出用（更新日時は含めない）
    private struct Trigger: Equatable {
        let snapshot: WidgetSnapshot
        let entitlementsLoaded: Bool
    }

    func body(content: Content) -> some View {
        let snapshot = WidgetSnapshot(visits: visits, theme: theme, isPro: isPro)
        let trigger = Trigger(snapshot: snapshot.withoutTimestamp, entitlementsLoaded: entitlementsLoaded)
        content.onChange(of: trigger, initial: true) {
            WidgetSnapshotSync.write(snapshot, entitlementsLoaded: entitlementsLoaded)
        }
    }
}
