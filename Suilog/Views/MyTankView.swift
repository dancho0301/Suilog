//
//  MyTankView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//  Redesigned per design_handoff_suilog spec.
//

import SwiftUI
import SwiftData
import Combine

struct MyTankView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \VisitRecord.visitDate, order: .reverse) private var visitRecords: [VisitRecord]

    let onTapAvatar: () -> Void
    let onSeeAllVisits: () -> Void

    init(
        onTapAvatar: @escaping () -> Void = {},
        onSeeAllVisits: @escaping () -> Void = {}
    ) {
        self.onTapAvatar = onTapAvatar
        self.onSeeAllVisits = onSeeAllVisits
    }

    private var visitedAquariumsCount: Int {
        Set(visitRecords.compactMap { $0.aquarium?.id }).count
    }

    private var creaturesCount: Int {
        Set(visitRecords.compactMap { $0.aquarium?.representativeFish }).count
    }

    private var visitCount: Int {
        visitRecords.count
    }

    private var recentVisits: [VisitRecord] {
        Array(visitRecords.prefix(5))
    }

    private var theme: Theme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        TankCardView(visits: visitRecords, theme: theme)
                            .frame(height: 280)
                        statsCard
                        recentSection
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("こんにちは 👋")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.midText)
                Text("マイ水槽")
                    .font(SuiFont.screenTitle)
                    .foregroundColor(SuiColor.heading)
            }
            Spacer()
            Button(action: onTapAvatar) {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 44, height: 44)
                        .suiShadow(.primaryButton(primary: theme.primaryColor))
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .accessibilityIdentifier("themeStoreButton")
        }
    }

    private var statsCard: some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 18) {
            HStack(spacing: 0) {
                StatItem(value: "\(visitedAquariumsCount)", label: "訪問水族館", primary: theme.primaryColor)
                Divider().frame(height: 32).background(SuiColor.divider)
                StatItem(value: "\(creaturesCount)", label: "生き物", primary: theme.primaryColor)
                Divider().frame(height: 32).background(SuiColor.divider)
                StatItem(value: "\(visitCount)", label: "訪問回数", primary: theme.primaryColor)
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("最近の訪問") {
                Button(action: onSeeAllVisits) {
                    Text("すべて見る")
                        .font(SuiFont.label)
                        .foregroundColor(theme.primaryColor)
                }
            }

            if recentVisits.isEmpty {
                SuiCard(radius: SuiRadius.cardMedium, padding: 20) {
                    HStack {
                        Text("まだ訪問記録がありません。水族館に行ってみよう！")
                            .font(SuiFont.body)
                            .foregroundColor(SuiColor.midText)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: SuiSpacing.cardGap) {
                    ForEach(recentVisits, id: \.id) { visit in
                        RecentVisitRow(visit: visit, theme: theme)
                    }
                }
            }
        }
    }
}

// MARK: - 最近の訪問 1行

private struct RecentVisitRow: View {
    let visit: VisitRecord
    let theme: Theme

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: visit.visitDate)
    }

    private var emoji: String {
        // 代表魚名に応じて簡易的にアイコン決定
        let name = visit.aquarium?.representativeFish.lowercased() ?? ""
        if name.contains("whale") || name.contains("orca") { return "🐋" }
        if name.contains("penguin") { return "🐧" }
        if name.contains("shark") { return "🦈" }
        if name.contains("jellyfish") { return "🪼" }
        if name.contains("dolphin") { return "🐬" }
        return "🐠"
    }

    var body: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.primaryBg)
                        .frame(width: 50, height: 50)
                    Text(emoji).font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.aquarium?.name ?? "不明な水族館")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SuiColor.heading)
                        .lineLimit(1)
                    Text(dateString)
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.subText)
                }

                Spacer()
                CheckInBadge(type: visit.checkInType)
            }
        }
    }
}

// MARK: - 水槽カード（魚アニメをこの内部に閉じ込める）

private struct TankCardView: View {
    let visits: [VisitRecord]
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [theme.tankTop, theme.tankBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(theme.backgroundImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                TankBubblesView(bubbleColor: theme.bubbleColor)

                if visits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fish")
                            .font(.system(size: 56))
                            .foregroundColor(.white.opacity(0.75))
                        Text("水族館に行って魚を集めよう")
                            .font(SuiFont.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                } else {
                    ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                        TankFish(
                            index: index,
                            total: visits.count,
                            checkInType: visit.checkInType,
                            representativeFish: visit.aquarium?.representativeFish ?? "fish.fill",
                            fishIconSize: visit.aquarium?.fishIconSize ?? 3,
                            theme: theme,
                            containerSize: geo.size
                        )
                    }
                }

                // カード内「海底」装飾
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { i in
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 3, height: CGFloat(12 + (i % 3) * 6))
                                .padding(.horizontal, 2)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: SuiRadius.cardLarge, style: .continuous))
            .suiShadow(.cardEmphasized(primary: theme.primaryColor))
        }
    }
}

