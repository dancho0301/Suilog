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

    /// 購入状態（権利）の最初の読み込みが終わったか。
    /// 起動直後は購入済みが空のため、テーマの巻き戻しやウィジェットの書き出しはこれが true になってから行う
    @Published private(set) var hasLoadedEntitlements = false

    /// 商品を読み込み中かどうか
    @Published private(set) var isLoading = false

    /// 購入処理中かどうか
    @Published private(set) var isPurchasing = false

    /// エラーメッセージ
    @Published var errorMessage: String?

    /// トランザクション更新のリスナータスク
    private var updateListenerTask: Task<Void, Error>?

    /// スイログ Pro（買い切り）のProduct ID
    static let proProductId = "com.suilog.pro"

    /// 応援課金（Tip Jar・消耗型）のProduct ID一覧
    static let tipProductIds: Set<String> = [
        "com.suilog.tip.small",
        "com.suilog.tip.medium",
        "com.suilog.tip.large"
    ]

    /// App Storeから読み込む全Product ID
    static var allProductIds: Set<String> {
        tipProductIds.union([proProductId])
    }

    /// 応援（チップ）の累計回数を保存するUserDefaultsキー
    static let tipCountKey = "TipTotalCount"

    /// スイログ Pro を購入済みかどうか
    var isProUnlocked: Bool {
        Self.isPro(in: purchasedProductIds)
    }

    /// 購入済みの Product ID に Pro が含まれるか（テスト容易性のため純粋関数として分離）
    static func isPro(in productIds: Set<String>) -> Bool {
        productIds.contains(proProductId)
    }

    /// 応援（チップ）の累計回数
    var tipCount: Int {
        UserDefaults.standard.integer(forKey: Self.tipCountKey)
    }

    init() {
        // トランザクション更新をリッスン
        updateListenerTask = listenForTransactions()

        // 購入状態（端末内で完結）を先に読み、商品（オフラインで待たされうる）は後に読み込む
        Task {
            await updatePurchasedProducts()
            await loadProducts()
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
            products = try await Product.products(for: StoreManager.allProductIds)
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

    /// チップ（消耗型）を購入する。成功時は累計応援回数を加算する
    /// - Parameter product: 購入するチップ商品
    /// - Returns: 購入が成功したかどうか
    func purchaseTip(_ product: Product) async -> Bool {
        let success = await purchase(product)
        if success {
            objectWillChange.send()
            UserDefaults.standard.set(tipCount + 1, forKey: Self.tipCountKey)
        }
        return success
    }

    /// 購入を復元する
    /// - Returns: 復元の結果（画面に「復元しました」などを出すために使う）
    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        isLoading = true
        errorMessage = nil
        var failed = false

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
            failed = true
        }

        isLoading = false
        return RestoreOutcome.resolve(isProUnlocked: isProUnlocked, failed: failed)
    }

    /// 特定のProduct IDに対応する商品を取得
    func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
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
        hasLoadedEntitlements = true
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

// MARK: - Restore Outcome

/// 購入の復元の結果
enum RestoreOutcome: Equatable {
    /// Pro が見つかって復元された
    case restored
    /// 通信は成功したが、復元できる購入がなかった
    case nothingToRestore
    /// 復元に失敗した（理由は StoreManager.errorMessage に入る）
    case failed

    static func resolve(isProUnlocked: Bool, failed: Bool) -> RestoreOutcome {
        if failed { return .failed }
        return isProUnlocked ? .restored : .nothingToRestore
    }

    /// 画面に出すメッセージ。失敗時は errorMessage のアラートが別に出るので nil
    var message: String? {
        switch self {
        case .restored: return "Pro を復元しました"
        case .nothingToRestore: return "復元できる購入が見つかりませんでした"
        case .failed: return nil
        }
    }
}
