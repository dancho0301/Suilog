//
//  MyTankView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import Combine

struct MyTankView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query private var visitRecords: [VisitRecord]

    var visitedAquariumsCount: Int {
        Set(visitRecords.compactMap { $0.aquarium?.id }).count
    }

    var locationCheckInCount: Int {
        visitRecords.filter { $0.checkInType == .location }.count
    }

    var manualCheckInCount: Int {
        visitRecords.filter { $0.checkInType == .manual }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景画像（テーマから取得）
                Image(themeManager.currentTheme.backgroundImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                // 泡のアニメーション（テーマの色を使用）
                BubblesView(bubbleColor: themeManager.currentTheme.bubbleColor)

            if visitedAquariumsCount == 0 {
                // 訪問がない場合のメッセージ
                VStack(spacing: 20) {
                    Image(systemName: "fish")
                        .font(.system(size: 80))
                        .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.3))

                    Text("水族館に行って魚を見つけよう！")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
            } else {
                // 訪問記録ごとに魚を表示（チェックイン種別で色分け）
                // 魚の高さを分散させて重なりを減らす
                ForEach(Array(visitRecords.enumerated()), id: \.element.id) { index, visit in
                    FloatingFish(
                        index: index,
                        checkInType: visit.checkInType,
                        representativeFish: visit.aquarium?.representativeFish ?? "fish.fill",
                        fishIconSize: visit.aquarium?.fishIconSize ?? 3,
                        totalCount: visitRecords.count,
                        locationColors: themeManager.currentTheme.locationCheckInColors,
                        manualColors: themeManager.currentTheme.manualCheckInColors,
                        theme: themeManager.currentTheme
                    )
                }

                // 統計情報
                VStack {
                    Spacer()

                    NavigationLink(destination: StatisticsView()) {
                        VStack(spacing: 12) {
                            Text("訪問した水族館")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor)

                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(visitedAquariumsCount)")
                                    .font(.system(size: 60, weight: .bold))
                                Text("か所")
                                    .font(.title3)
                            }
                            .foregroundColor(themeManager.currentTheme.textColor)

                            Divider()
                                .background(themeManager.currentTheme.textColor.opacity(0.5))
                                .padding(.vertical, 4)

                            HStack(spacing: 20) {
                                VStack {
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .foregroundColor(themeManager.currentTheme.locationCheckInColors.first ?? .yellow)
                                        Text("\(locationCheckInCount)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    Text("位置情報")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                                }

                                VStack {
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .foregroundColor(themeManager.currentTheme.manualCheckInColors.first ?? .gray)
                                        Text("\(manualCheckInCount)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    Text("手動")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                                }
                            }
                            .foregroundColor(themeManager.currentTheme.textColor)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeManager.currentTheme.statisticsBackgroundColor)
                                .shadow(radius: 10)
                        )
                    }
                    .padding(.bottom, 40)
                }
            }
            }
        }
    }
}

// 魚の動きの種類
enum FishMovementType {
    case horizontal      // 左から右へ水平移動（デフォルト）
    case floatUp         // 下から上へゆっくり浮上（クラゲ用）
}

struct FloatingFish: View {
    let index: Int
    let checkInType: CheckInType
    let representativeFish: String
    let fishIconSize: Int  // 1-5のサイズ指定
    let totalCount: Int
    let locationColors: [Color]
    let manualColors: [Color]
    let theme: Theme  // テーマ

    @State private var offset: CGSize = .zero
    @State private var wobble: CGFloat = 0  // 左右の揺れ（クラゲ用）
    @State private var calculatedFishSize: CGFloat?

    // 魚の種類に応じた動きを決定
    private var movementType: FishMovementType {
        switch representativeFish {
        case "Jellyfish":
            return .floatUp
        default:
            return .horizontal
        }
    }

