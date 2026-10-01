//
//  SuilogWidgetView.swift
//  SuilogWidget
//

import WidgetKit
import SwiftUI

struct SuilogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SuilogWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if snapshot.isPro {
                    content(snapshot)
                } else {
                    message(icon: "crown.fill", text: "スイログ Pro で使えます")
                }
            } else {
                message(icon: "fish.fill", text: "アプリを開くと表示されます")
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 0.5)
        .containerBackground(for: .widget) { background }
    }

    // MARK: - 背景（テーマの水槽の色）

    private var background: some View {
        LinearGradient(
            colors: [
                Color(widgetHex: entry.snapshot?.tankTopHex ?? "#A8D8EF"),
                Color(widgetHex: entry.snapshot?.tankBottomHex ?? "#6BBBD8")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(Color.black.opacity(0.3))
    }

    // MARK: - Pro の人に見せる内容

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        if family == .systemMedium {
            HStack(alignment: .top, spacing: 16) {
                stats(snapshot)
                Divider().overlay(Color.white.opacity(0.4))
                recentVisits(snapshot)
            }
        } else {
            stats(snapshot)
        }
    }

    private func stats(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("訪問した水族館")
                .font(.caption2)
                .opacity(0.95)
            Text("\(snapshot.visitedAquariumCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("訪問 \(snapshot.visitCount) 回")
                .font(.caption.weight(.medium))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recentVisits(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("最近の訪問")
                .font(.caption2)
                .opacity(0.95)
            if snapshot.recentVisits.isEmpty {
                Text("まだ訪問記録がありません")
                    .font(.caption)
            } else {
                ForEach(Array(snapshot.recentVisits.enumerated()), id: \.offset) { _, visit in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(visit.aquariumName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(visit.visitDate, format: .dateTime.year().month().day())
                            .font(.caption2)
                            .opacity(0.95)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pro ではない / まだデータがない

    private func message(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(text)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
