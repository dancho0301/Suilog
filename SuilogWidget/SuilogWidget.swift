//
//  SuilogWidget.swift
//  SuilogWidget
//
//  ビルドを通すための最小のウィジェット（次のタスクで本物に置き換える）。
//

import SwiftUI
import WidgetKit

struct SuilogWidgetEntry: TimelineEntry {
    let date: Date
}

struct SuilogWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SuilogWidgetEntry {
        SuilogWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SuilogWidgetEntry) -> Void) {
        completion(SuilogWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuilogWidgetEntry>) -> Void) {
        completion(Timeline(entries: [SuilogWidgetEntry(date: Date())], policy: .never))
    }
}

struct SuilogWidgetView: View {
    let entry: SuilogWidgetEntry

    var body: some View {
        // 共有ファイル（Shared/WidgetSnapshot.swift）がウィジェットにもコンパイルされていることの確認
        let _ = WidgetSnapshotStore.appGroupId
        Text("スイログ")
            .containerBackground(for: .widget) { Color.blue }
    }
}

struct SuilogWidget: Widget {
    let kind = "SuilogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuilogWidgetProvider()) { entry in
            SuilogWidgetView(entry: entry)
        }
        .configurationDisplayName("スイログ")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
