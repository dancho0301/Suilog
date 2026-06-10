//
//  VisitShareSheet.swift
//  Suilog
//
//  訪問記録のシェアカード画像を生成してSNS等に共有するシート。
//

import SwiftUI

/// 訪問記録のシェアシート（カードのプレビュー＋共有ボタン）
struct VisitShareSheet: View {
    let visit: VisitRecord
    let aquarium: Aquarium
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
                                "\(aquarium.name)の訪問記録",
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
            .navigationTitle("記録をシェア")
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
            content: VisitShareCard(visit: visit, aquarium: aquarium, theme: theme)
        )
        renderer.scale = 3
        renderedImage = renderer.uiImage
    }
}

// MARK: - シェアカード（画像レンダリング用レイアウト）

private struct VisitShareCard: View {
    let visit: VisitRecord
    let aquarium: Aquarium
    let theme: Theme

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: visit.visitDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let data = visit.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 318, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(aquarium.name)
                        .font(SuiFont.heading)
                        .foregroundColor(SuiColor.heading)
                    Text("\(dateString) 訪問")
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.subText)
                }
                Spacer()
                CheckInBadge(type: visit.checkInType)
            }

            if !visit.memo.isEmpty {
                Text(visit.memo)
                    .font(SuiFont.body)
                    .foregroundColor(SuiColor.midText)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
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
}
