//
//  ProfileView.swift
//  Suilog
//
//  Created per design_handoff_suilog spec (§6 プロフィール).
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var locationManager: LocationManager
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord]

    @State private var showingThemeStore = false
    @State private var showingOnboarding = false

    private var theme: Theme { themeManager.currentTheme }

    private var visitedCount: Int {
        Set(visitRecords.compactMap { $0.aquarium?.id }).count
    }

    private var goldCount: Int {
        visitRecords.filter { $0.checkInType == .location }.count
    }

    private var silverCount: Int {
        visitRecords.filter { $0.checkInType == .manual }.count
    }

    private var rankTitle: String {
        switch visitedCount {
        case 0: return "初心者トレーナー"
        case 1..<5: return "見習いアクアリスト"
        case 5..<15: return "アクアリスト"
        case 15..<40: return "ベテランアクアリスト"
        case 40..<80: return "水族館マスター"
        default: return "伝説のアクアリスト"
        }
    }

    private var allBadges: [Badge] {
        Badge.allBadges(
            visitedCount: visitedCount,
            goldCount: goldCount,
            visitedRegions: Set(visitRecords.compactMap { $0.aquarium?.region }).count
        )
    }

    private var earnedBadges: [Badge] { allBadges.filter { $0.isEarned } }
    private var inProgressBadges: [Badge] { allBadges.filter { !$0.isEarned } }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        heroCard
                        statsCard
                        earnedSection
                        inProgressSection
                        settingsSection
                        shareButton
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingThemeStore) {
            ThemeStoreView()
                .environmentObject(storeManager)
                .environmentObject(themeManager)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isReplay: true) {
                showingOnboarding = false
            }
            .environmentObject(themeManager)
            .environmentObject(locationManager)
        }
    }

    // MARK: - Sections

    private var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                Text("🐠").font(.system(size: 42))
            }
            Text("アクアリストさん")
                .font(SuiFont.heading)
                .foregroundColor(.white)
            Text(rankTitle)
                .font(SuiFont.label)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.2)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [theme.primaryColor, theme.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: SuiRadius.cardLarge, style: .continuous))
        .suiShadow(.cardEmphasized(primary: theme.primaryColor))
    }

    private var statsCard: some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 18) {
            HStack(spacing: 0) {
                StatItem(value: "\(visitedCount)", label: "訪問館数", primary: theme.primaryColor)
                Divider().frame(height: 36).background(SuiColor.divider)
                VStack(spacing: 4) {
                    Text("\(goldCount + silverCount)")
                        .font(SuiFont.stat)
                        .foregroundColor(theme.primaryColor)
                    HStack(spacing: 4) {
                        Text("🥇\(goldCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SuiColor.goldText)
                        Text("🥈\(silverCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SuiColor.silverText)
                    }
                }
                .frame(maxWidth: .infinity)
                Divider().frame(height: 36).background(SuiColor.divider)
                StatItem(value: "\(earnedBadges.count)", label: "バッジ", primary: theme.primaryColor)
            }
        }
    }

    private var earnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("獲得したバッジ") {
                Text("\(earnedBadges.count) / \(allBadges.count)")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.subText)
            }

            if earnedBadges.isEmpty {
                SuiCard(radius: SuiRadius.cardMedium, padding: 20) {
                    Text("まだバッジを獲得していません。\n水族館にチェックインしよう！")
                        .font(SuiFont.body)
                        .foregroundColor(SuiColor.midText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(earnedBadges) { badge in
                        EarnedBadgeTile(badge: badge, theme: theme)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inProgressSection: some View {
        if !inProgressBadges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("挑戦中のバッジ")
                VStack(spacing: 10) {
                    ForEach(inProgressBadges) { badge in
                        InProgressBadgeRow(badge: badge, theme: theme)
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("設定")
            Button {
                showingThemeStore = true
            } label: {
                settingsRow(
                    icon: "paintpalette.fill",
                    title: "テーマを変える",
                    subtitle: themeManager.currentTheme.name
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("themeStoreButton")

            Button {
                showingOnboarding = true
            } label: {
                settingsRow(
                    icon: "questionmark.circle.fill",
                    title: "使い方を見る",
                    subtitle: "アプリの紹介をもう一度表示"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboardingReplayButton")
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(SuiColor.heading)
                    Text(subtitle)
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.subText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SuiColor.subText)
            }
        }
    }

    private var shareButton: some View {
        Button {
            // 将来実装: バッジシェア
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("バッジをシェアする")
                    .font(SuiFont.bodyMedium)
            }
            .foregroundColor(theme.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                            .strokeBorder(theme.primaryLight, lineWidth: 1.5)
                    )
            )
        }
    }
}

// MARK: - バッジモデル

struct Badge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let progress: Double      // 0.0 - 1.0
    let progressText: String  // "3 / 5"

    var isEarned: Bool { progress >= 1.0 }

    static func allBadges(visitedCount: Int, goldCount: Int, visitedRegions: Int) -> [Badge] {
        [
            Badge(
                id: "first_step",
                icon: "🎉",
                title: "はじめの一歩",
                description: "初めての訪問",
                progress: min(Double(visitedCount), 1.0),
                progressText: "\(min(visitedCount, 1)) / 1"
            ),
            Badge(
                id: "five_tanks",
                icon: "🐠",
                title: "5館制覇",
                description: "5館に訪問",
                progress: min(Double(visitedCount) / 5.0, 1.0),
                progressText: "\(min(visitedCount, 5)) / 5"
            ),
            Badge(
                id: "ten_tanks",
                icon: "🐙",
                title: "10館制覇",
                description: "10館に訪問",
                progress: min(Double(visitedCount) / 10.0, 1.0),
                progressText: "\(min(visitedCount, 10)) / 10"
            ),
            Badge(
                id: "gold_ten",
                icon: "🥇",
                title: "ゴールド10",
                description: "位置情報チェックイン10回",
                progress: min(Double(goldCount) / 10.0, 1.0),
                progressText: "\(min(goldCount, 10)) / 10"
            ),
            Badge(
                id: "region_master",
                icon: "🗾",
                title: "地域マスター",
                description: "全7地域を制覇",
                progress: min(Double(visitedRegions) / 7.0, 1.0),
                progressText: "\(min(visitedRegions, 7)) / 7"
            ),
            Badge(
                id: "fifty_tanks",
                icon: "🌊",
                title: "50館制覇",
                description: "50館に訪問",
                progress: min(Double(visitedCount) / 50.0, 1.0),
                progressText: "\(min(visitedCount, 50)) / 50"
            )
        ]
    }
}

// MARK: - 獲得済みバッジタイル

private struct EarnedBadgeTile: View {
    let badge: Badge
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Text(badge.icon)
                    .font(.system(size: 36))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(theme.primaryBg))

                ZStack {
                    Circle().fill(theme.primaryColor).frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                }
            }
            Text(badge.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SuiColor.heading)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.primaryLight, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - 挑戦中バッジ行

private struct InProgressBadgeRow: View {
    let badge: Badge
    let theme: Theme

    var body: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            HStack(spacing: 14) {
                Text(badge.icon)
                    .font(.system(size: 28))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(theme.primaryBg))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(badge.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SuiColor.heading)
                        Spacer()
                        Text(badge.progressText)
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                    }
                    Text(badge.description)
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.midText)
                    ProgressBar(progress: badge.progress, theme: theme)
                        .frame(height: 6)
                }
            }
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "#EEF4F8"))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.primaryLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(progress))
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: VisitRecord.self, inMemory: true)
        .environmentObject(ThemeManager())
        .environmentObject(StoreManager())
        .environmentObject(LocationManager())
}