// MARK: - カード内で泳ぐ魚

private struct TankFish: View {
    let index: Int
    let total: Int
    let checkInType: CheckInType
    let representativeFish: String
    let fishIconSize: Int
    let theme: Theme
    let containerSize: CGSize

    @State private var startTime: Date = Date()
    @State private var startDelay: Double = Double.random(in: 0...4)
    @State private var cycleDuration: Double = Double.random(in: 10...16)
    @State private var cyclePause: Double = Double.random(in: 0.5...3.0)
    @State private var wobblePhase: Double = Double.random(in: 0...1)

    private var size: CGFloat {
        let base: CGFloat
        switch fishIconSize {
        case 1: base = 24
        case 2: base = 30
        case 3: base = 36
        case 4: base = 44
        case 5: base = 56
        default: base = 36
        }
        return base
    }

    private var fishColor: Color {
        switch checkInType {
        case .location:
            let colors = theme.locationCheckInColors
            return colors.isEmpty ? .yellow : colors[index % colors.count]
        case .manual:
            let colors = theme.manualCheckInColors
            return colors.isEmpty ? .gray : colors[index % colors.count]
        }
    }

    private var isCustomAsset: Bool { !representativeFish.contains(".") }

    private var baseY: CGFloat {
        let laneCount = max(total, 3)
        let laneIndex = index % laneCount
        let laneHeight = containerSize.height / CGFloat(laneCount)
        return laneHeight * (CGFloat(laneIndex) + 0.5)
    }

    private func currentPosition(at date: Date) -> CGPoint {
        let elapsed = date.timeIntervalSince(startTime) - startDelay
        let leftHidden = CGPoint(x: -size * 1.5, y: baseY)
        guard elapsed >= 0, containerSize.width > 0 else { return leftHidden }

        let cycleLength = cycleDuration + cyclePause
        let cyclePos = elapsed.truncatingRemainder(dividingBy: cycleLength)
        guard cyclePos < cycleDuration else { return leftHidden }

        let t = cyclePos / cycleDuration
        let startX: CGFloat = -size * 1.5
        let endX: CGFloat = containerSize.width + size * 1.5
        let x = startX + (endX - startX) * CGFloat(t)
        let wobble = sin((t + wobblePhase) * .pi * 2) * 8
        return CGPoint(x: x, y: baseY + wobble)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let pos = currentPosition(at: context.date)
            Group {
                if isCustomAsset {
                    Image(theme.creatureImageName(representativeFish))
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                } else {
                    Image(systemName: representativeFish)
                        .font(.system(size: size))
                        .foregroundColor(fishColor)
                }
            }
            .position(x: pos.x, y: pos.y)
        }
    }
}

// MARK: - 水槽カード内の泡

private struct TankBubblesView: View {
    let bubbleColor: Color

    @State private var bubbles: [BubbleData] = []
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles) { bubble in
                    TankBubble(
                        data: bubble,
                        containerHeight: geo.size.height,
                        bubbleColor: bubbleColor
                    )
                }
            }
            .onAppear { addBubble(width: geo.size.width) }
            .onReceive(timer) { _ in addBubble(width: geo.size.width) }
        }
    }

    private func addBubble(width: CGFloat) {
        guard width > 0 else { return }
        let bubble = BubbleData(
            id: UUID(),
            startX: CGFloat.random(in: 10...(width - 10)),
            size: CGFloat.random(in: 6...12),
            duration: Double.random(in: 3...5)
        )
        bubbles.append(bubble)
        DispatchQueue.main.asyncAfter(deadline: .now() + bubble.duration) {
            bubbles.removeAll { $0.id == bubble.id }
        }
    }
}

private struct BubbleData: Identifiable {
    let id: UUID
    let startX: CGFloat
    let size: CGFloat
    let duration: Double
}

private struct TankBubble: View {
    let data: BubbleData
    let containerHeight: CGFloat
    let bubbleColor: Color

    @State private var y: CGFloat = 0
    @State private var opacity: Double = 0.7

    var body: some View {
        Circle()
            .fill(bubbleColor.opacity(0.6))
            .overlay(Circle().stroke(bubbleColor.opacity(0.4), lineWidth: 0.5))
            .frame(width: data.size, height: data.size)
            .position(x: data.startX, y: y)
            .opacity(opacity)
            .onAppear {
                y = containerHeight + data.size
                withAnimation(.easeOut(duration: data.duration)) {
                    y = -data.size
                }
                withAnimation(.easeIn(duration: data.duration)) {
                    opacity = 0
                }
            }
    }
}

#Preview {
    MyTankView()
        .modelContainer(for: VisitRecord.self, inMemory: true)
        .environmentObject(ThemeManager())
}
