//
//  ProfileShareSheet.swift
//  Suilog
//
//  実績（ランク・訪問数・獲得バッジ）のシェアカード画像を生成して共有するシート。
//

import SwiftUI

struct ProfileShareSheet: View {
    let nickname: String
    let rankTitle: String
    let visitedCount: Int
    let totalAquariumCount: Int
    let goldCount: Int
    let silverCount: Int
    let earnedBadges: [Badge]
    let theme: Theme

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                VStack(spacing: 20) {
                    if let renderedImage {
                        Spacer()

                        Image(uiImage: renderedImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: SuiRadius.cardLarge, style: .continuous))
                            .suiShadow(.card)

                        Spacer()

                        ShareLink(
                            item: Image(uiImage: renderedImage),
                            preview: SharePreview(
                                "\(nickname)のスイログ実績",
                                image: Image(uiImage: renderedImage)
                            )
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("シェアする")
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
                        .suiShadow(.primaryButton(primary: theme.primaryColor))
                    } else {
                        ProgressView()
                    }
                }
                .padding(.horizontal, SuiSpacing.screenHorizontal)
                .padding(.vertical, 20)
            }
            .navigationTitle("実績をシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.primaryColor)
                }
            }
            .task {
                renderCard()
            }
        }
    }

    /// シェアカードを画像にレンダリングする
    @MainActor
    private func renderCard() {
        let renderer = ImageRenderer(
            content: ProfileShareCard(
                nickname: nickname,
                rankTitle: rankTitle,
                visitedCount: visitedCount,
                totalAquariumCount: totalAquariumCount,
                goldCount: goldCount,
                silverCount: silverCount,
                earnedBadges: earnedBadges,
                theme: theme
            )
        )
        renderer.scale = 3
        renderedImage = renderer.uiImage
    }
}

// MARK: - シェアカード（画像レンダリング用レイアウト）

private struct ProfileShareCard: View {
    let nickname: String
    let rankTitle: String
    let visitedCount: Int
    let totalAquariumCount: Int
    let goldCount: Int
    let silverCount: Int
    let earnedBadges: [Badge]
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ヘッダー（名前とランク）
            VStack(alignment: .leading, spacing: 6) {
                Text(nickname)
                    .font(SuiFont.heading)
                    .foregroundColor(.white)
                Text(rankTitle)
                    .font(SuiFont.label)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.25)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                LinearGradient(
                    colors: [theme.primaryColor, theme.primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // 統計
            HStack(spacing: 0) {
                statItem(value: "\(visitedCount) / \(totalAquariumCount)", label: "訪問館数")
                statItem(value: "🥇 \(goldCount)", label: "ゴールド")
                statItem(value: "🥈 \(silverCount)", label: "シルバー")
            }

            // 獲得バッジ
            if !earnedBadges.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("獲得バッジ（\(earnedBadges.count)個）")
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.subText)
                    let columns = [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(earnedBadges.prefix(8)) { badge in
                            VStack(spacing: 2) {
                                Text(badge.icon)
                                    .font(.system(size: 24))
                                Text(badge.title)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(SuiColor.heading)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.primaryBg)
                )
            }

            HStack(spacing: 4) {
                Text("🐠")
                    .font(.system(size: 14))
                Text("スイログ - 水族館めぐりの記録")
                    .font(SuiFont.caption)
                    .foregroundColor(SuiColor.subText)
            }
        }
        .padding(16)
        .frame(width: 350)
        .background(Color.white)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SuiFont.bodyMedium)
                .foregroundColor(SuiColor.heading)
            Text(label)
                .font(SuiFont.caption)
                .foregroundColor(SuiColor.subText)
        }
        .frame(maxWidth: .infinity)
    }
}
