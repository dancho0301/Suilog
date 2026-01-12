//
//  StatisticsView.swift
//  Suilog
//
//  Created by Claude on 2026/01/12.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord]
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var animateProgress = false
    @State private var showConfetti = false

    /// 地域の順序（北から南へ）
    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
    ]

    /// 地域の絵文字
    private let regionEmojis: [String: String] = [
        "北海道": "🦌",
        "東北": "🍎",
        "関東": "🗼",
        "中部": "🗻",
        "近畿": "⛩️",
        "中国・四国": "🍊",
        "九州・沖縄": "🌺"
    ]

    /// 全体の達成率
    private var achievementRate: Double {
        let visitedCount = aquariums.filter { !$0.visits.isEmpty }.count
        guard !aquariums.isEmpty else { return 0.0 }
        return Double(visitedCount) / Double(aquariums.count)
    }

    /// 訪問済み水族館数
    private var visitedCount: Int {
        aquariums.filter { !$0.visits.isEmpty }.count
    }

    /// 地域別訪問統計
    private var regionalStats: [(region: String, visitedCount: Int, totalCount: Int)] {
        regionOrder.map { region in
            let regionAquariums = aquariums.filter { $0.region == region }
            let visitedInRegion = regionAquariums.filter { !$0.visits.isEmpty }.count
            return (region: region, visitedCount: visitedInRegion, totalCount: regionAquariums.count)
        }
    }

    /// 月別訪問統計（過去12ヶ月）
    private var monthlyStats: [(month: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        var stats: [(Date, Int)] = []

        for i in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthComponents = calendar.dateComponents([.year, .month], from: monthStart) as DateComponents? else {
                continue
            }

            let count = visitRecords.filter { visit in
                let visitComponents = calendar.dateComponents([.year, .month], from: visit.visitDate)
                return visitComponents.year == monthComponents.year &&
                       visitComponents.month == monthComponents.month
            }.count

            stats.append((monthStart, count))
        }

        return stats
    }

    /// 最も訪問した水族館（トップ5）
    private var topAquariums: [(aquarium: Aquarium, visitCount: Int)] {
        aquariums
            .filter { !$0.visits.isEmpty }
            .map { ($0, $0.visits.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    /// 達成度に応じたメッセージ
    private var achievementMessage: (emoji: String, title: String, subtitle: String) {
        let rate = achievementRate
        switch rate {
        case 0:
            return ("🐠", "はじめよう！", "最初の水族館に行ってみよう")
        case 0..<0.1:
            return ("🌊", "いい調子！", "水族館の旅が始まったね")
        case 0.1..<0.25:
            return ("🐬", "すごい！", "もっと発見が待ってるよ")
        case 0.25..<0.5:
            return ("🐙", "素晴らしい！", "水族館マスターへの道")
        case 0.5..<0.75:
            return ("🦈", "驚異的！", "半分以上制覇したよ！")
        case 0.75..<1.0:
            return ("🐋", "伝説級！", "もうすぐコンプリート！")
        default:
            return ("👑", "完全制覇！", "すべての水族館を巡ったよ！")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヒーローセクション（達成率）
                heroSection

                // 地域別カード
                regionalCardsSection

                // 月別トレンド
                monthlyTrendSection

                // ランキング
                rankingSection

                // 統計サマリー
                statsSummarySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("統計")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                animateProgress = true
            }
        }
    }

    // MARK: - ヒーローセクション
    private var heroSection: some View {
        VStack(spacing: 16) {
            // 絵文字とメッセージ
            Text(achievementMessage.emoji)
                .font(.system(size: 60))
                .scaleEffect(animateProgress ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: animateProgress)

            Text(achievementMessage.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(achievementMessage.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 円形プログレス
            ZStack {
                // 背景円
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // プログレス円
                Circle()
                    .trim(from: 0, to: animateProgress ? achievementRate : 0)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.4, green: 0.8, blue: 1.0),
                                Color(red: 0.6, green: 0.4, blue: 1.0),
                                Color(red: 1.0, green: 0.4, blue: 0.6),
                                Color(red: 0.4, green: 0.8, blue: 1.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3), value: animateProgress)

                // 中央の数値
                VStack(spacing: 4) {
                    Text("\(Int(achievementRate * 100))%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("\(visitedCount)/\(aquariums.count)館")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.purple.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }

    // MARK: - 地域別カードセクション
    private var regionalCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🗾")
                    .font(.title2)
                Text("地域別")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(regionalStats, id: \.region) { stat in
                    RegionalCard(
                        region: stat.region,
                        emoji: regionEmojis[stat.region] ?? "🐟",
                        visited: stat.visitedCount,
                        total: stat.totalCount,
                        animate: animateProgress
                    )
                }
            }
        }
    }

    // MARK: - 月別トレンドセクション
    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📈")
                    .font(.title2)
                Text("訪問トレンド")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            if visitRecords.isEmpty {
                EmptyStateCard(
                    emoji: "🎯",
                    message: "水族館に行くと\nここにグラフが表示されるよ！"
                )
            } else {
                VStack(spacing: 8) {
                    Chart {
                        ForEach(monthlyStats, id: \.month) { stat in
                            BarMark(
                                x: .value("月", stat.month, unit: .month),
                                y: .value("訪問数", stat.count)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.8, blue: 1.0),
                                        Color(red: 0.6, green: 0.4, blue: 1.0)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(6)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 2)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month(.abbreviated))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 180)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.blue.opacity(0.1), radius: 15, x: 0, y: 5)
                )
            }
        }
    }

    // MARK: - ランキングセクション
    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🏆")
                    .font(.title2)
                Text("よく行く水族館")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            if topAquariums.isEmpty {
                EmptyStateCard(
                    emoji: "🎪",
                    message: "水族館を訪れると\nランキングが表示されるよ！"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topAquariums.enumerated()), id: \.element.aquarium.id) { index, item in
                        RankingRow(
                            rank: index + 1,
                            name: item.aquarium.name,
                            count: item.visitCount,
                            isFirst: index == 0,
                            isLast: index == topAquariums.count - 1
                        )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.orange.opacity(0.1), radius: 15, x: 0, y: 5)
                )
            }
        }
    }

    // MARK: - 統計サマリーセクション
    private var statsSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📊")
                    .font(.title2)
                Text("まとめ")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 12) {
                StatBubble(
                    value: "\(visitRecords.count)",
                    label: "総訪問",
                    emoji: "🎫",
                    color: Color(red: 0.4, green: 0.8, blue: 0.6)
                )

                StatBubble(
                    value: "\(visitRecords.filter { $0.checkInType == .location }.count)",
                    label: "位置情報",
                    emoji: "📍",
                    color: Color(red: 1.0, green: 0.7, blue: 0.3)
                )

                StatBubble(
                    value: "\(visitRecords.filter { $0.checkInType == .manual }.count)",
                    label: "手動",
                    emoji: "✏️",
                    color: Color(red: 0.6, green: 0.7, blue: 0.9)
                )
            }
        }
    }
}

