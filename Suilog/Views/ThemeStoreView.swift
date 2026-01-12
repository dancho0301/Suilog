//
//  ThemeStoreView.swift
//  Suilog
//
//  Created by dancho on 2025/01/07.
//

import SwiftUI
import StoreKit

struct ThemeStoreView: View {
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedThemeForPreview: Theme?
    @State private var showingPurchaseError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 現在のテーマ
                    currentThemeSection

                    // テーマ一覧
                    themesGrid

                    // TODO: テーマ購入機能を実装したら以下を有効化する
                    // // 全テーマパック
                    // allThemesPackSection

                    // // 購入復元ボタン
                    // restorePurchasesButton
                }
                .padding()
            }
            .navigationTitle("テーマストア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedThemeForPreview) { theme in
                ThemePreviewView(theme: theme)
                    .environmentObject(storeManager)
                    .environmentObject(themeManager)
                    .presentationDetents([.large])
            }
            .alert("エラー", isPresented: $showingPurchaseError) {
                Button("OK") { }
            } message: {
                Text(storeManager.errorMessage ?? "購入に失敗しました")
            }
            .onChange(of: storeManager.errorMessage) { _, newValue in
                if newValue != nil {
                    showingPurchaseError = true
                }
            }
        }
    }

    // MARK: - Current Theme Section

    private var currentThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在のテーマ")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Image(themeManager.currentTheme.backgroundImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(themeManager.currentTheme.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(themeManager.currentTheme.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("使用中")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Themes Grid

    private var themesGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("テーマ")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(themeManager.availableThemes) { theme in
                    ThemeCard(theme: theme)
                        .onTapGesture {
                            selectedThemeForPreview = theme
                        }
                }
            }
        }
    }

    // MARK: - All Themes Pack

    private var allThemesPackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お得なセット")
                .font(.headline)
                .foregroundColor(.secondary)

            if let allPackProduct = storeManager.product(for: "com.suilog.theme.all_pack") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("全テーマパック")
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("すべてのテーマが含まれています")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if storeManager.isPurchased("com.suilog.theme.all_pack") {
                            Text("購入済み")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        } else {
                            Button {
                                Task {
                                    _ = await storeManager.purchase(allPackProduct)
                                }
                            } label: {
                                Text(allPackProduct.displayPrice)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                            .disabled(storeManager.isPurchasing)
                        }
                    }

                    // テーマプレビュー
                    HStack(spacing: 8) {
                        ForEach(themeManager.availableThemes.filter { !$0.isDefault }) { theme in
                            Image(theme.backgroundImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
            }
        }
    }

    // MARK: - Restore Purchases Button

    private var restorePurchasesButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("購入を復元")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .disabled(storeManager.isLoading)
        .padding(.top, 8)
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: Theme
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager

    private var isPurchased: Bool {
        themeManager.isUnlocked(theme)
    }

    private var isSelected: Bool {
        themeManager.currentTheme.id == theme.id
    }

    var body: some View {
        VStack(spacing: 8) {
            // プレビュー画像
            ZStack(alignment: .topTrailing) {
                Image(theme.backgroundImageName)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // 選択中バッジ
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                        .background(Circle().fill(.white))
                        .padding(8)
                }
            }

            // テーマ名
            Text(theme.name)
                .font(.subheadline)
                .fontWeight(.medium)

            // ステータス
            Group {
                if isPurchased {
                    if isSelected {
                        Text("使用中")
                            .foregroundColor(.green)
                    } else {
                        Text("選択可能")
                            .foregroundColor(.blue)
                    }
                } else {
                    if let product = storeManager.product(for: theme.productId ?? "") {
                        Text(product.displayPrice)
                            .foregroundColor(.orange)
                    } else if theme.isDefault {
                        Text("無料")
                            .foregroundColor(.green)
                    } else {
                        Text("読み込み中...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption)
            .fontWeight(.medium)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Theme Preview View

struct ThemePreviewView: View {
    let theme: Theme
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingPurchaseError = false

    private var isPurchased: Bool {
        themeManager.isUnlocked(theme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 背景プレビュー
                    Image(theme.backgroundImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 400)
                        .clipped()

                    // テーマ情報とボタン
                    VStack(spacing: 16) {
                        Text(theme.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(theme.description)
                            .font(.body)
                            .foregroundColor(.secondary)

                        // 色サンプル
                        HStack(spacing: 12) {
                            VStack {
                                Text("位置情報")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(0..<min(theme.locationCheckInColors.count, 3), id: \.self) { index in
                                        Circle()
                                            .fill(theme.locationCheckInColors[index])
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }

                            Divider()
                                .frame(height: 40)

                            VStack {
                                Text("手動")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(0..<min(theme.manualCheckInColors.count, 3), id: \.self) { index in
                                        Circle()
                                            .fill(theme.manualCheckInColors[index])
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                        }

                        // アクションボタン
                        if themeManager.currentTheme.id == theme.id {
                            // 現在使用中のテーマ
                            Text("このテーマを使用中")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if isPurchased {
                            // 購入済み（または無料）で未使用のテーマ
                            Button {
                                themeManager.selectTheme(theme)
                                dismiss()
                            } label: {
                                Text("このテーマを使用する")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else if let productId = theme.productId,
                                  !productId.isEmpty,
                                  let product = storeManager.product(for: productId) {
                            // 未購入で購入可能なテーマ
                            Button {
                                Task {
                                    let success = await storeManager.purchase(product)
                                    if success {
                                        // 購入成功後にテーマを適用
                                        await MainActor.run {
                                            themeManager.updatePurchasedProducts(storeManager.purchasedProductIds)
                                            themeManager.selectTheme(theme)
                                            dismiss()
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if storeManager.isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("\(product.displayPrice) で購入")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(storeManager.isPurchasing)
                        } else {
                            // 商品情報読み込み中または無料テーマの場合の代替表示
                            HStack {
                                ProgressView()
                                Text("読み込み中...")
                            }
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .alert("エラー", isPresented: $showingPurchaseError) {
                Button("OK") { }
            } message: {
                Text(storeManager.errorMessage ?? "購入に失敗しました")
            }
            .onChange(of: storeManager.errorMessage) { _, newValue in
                if newValue != nil {
                    showingPurchaseError = true
                }
            }
        }
    }
}

#Preview {
    ThemeStoreView()
        .environmentObject(StoreManager())
        .environmentObject(ThemeManager())
}
