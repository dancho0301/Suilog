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

    /// 地域の順序（北から南へ）
    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
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

    /// 最も訪問した地域
    private var topRegion: (region: String, count: Int)? {
        let regionCounts = Dictionary(grouping: visitRecords.compactMap { $0.aquarium?.region }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        guard let top = regionCounts.first else { return nil }
        return (region: top.key, count: top.value)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 達成率セクション
                    achievementSection

                    // 地域別訪問数グラフ
                    regionalChartSection

                    // 月別トレンドグラフ
                    monthlyTrendSection

                    // その他の統計
                    additionalStatsSection
                }
                .padding()
            }
            .navigationTitle("統計")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - 達成率セクション
    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("達成率")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("\(visitedCount) / \(aquariums.count) 館")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(Int(achievementRate * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }

                // プログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 20)

                        // 進捗
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.primaryColor.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * achievementRate, height: 20)
                    }
                }
                .frame(height: 20)
            }

            // 地域別達成率内訳
            VStack(alignment: .leading, spacing: 8) {
                Text("地域別達成率")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                ForEach(regionalStats, id: \.region) { stat in
                    HStack {
                        Text(stat.region)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 12)

                                if stat.totalCount > 0 {
                                    let rate = Double(stat.visitedCount) / Double(stat.totalCount)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.7))
                                        .frame(width: geometry.size.width * rate, height: 12)
                                }
                            }
                        }
                        .frame(height: 12)

                        Text("\(stat.visitedCount)/\(stat.totalCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - 地域別訪問数グラフ
    private var regionalChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("地域別訪問数")
                .font(.headline)

            if visitRecords.isEmpty {
                Text("まだ訪問記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(regionalStats, id: \.region) { stat in
                        BarMark(
                            x: .value("訪問数", stat.visitedCount),
                            y: .value("地域", stat.region)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.primaryColor.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel()
                    }
                }
                .frame(height: 280)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - 月別トレンドグラフ
    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("月別訪問トレンド（過去12ヶ月）")
                .font(.headline)

            if visitRecords.isEmpty {
                Text("まだ訪問記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(monthlyStats, id: \.month) { stat in
                        LineMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("訪問数", stat.count)
                        )
                        .foregroundStyle(themeManager.currentTheme.primaryColor)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("訪問数", stat.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.primaryColor.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("訪問数", stat.count)
                        )
                        .foregroundStyle(themeManager.currentTheme.primaryColor)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.narrow))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - その他の統計
    private var additionalStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("その他の統計")
                .font(.headline)

            VStack(spacing: 12) {
                // 最も訪問した水族館
                if !topAquariums.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("よく訪れる水族館")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(Array(topAquariums.enumerated()), id: \.element.aquarium.id) { index, item in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)

                                Text(item.aquarium.name)
                                    .font(.subheadline)

                                Spacer()

                                Text("\(item.visitCount)回")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Divider()
                }

                // 最も訪問した地域
                if let topRegion = topRegion {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最も訪れた地域")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(topRegion.region)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Text("\(topRegion.count)回")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }

                    Divider()
                }

                // 総訪問回数
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("総訪問回数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(visitRecords.count)回")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text("\(visitRecords.filter { $0.checkInType == .location }.count)")
                                    .font(.caption)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("\(visitRecords.filter { $0.checkInType == .manual }.count)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(ThemeManager())
}