    var body: some View {
        let size = calculatedFishSize ?? calculateFishSize()
        Group {
            if isCustomAsset(representativeFish) {
                // カスタムアセット（テーマフォルダから取得）
                Image(theme.creatureImageName(representativeFish))
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                // SF Symbols
                Image(systemName: representativeFish)
                    .font(.system(size: size))
                    .foregroundColor(fishColor)
            }
        }
        .offset(x: offset.width + wobble, y: offset.height)
        .onAppear {
            if calculatedFishSize == nil {
                calculatedFishSize = calculateFishSize()
            }
            startAnimation()
        }
    }

    /// SF Symbolsかカスタムアセットかを判定
    /// SF Symbolsは必ず "." を含む（例: fish.fill, seal.fill）
    /// カスタムアセットは "." を含まない（例: orca, Dolphin, freshwaterfish）
    private func isCustomAsset(_ name: String) -> Bool {
        return !name.contains(".")
    }

    private func calculateFishSize() -> CGFloat {
        // デバイスタイプを判定
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        // fishIconSize (1-5) に基づいてサイズを決定
        // iPhone: 2倍サイズ
        // iPad: さらに1.5倍（合計3倍）
        let baseSize: CGFloat
        let variation: CGFloat

        if isIPad {
            // iPad用のサイズ（iPhoneの1.5倍）
            // サイズ1: 90-150pt
            // サイズ2: 120-180pt
            // サイズ3: 150-210pt (デフォルト)
            // サイズ4: 180-240pt
            // サイズ5: 240-360pt (シャチなど大型生物)
            switch fishIconSize {
            case 1:
                baseSize = 90
                variation = 60
            case 2:
                baseSize = 120
                variation = 60
            case 3:
                baseSize = 150
                variation = 60
            case 4:
                baseSize = 180
                variation = 60
            case 5:
                baseSize = 240
                variation = 120
            default:
                baseSize = 150
                variation = 60
            }
        } else {
            // iPhone用のサイズ（元の2倍）
            // サイズ1: 60-100pt
            // サイズ2: 80-120pt
            // サイズ3: 100-140pt (デフォルト)
            // サイズ4: 120-160pt
            // サイズ5: 160-240pt (シャチなど大型生物)
            switch fishIconSize {
            case 1:
                baseSize = 60
                variation = 40
            case 2:
                baseSize = 80
                variation = 40
            case 3:
                baseSize = 100
                variation = 40
            case 4:
                baseSize = 120
                variation = 40
            case 5:
                baseSize = 160
                variation = 80
            default:
                baseSize = 100
                variation = 40
            }
        }

        return CGFloat.random(in: baseSize...(baseSize + variation))
    }

    private var fishColor: Color {
        // チェックイン種別で基本色を決定（テーマから取得）
        switch checkInType {
        case .location:
            // 位置情報チェックインはテーマのlocationColors
            guard !locationColors.isEmpty else { return .yellow }
            return locationColors[index % locationColors.count]
        case .manual:
            // 手動チェックインはテーマのmanualColors
            guard !manualColors.isEmpty else { return .gray }
            return manualColors[index % manualColors.count]
        }
    }

