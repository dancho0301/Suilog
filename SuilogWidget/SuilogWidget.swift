//
//  SuilogWidget.swift
//  SuilogWidget
//
//  ホーム画面に「訪問の記録」を表示するウィジェット（スイログ Pro の特典）。
//  表示するデータは、アプリが App Group に書き出した WidgetSnapshot を読むだけ。
//

import WidgetKit
import SwiftUI

struct SuilogWidgetEntry: TimelineEntry {
    let date: Date
    /// nil = アプリがまだスナップショットを書き出していない（または読めなかった）
    let snapshot: WidgetSnapshot?
}

struct SuilogWidgetProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> SuilogWidgetEntry {
        SuilogWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SuilogWidgetEntry) -> Void) {
        // ウィジェットギャラリーのプレビューにはサンプルを使う
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder : store.load()
        completion(SuilogWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuilogWidgetEntry>) -> Void) {
        // 更新はアプリからの reloadAllTimelines が中心。念のため 6 時間後にも読み直す
        let entry = SuilogWidgetEntry(date: Date(), snapshot: store.load())
        let nextUpdate = Date().addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct SuilogWidget: Widget {
    let kind = "SuilogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuilogWidgetProvider()) { entry in
            SuilogWidgetView(entry: entry)
        }
        .configurationDisplayName("訪問の記録")
        .description("訪問した水族館の数や、最近の訪問を表示します。（スイログ Pro）")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("小", as: .systemSmall) {
    SuilogWidget()
} timeline: {
    SuilogWidgetEntry(date: Date(), snapshot: .placeholder)
    SuilogWidgetEntry(date: Date(), snapshot: .placeholderLocked)
    SuilogWidgetEntry(date: Date(), snapshot: nil)
}

#Preview("中", as: .systemMedium) {
    SuilogWidget()
} timeline: {
    SuilogWidgetEntry(date: Date(), snapshot: .placeholder)
    SuilogWidgetEntry(date: Date(), snapshot: .placeholderLocked)
    SuilogWidgetEntry(date: Date(), snapshot: nil)
}
