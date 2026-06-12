//
//  TipJarView.swift
//  Suilog
//
//  開発者への応援課金（Tip Jar）画面。消耗型のチップを購入できる。
//

import SwiftUI
import StoreKit

struct TipJarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingThanks = false

    private var theme: Theme { themeManager.currentTheme }

    /// チップ商品を価格の安い順で返す
    private var tipProducts: [Product] {
        storeManager.products
            .filter { StoreManager.tipProductIds.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    /// 価格帯に応じた魚の絵文字
    private func emoji(for index: Int) -> String {
        switch index {
        case 0: return "🐟"
        case 1: return "🐠"
        default: return "🐋"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header

                        if tipProducts.isEmpty {
                            if storeManager.isLoading {
                                ProgressView("読み込み中...")
                                    .padding(.vertical, 20)
                            } else {
                                Text("商品情報を取得できませんでした。\n時間をおいて再度お試しください。")
                                    .font(SuiFont.label)
                                    .foregroundColor(SuiColor.subText)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            VStack(spacing: SuiSpacing.cardGap) {
                                ForEach(Array(tipProducts.enumerated()), id: \.element.id) { index, product in
                                    tipRow(product: product, emoji: emoji(for: index))
                                }
                            }
                        }

                        if storeManager.tipCount > 0 {
                            Text("これまでの応援: \(storeManager.tipCount)回\nいつもありがとうございます！")
                                .font(SuiFont.label)
                                .foregroundColor(SuiColor.midText)
                                .multilineTextAlignment(.center)
                        }

                        Text("※ 応援は任意です。機能の違いはありません。")
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("開発者を応援")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.primaryColor)
                }
            }
            .alert("ありがとうございます！🐟", isPresented: $showingThanks) {
                Button("OK") { }
            } message: {
                Text("応援が開発の大きな励みになります。\nこれからもスイログをよろしくお願いします！")
            }
            .alert("エラー", isPresented: .init(
                get: { storeManager.errorMessage != nil },
                set: { if !$0 { storeManager.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(storeManager.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.primaryLight.opacity(0.45))
                    .frame(width: 100, height: 100)
                Text("🐡")
                    .font(.system(size: 50))
            }
            Text("開発者を応援する")
                .font(SuiFont.screenTitle)
                .foregroundColor(SuiColor.heading)
            Text("スイログは個人で開発しています。\n気に入っていただけたら、エサやりで応援してください！")
                .font(SuiFont.body)
                .foregroundColor(SuiColor.midText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func tipRow(product: Product, emoji: String) -> some View {
        Button {
            Task {
                if await storeManager.purchaseTip(product) {
                    showingThanks = true
                }
            }
        } label: {
            SuiCard(radius: SuiRadius.cardMedium, padding: 16) {
                HStack(spacing: 14) {
                    Text(emoji)
                        .font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayName)
                            .font(SuiFont.bodyMedium)
                            .foregroundColor(SuiColor.heading)
                        Text(product.description)
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                    }
                    Spacer()
                    Text(product.displayPrice)
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(theme.primaryColor))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isPurchasing)
    }
}

#Preview {
    TipJarView()
        .environmentObject(ThemeManager())
        .environmentObject(StoreManager())
}
