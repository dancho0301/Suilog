//
//  StoreManager.swift
//  Suilog
//
//  Created by dancho on 2025/01/07.
//

import StoreKit
import Combine

/// StoreKit 2 を使用したアプリ内課金管理
@MainActor
class StoreManager: ObservableObject {
    /// 読み込み済みの商品一覧
    @Published private(set) var products: [Product] = []

    /// 購入済みのProduct ID一覧
    @Published private(set) var purchasedProductIds: Set<String> = []

    /// 商品を読み込み中かどうか
    @Published private(set) var isLoading = false

    /// 購入処理中かどうか
    @Published private(set) var isPurchasing = false

    /// エラーメッセージ
    @Published var errorMessage: String?

    /// トランザクション更新のリスナータスク
    private var updateListenerTask: Task<Void, Error>?

    /// テーマ商品のProduct ID一覧
    static let themeProductIds: Set<String> = [
        "com.suilog.theme.yumekawa",
        "com.suilog.theme.all_pack"
    ]

    init() {
        // トランザクション更新をリッスン
        updateListenerTask = listenForTransactions()

        // 商品と購入状態を読み込む
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// 商品一覧を読み込む
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await Product.products(for: StoreManager.themeProductIds)
            // 価格順にソート
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "商品の読み込みに失敗しました: \(error.localizedDescription)"
            print("Failed to load products: \(error)")
        }

        isLoading = false
    }

    /// 商品を購入する
    /// - Parameter product: 購入する商品
    /// - Returns: 購入が成功したかどうか
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                isPurchasing = false
                return true

            case .userCancelled:
                isPurchasing = false
                return false

            case .pending:
                errorMessage = "購入が保留中です。しばらくお待ちください。"
                isPurchasing = false
                return false

            @unknown default:
                isPurchasing = false
                return false
            }
        } catch StoreError.verificationFailed {
            errorMessage = "購入の検証に失敗しました。"
            isPurchasing = false
            return false
        } catch {
            errorMessage = "購入に失敗しました: \(error.localizedDescription)"
            isPurchasing = false
            return false
        }
    }

    /// 購入を復元する
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 特定のProduct IDに対応する商品を取得
    func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
    }

    /// 特定の商品が購入済みかどうか
    func isPurchased(_ productId: String) -> Bool {
        purchasedProductIds.contains(productId) ||
        purchasedProductIds.contains("com.suilog.theme.all_pack")
    }

    // MARK: - Private Methods

    /// 購入済み商品を更新する
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }

        purchasedProductIds = purchased
    }

    /// トランザクションの更新をリッスンする
    private func listenForTransactions() -> Task<Void, Error> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }

    /// トランザクションの検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Error Types

enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "購入の検証に失敗しました"
        }
    }
}
