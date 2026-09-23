//
//  MyTankView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//  Redesigned per design_handoff_suilog spec.
//

import SwiftUI
import SwiftData

struct MyTankView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \VisitRecord.visitDate, order: .reverse) private var visitRecords: [VisitRecord]

    let onSeeAllVisits: () -> Void

    init(
        onSeeAllVisits: @escaping () -> Void = {}
    ) {
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("こんにちは 👋")
                .font(SuiFont.label)
                .foregroundColor(SuiColor.midText)
            Text("マイ水槽")
                .font(SuiFont.screenTitle)
                .foregroundColor(SuiColor.heading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @State private var simulation = TankSimulation()
    @Environment(\.scenePhase) private var scenePhase

    private var specs: [TankCreatureSpec] {
        visits.enumerated().map { index, visit in
            TankCreatureSpec(
                id: visit.id,
                creatureName: visit.aquarium?.representativeFish ?? "fish.fill",
                sizeLevel: visit.aquarium?.fishIconSize ?? 3,
                isLocationCheckIn: visit.checkInType == .location,
                colorIndex: index
            )
        }
    }

    var body: some View {
        let specs = self.specs
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

                if visits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fish")
                            .font(.system(size: 56))
                            .foregroundColor(.white.opacity(0.75))
                        Text("水族館に行って魚を集めよう")
                            .font(SuiFont.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                TimelineView(.animation(minimumInterval: nil, paused: scenePhase != .active)) { context in
                    let _ = simulation.update(specs: specs, date: context.date, size: geo.size)
                    let time = simulation.time
                    let creatures = simulation.creatures
                    let bubbles = simulation.bubbles

                    ZStack {
                        // 水面から差し込む光
                        Rectangle()
                            .colorEffect(ShaderLibrary.tankLight(
                                .boundingRect,
                                .float(time.truncatingRemainder(dividingBy: 3600)),
                                .float(0.55)
                            ))
                            .blendMode(.plusLighter)

                        // 奥の浮遊物（マリンスノー）
                        marineSnow(time: time, count: 28, near: false)

                        ForEach(creatures) { creature in
                            if creature.isActive {
                                TankCreatureView(creature: creature, theme: theme)
                            }
                        }

                        bubbleLayer(bubbles)

                        // 手前の浮遊物
                        marineSnow(time: time, count: 10, near: true)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)

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

    // MARK: 泡

    private func bubbleLayer(_ bubbles: [TankBubbleParticle]) -> some View {
        let color = theme.bubbleColor
        return Canvas { ctx, _ in
            for bubble in bubbles {
                let rect = CGRect(
                    x: bubble.x - bubble.size / 2,
                    y: bubble.y - bubble.size / 2,
                    width: bubble.size,
                    height: bubble.size
                )
                // 水面付近で消えていく
                let alpha = min(1, max(0, bubble.y / 30))
                ctx.opacity = alpha
                let circle = Path(ellipseIn: rect)
                ctx.fill(circle, with: .color(color.opacity(0.22)))
                ctx.stroke(circle, with: .color(color.opacity(0.7)), lineWidth: 0.8)
                // ハイライト
                let highlight = CGRect(
                    x: rect.minX + bubble.size * 0.22,
                    y: rect.minY + bubble.size * 0.18,
                    width: bubble.size * 0.3,
                    height: bubble.size * 0.3
                )
                ctx.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.75)))
            }
        }
    }

    // MARK: マリンスノー

    /// 時刻から位置が決まる浮遊物（状態を持たない）
    private func marineSnow(time: Double, count: Int, near: Bool) -> some View {
        Canvas { ctx, size in
            let seedOffset = near ? 1000.0 : 0.0
            for i in 0..<count {
                let n = Double(i) + seedOffset
                let r1 = Self.hash(n * 3 + 1)
                let r2 = Self.hash(n * 3 + 2)
                let r3 = Self.hash(n * 3 + 3)
                let speed = (near ? 7.0 : 3.0) + r2 * (near ? 8.0 : 5.0)
                let span = Double(size.height) + 20
                let y = (r1 * span + time * speed).truncatingRemainder(dividingBy: span) - 10
                let x = r3 * Double(size.width) + sin(time * 0.3 + r1 * 6.283) * (near ? 12 : 6)
                let radius = near ? 1.2 + r2 * 1.4 : 0.5 + r2 * 0.9
                // ゆっくり明滅させる
                let twinkle = 0.6 + 0.4 * sin(time * (0.5 + r3) + r2 * 6.283)
                ctx.opacity = (near ? 0.35 : 0.45) * twinkle
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .blur(radius: near ? 0.8 : 0)
    }

    nonisolated private static func hash(_ n: Double) -> Double {
        let v = sin(n * 12.9898) * 43758.5453
        return v - v.rounded(.down)
    }
}

// MARK: - カード内で泳ぐ生き物

private struct TankCreatureView: View {
    let creature: TankCreature
    let theme: Theme

    private var fishColor: Color {
        let colors = creature.spec.isLocationCheckIn ? theme.locationCheckInColors : theme.manualCheckInColors
        guard !colors.isEmpty else { return creature.spec.isLocationCheckIn ? .yellow : .gray }
        return colors[creature.spec.colorIndex % colors.count]
    }

    var body: some View {
        let size = creature.renderSize
        let undulation = creature.undulationAmount
        let sweep = creature.tailSweepAmount
        let scale = creature.renderScale
        let tint = creature.tint

        creatureImage(size: size)
            .frame(width: size, height: size)
            // 体のうねり（尾から頭へ伝わる波）
            .distortionEffect(
                ShaderLibrary.creatureSwim(
                    .boundingRect,
                    .float(creature.tailPhase),
                    .float(undulation),
                    .float(sweep),
                    .float(creature.profile.wavelength)
                ),
                maxSampleOffset: CGSize(width: size * sweep + 1, height: size * undulation + 1),
                isEnabled: undulation > 0 || sweep > 0
            )
            .scaleEffect(x: scale.x, y: scale.y)
            // 進行方向への傾き
            .rotationEffect(.radians(creature.renderRotation))
            // 反転は体をひねるように Y 軸回転させる
            .rotation3DEffect(.radians(creature.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            // 奥行き：奥ほど青く、淡く、ぼやける
            .saturation(creature.saturation)
            .colorMultiply(Color(red: tint.red, green: tint.green, blue: tint.blue))
            .blur(radius: creature.blurRadius)
            .opacity(creature.opacity)
            .position(x: creature.x, y: creature.y + creature.renderOffsetY)
    }

    @ViewBuilder
    private func creatureImage(size: Double) -> some View {
        if creature.spec.isCustomAsset {
            Image(theme.creatureImageName(creature.spec.creatureName))
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: creature.spec.creatureName)
                .font(.system(size: size))
                .foregroundColor(fishColor)
        }
    }
}

#Preview {
    MyTankView()
        .modelContainer(for: VisitRecord.self, inMemory: true)
        .environmentObject(ThemeManager())
}