// MARK: - 地域別カード
struct RegionalCard: View {
    let region: String
    let emoji: String
    let visited: Int
    let total: Int
    let animate: Bool

    private var rate: Double {
        guard total > 0 else { return 0 }
        return Double(visited) / Double(total)
    }

    private var isComplete: Bool {
        visited == total && total > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.title3)
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }

            Text(region)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // ミニプログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isComplete
                                    ? [Color.green, Color.green.opacity(0.7)]
                                    : [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animate ? geometry.size.width * rate : 0, height: 8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.5), value: animate)
                }
            }
            .frame(height: 8)

            Text("\(visited)/\(total)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - ランキング行
struct RankingRow: View {
    let rank: Int
    let name: String
    let count: Int
    let isFirst: Bool
    let isLast: Bool

    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if rank <= 3 {
                Text(rankEmoji)
                    .font(.title2)
                    .frame(width: 36)
            } else {
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 36)
            }

            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Text("\(count)回")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.15))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(
            .rect(
                topLeadingRadius: isFirst ? 20 : 0,
                bottomLeadingRadius: isLast ? 20 : 0,
                bottomTrailingRadius: isLast ? 20 : 0,
                topTrailingRadius: isFirst ? 20 : 0
            )
        )

        if !isLast {
            Divider()
                .padding(.leading, 60)
        }
    }
}

// MARK: - 統計バブル
struct StatBubble: View {
    let value: String
    let label: String
    let emoji: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.title2)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - 空状態カード
struct EmptyStateCard: View {
    let emoji: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 48))

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 15, x: 0, y: 5)
        )
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
            .modelContainer(for: Aquarium.self, inMemory: true)
            .environmentObject(ThemeManager())
    }
}
