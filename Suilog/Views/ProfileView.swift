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
    @State private var showingProfileShare = false
    @State private var showingProStore = false
    @State private var showingTipJar = false
    @State private var nickname: String = CloudSettingsManager.shared.string(forKey: CloudSettingsManager.nicknameKey) ?? ""
    @State private var nicknameInput = ""
    @State private var showingNicknameEditor = false
    @State private var exportedFile: ExportedFile?
    @State private var showingExportError = false

    /// sheet(item:) 用のエクスポートファイルラッパー
    private struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var theme: Theme { themeManager.currentTheme }

    private var displayName: String {
        nickname.isEmpty ? "アクアリストさん" : nickname
    }

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

    /// 同じ水族館への最多訪問回数
    private var maxVisitsToOneAquarium: Int {
        let counts = Dictionary(grouping: visitRecords.compactMap { $0.aquarium?.id }) { $0 }
        return counts.values.map(\.count).max() ?? 0
    }

    /// 写真付きの記録数
    private var photoRecordCount: Int {
        visitRecords.filter { $0.photoData != nil }.count
    }

    /// 今年訪問した水族館数（ユニーク）
    private var visitedThisYear: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let ids = visitRecords
            .filter { calendar.component(.year, from: $0.visitDate) == year }
            .compactMap { $0.aquarium?.id }
        return Set(ids).count
    }

    private var allBadges: [Badge] {
        Badge.allBadges(
            visitedCount: visitedCount,
            goldCount: goldCount,
            silverCount: silverCount,
            visitedRegions: Set(visitRecords.compactMap { $0.aquarium?.region }).count,
            maxVisitsToOneAquarium: maxVisitsToOneAquarium,
            photoRecordCount: photoRecordCount,
            visitedThisYear: visitedThisYear
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
        .sheet(isPresented: $showingProStore) {
            ProStoreView()
                .environmentObject(storeManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingTipJar) {
            TipJarView()
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
        .sheet(isPresented: $showingProfileShare) {
            ProfileShareSheet(
                nickname: displayName,
                rankTitle: rankTitle,
                visitedCount: visitedCount,
                totalAquariumCount: aquariums.count,
                goldCount: goldCount,
                silverCount: silverCount,
                earnedBadges: earnedBadges,
                theme: theme
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $exportedFile) { file in
            exportSheet(file: file)
                .presentationDetents([.medium])
        }
        .alert("ニックネームを変更", isPresented: $showingNicknameEditor) {
            TextField("ニックネーム", text: $nicknameInput)
            Button("保存") {
                let trimmed = nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                nickname = trimmed
                CloudSettingsManager.shared.set(
                    trimmed.isEmpty ? nil : trimmed,
                    forKey: CloudSettingsManager.nicknameKey
                )
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("プロフィールに表示する名前を入力してください")
        }
        .alert("エクスポートに失敗しました", isPresented: $showingExportError) {
            Button("OK", role: .cancel) { }
        }
    }

    /// エクスポート結果シート（共有ボタン付き）
    private func exportSheet(file: ExportedFile) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 44))
                .foregroundColor(theme.primaryColor)
            VStack(spacing: 6) {
                Text("エクスポート完了")
                    .font(SuiFont.heading)
                    .foregroundColor(SuiColor.heading)
                Text("訪問記録 \(visitRecords.count)件をJSON形式で書き出しました。\n※ 写真データは含まれません")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.midText)
                    .multilineTextAlignment(.center)
            }
            ShareLink(item: file.url) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("ファイルを共有")
                        .font(SuiFont.bodyMedium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                        .fill(theme.primaryColor)
                )
            }
            .padding(.horizontal, SuiSpacing.screenHorizontal)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.primaryBg)
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
            Button {
                nicknameInput = nickname
                showingNicknameEditor = true
            } label: {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(SuiFont.heading)
                        .foregroundColor(.white)
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .accessibilityIdentifier("nicknameEditButton")
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
                showingProStore = true
            } label: {
                settingsRow(
                    icon: "crown.fill",
                    title: "スイログ Pro",
                    subtitle: storeManager.isProUnlocked
                        ? "利用中 - ありがとうございます！"
                        : "写真無制限などの追加機能"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("proStoreButton")

            Button {
                showingTipJar = true
            } label: {
                settingsRow(
                    icon: "heart.fill",
                    title: "開発者を応援する",
                    subtitle: "エサやりチップで開発を応援"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tipJarButton")

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

            Button {
                exportVisitRecords()
            } label: {
                settingsRow(
                    icon: "square.and.arrow.up.on.square.fill",
                    title: "データをエクスポート",
                    subtitle: "訪問記録をJSONで書き出し"
                )
            }
            .buttonStyle(.plain)
            .disabled(visitRecords.isEmpty)
            .opacity(visitRecords.isEmpty ? 0.5 : 1)
            .accessibilityIdentifier("exportDataButton")
        }
    }

    private func exportVisitRecords() {
        do {
            let url = try DataExporter.exportVisitRecords(visitRecords)
            exportedFile = ExportedFile(url: url)
        } catch {
            showingExportError = true
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
            showingProfileShare = true
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

    static func allBadges(
        visitedCount: Int,
        goldCount: Int,
        silverCount: Int,
        visitedRegions: Int,
        maxVisitsToOneAquarium: Int,
        photoRecordCount: Int,
        visitedThisYear: Int
    ) -> [Badge] {
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
                id: "twentyfive_tanks",
                icon: "🐢",
                title: "25館制覇",
                description: "25館に訪問",
                progress: min(Double(visitedCount) / 25.0, 1.0),
                progressText: "\(min(visitedCount, 25)) / 25"
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
                id: "silver_ten",
                icon: "🥈",
                title: "シルバー10",
                description: "手動チェックイン10回",
                progress: min(Double(silverCount) / 10.0, 1.0),
                progressText: "\(min(silverCount, 10)) / 10"
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
                id: "repeater",
                icon: "🐡",
                title: "常連さん",
                description: "同じ水族館に5回訪問",
                progress: min(Double(maxVisitsToOneAquarium) / 5.0, 1.0),
                progressText: "\(min(maxVisitsToOneAquarium, 5)) / 5"
            ),
            Badge(
                id: "photographer",
                icon: "📸",
                title: "フォトグラファー",
                description: "写真付きの記録10件",
                progress: min(Double(photoRecordCount) / 10.0, 1.0),
                progressText: "\(min(photoRecordCount, 10)) / 10"
            ),
            Badge(
                id: "annual_pass",
                icon: "📅",
                title: "年間パスポート",
                description: "1年で10館に訪問",
                progress: min(Double(visitedThisYear) / 10.0, 1.0),
                progressText: "\(min(visitedThisYear, 10)) / 10"
            ),
            Badge(
                id: "fifty_tanks",
                icon: "🌊",
                title: "50館制覇",
                description: "50館に訪問",
                progress: min(Double(visitedCount) / 50.0, 1.0),
                progressText: "\(min(visitedCount, 50)) / 50"
            ),
            Badge(
                id: "hundred_tanks",
                icon: "🏆",
                title: "100館制覇",
                description: "100館に訪問",
                progress: min(Double(visitedCount) / 100.0, 1.0),
                progressText: "\(min(visitedCount, 100)) / 100"
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