    private func startAnimation() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        switch movementType {
        case .horizontal:
            startHorizontalAnimation(screenWidth: screenWidth, screenHeight: screenHeight)
        case .floatUp:
            startFloatUpAnimation(screenWidth: screenWidth, screenHeight: screenHeight)
        }
    }

    // MARK: - 水平移動アニメーション（デフォルト）
    private func startHorizontalAnimation(screenWidth: CGFloat, screenHeight: CGFloat) {
        let size = calculatedFishSize ?? calculateFishSize()
        // 魚が泳ぐ範囲（デバイスによって調整）
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        // iPhone: 5%〜60%、iPad: 5%〜70%
        let topLimit = -screenHeight * 0.45
        let bottomLimit = isIPad ? screenHeight * 0.30 : screenHeight * 0.20  // 範囲を広げて消えないように

        // indexに基づいて高さを分散（レーン分け）
        let assignedHeight = calculateAssignedHeight(topLimit: topLimit, bottomLimit: bottomLimit)

        // 開始位置をずらす（重なり防止）
        let startOffset = CGFloat(index % 5) * (screenWidth / 5)

        offset = CGSize(
            width: -screenWidth/2 - size - startOffset,
            height: assignedHeight
        )

        // 左から右にふわふわ流れるアニメーション
        swimLeftToRight(screenWidth: screenWidth, screenHeight: screenHeight)
    }

    // indexに基づいて高さを計算（レーン分け）
    private func calculateAssignedHeight(topLimit: CGFloat, bottomLimit: CGFloat) -> CGFloat {
        let range = bottomLimit - topLimit
        let laneCount = max(totalCount, 5) // 最低5レーン
        let laneHeight = range / CGFloat(laneCount)

        // indexに基づいてレーンを割り当て、少しランダム性を加える
        let laneIndex = index % laneCount
        let baseHeight = topLimit + (CGFloat(laneIndex) + 0.5) * laneHeight
        let randomOffset = CGFloat.random(in: -laneHeight * 0.3...laneHeight * 0.3)

        return baseHeight + randomOffset
    }

    private func swimLeftToRight(screenWidth: CGFloat, screenHeight: CGFloat) {
        let size = calculatedFishSize ?? calculateFishSize()
        // 魚が泳ぐ範囲（デバイスによって調整）
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        // iPhone: 5%〜60%、iPad: 5%〜70%
        let topLimit = -screenHeight * 0.45
        let bottomLimit = isIPad ? screenHeight * 0.30 : screenHeight * 0.20  // 範囲を広げて消えないように

        // 画面の右端を超えたら左端に戻る
        let currentX = offset.width

        // indexに基づいた割り当て高さ
        let assignedHeight = calculateAssignedHeight(topLimit: topLimit, bottomLimit: bottomLimit)

        // 右端に到達したかチェック（より余裕を持たせる）
        if currentX > screenWidth/2 + size * 2 {
            // 左端にリセット（割り当てられた高さ付近に戻る）
            offset = CGSize(
                width: -screenWidth/2 - size,
                height: assignedHeight
            )
        }

        // 次の位置を決定（右方向に進む、上下にゆっくり波打つ）
        let speed = CGFloat.random(in: 20...40) // ゆっくりした速度
        let nextX = offset.width + screenWidth / 2 // 画面の1/2ずつ進む（より大きな移動）

        // 上下の動き幅（割り当てレーン内で動く）
        let laneHeight = (bottomLimit - topLimit) / CGFloat(max(totalCount, 5))
        let verticalRange = laneHeight * 0.4 // レーン高さの40%まで上下
        let nextY = offset.height + CGFloat.random(in: -verticalRange...verticalRange)

        // 割り当てレーン付近に収める
        let laneTop = assignedHeight - laneHeight * 0.5
        let laneBottom = assignedHeight + laneHeight * 0.5
        let clampedY = max(laneTop, min(laneBottom, nextY))

        // アニメーション時間（ゆっくり進む）
        let duration: Double = Double((nextX - offset.width) / speed)

        // linear（一定速度）で停止せず連続的に動く
        withAnimation(.linear(duration: duration)) {
            offset = CGSize(width: nextX, height: clampedY)
        }

        // アニメーション完了直前に次の動きを開始（途切れない）
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.95) {
            swimLeftToRight(screenWidth: screenWidth, screenHeight: screenHeight)
        }
    }

    // MARK: - クラゲ用浮上アニメーション
    private func startFloatUpAnimation(screenWidth: CGFloat, screenHeight: CGFloat) {
        let size = calculatedFishSize ?? calculateFishSize()
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let bottomLimit = isIPad ? screenHeight * 0.30 : screenHeight * 0.20  // 範囲を広げて消えないように

        // 画面下部のランダムな位置から開始
        offset = CGSize(
            width: CGFloat.random(in: -screenWidth * 0.3...screenWidth * 0.3),
            height: bottomLimit + size
        )

        // 左右の揺れを開始
        startWobbleAnimation()

        // 上に浮上するアニメーション
        floatUp(screenWidth: screenWidth, screenHeight: screenHeight)
    }

    private func startWobbleAnimation() {
        // ゆったりとした左右の揺れ
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            wobble = CGFloat.random(in: 20...40) * (Bool.random() ? 1 : -1)
        }
    }

    private func floatUp(screenWidth: CGFloat, screenHeight: CGFloat) {
        let size = calculatedFishSize ?? calculateFishSize()
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let topLimit = -screenHeight * 0.45
        let bottomLimit = isIPad ? screenHeight * 0.30 : screenHeight * 0.20  // 範囲を広げて消えないように

        // 上端に到達したら下端にリセット（より余裕を持たせる）
        if offset.height < topLimit - size {
            offset = CGSize(
                width: CGFloat.random(in: -screenWidth * 0.3...screenWidth * 0.3),
                height: bottomLimit + size
            )
        }

        // ゆっくり上に移動
        let speed = CGFloat.random(in: 8...15) // クラゲはとてもゆっくり
        let nextY = offset.height - screenHeight * 0.15 // 少しずつ上に

        // アニメーション時間
        let duration: Double = Double(abs(nextY - offset.height) / speed)

        withAnimation(.easeInOut(duration: duration)) {
            offset = CGSize(width: offset.width, height: nextY)
        }

        // 次の動きを開始
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.95) {
            floatUp(screenWidth: screenWidth, screenHeight: screenHeight)
        }
    }
}

