//
//  ProStoreView.swift
//  Suilog
//
//  スイログ Pro（買い切り）の購入画面。
//

import SwiftUI
import StoreKit

struct ProStoreView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingPurchaseSuccess = false

    private var theme: Theme { themeManager.currentTheme }

    private var proProduct: Product? {
        storeManager.product(for: StoreManager.proProductId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        benefitsCard
                        purchaseSection
                        restoreButton
                        noteText
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("スイログ Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.primaryColor)
                }
            }
            .alert("ありがとうございます！", isPresented: $showingPurchaseSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("スイログ Pro をご購入いただきました。\nこれからも水族館めぐりを楽しんでください🐠")
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
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundColor(SuiColor.star)
            }
            Text("スイログ Pro")
                .font(SuiFont.screenTitle)
                .foregroundColor(SuiColor.heading)
            Text("一度の購入で、すべてのPro機能がずっと使えます")
                .font(SuiFont.body)
                .foregroundColor(SuiColor.midText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefitsCard: some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                benefitRow(
                    icon: "photo.stack.fill",
                    title: "写真を無制限に保存",
                    caption: "1つの記録に保存できる写真が\(VisitRecord.maxPhotoCount)枚 → 無制限に"
                )
                benefitRow(
                    icon: "sparkles",
                    title: "今後のPro機能をすべて利用",
                    caption: "ウィジェットや図鑑の上級機能など、今後追加されるPro機能も追加料金なし"
                )
                benefitRow(
                    icon: "heart.fill",
                    title: "開発を応援",
                    caption: "個人開発のスイログを支え、新機能の開発を後押しします"
                )
            }
        }
    }

    private func benefitRow(icon: String, title: String, caption: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.primaryColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SuiFont.bodyMedium)
                    .foregroundColor(SuiColor.heading)
                Text(caption)
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.midText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if storeManager.isProUnlocked {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Pro 利用中 - ありがとうございます！")
                    .font(SuiFont.bodyMedium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                    .fill(Color.green)
            )
        } else if let product = proProduct {
            Button {
                Task {
                    if await storeManager.purchase(product) {
                        showingPurchaseSuccess = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if storeManager.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                    }
                    Text("\(product.displayPrice) で購入する")
                        .font(SuiFont.bodyMedium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                        .fill(theme.primaryColor)
                )
            }
            .disabled(storeManager.isPurchasing)
            .suiShadow(.primaryButton(primary: theme.primaryColor))
            .accessibilityIdentifier("pro.purchaseButton")
        } else if storeManager.isLoading {
            ProgressView("読み込み中...")
                .padding(.vertical, 16)
        } else {
            Text("商品情報を取得できませんでした。\n時間をおいて再度お試しください。")
                .font(SuiFont.label)
                .foregroundColor(SuiColor.subText)
                .multilineTextAlignment(.center)
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await storeManager.restorePurchases() }
        } label: {
            Text("購入を復元する")
                .font(SuiFont.label)
                .foregroundColor(theme.primaryColor)
        }
        .disabled(storeManager.isLoading)
    }

    private var noteText: some View {
        Text("※ 買い切り型のため、追加料金や自動更新はありません。同じApple IDのデバイス間で共有されます。")
            .font(SuiFont.caption)
            .foregroundColor(SuiColor.subText)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    ProStoreView()
        .environmentObject(ThemeManager())
        .environmentObject(StoreManager())
}