// MARK: - Bubbles View
struct BubblesView: View {
    let bubbleColor: Color

    @State private var bubbles: [BubbleData] = []
    private let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    init(bubbleColor: Color = .white) {
        self.bubbleColor = bubbleColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bubbles) { bubble in
                    Bubble(
                        startX: bubble.startX,
                        size: bubble.size,
                        duration: bubble.duration,
                        screenHeight: geometry.size.height,
                        bubbleColor: bubbleColor
                    )
                }
            }
            .onAppear {
                // 初期泡を追加
                addBubble()
                addBubble()
            }
        }
        .onReceive(timer) { _ in
            addBubble()
        }
    }

    private func addBubble() {
        let screenWidth = UIScreen.main.bounds.width

        // ランダムに泡を生成（確率70%）
        if Double.random(in: 0...1) < 0.7 {
            let newBubble = BubbleData(
                id: UUID(),
                startX: CGFloat.random(in: 20...(screenWidth - 20)),
                size: CGFloat.random(in: 8...16),
                duration: Double.random(in: 4...7)
            )
            bubbles.append(newBubble)

            // 泡が画面外に消えたら削除
            DispatchQueue.main.asyncAfter(deadline: .now() + newBubble.duration) {
                bubbles.removeAll { $0.id == newBubble.id }
            }
        }
    }
}

struct BubbleData: Identifiable {
    let id: UUID
    let startX: CGFloat
    let size: CGFloat
    let duration: Double
}

struct Bubble: View {
    let startX: CGFloat
    let size: CGFloat
    let duration: Double
    let screenHeight: CGFloat
    let bubbleColor: Color

    @State private var yPosition: CGFloat = 0
    @State private var opacity: Double = 0.7

    init(startX: CGFloat, size: CGFloat, duration: Double, screenHeight: CGFloat, bubbleColor: Color = .white) {
        self.startX = startX
        self.size = size
        self.duration = duration
        self.screenHeight = screenHeight
        self.bubbleColor = bubbleColor
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        bubbleColor.opacity(0.9),
                        bubbleColor.opacity(0.5),
                        bubbleColor.opacity(0.2)
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(bubbleColor.opacity(0.4), lineWidth: 0.5)
            )
            .position(x: startX, y: yPosition)
            .opacity(opacity)
            .onAppear {
                // 初期位置は画面下部
                yPosition = screenHeight + size

                // ゆっくり上に浮かび上がるアニメーション
                withAnimation(.easeOut(duration: duration)) {
                    yPosition = -size
                }

                // 上に行くほど徐々に透明に
                withAnimation(.easeIn(duration: duration)) {
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
