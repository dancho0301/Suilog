//
//  SuilogApp.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData

@main
struct SuilogApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var themeManager = ThemeManager()

    var sharedModelContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            // マイグレーションプランを使用してModelContainerを作成
            // これにより、スキーマV1→V2→V3への自動マイグレーションが実行され、
            // 既存の訪問データは保持されます
            let container = try ModelContainer(
                for: AquariumMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            print("✅ ModelContainerを作成しました（マイグレーションプラン使用）")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(storeManager)
                .environmentObject(themeManager)
                .task {
                    // 初回起動時にサンプルデータを挿入
                    await seedDataIfNeeded()
                }
                .onReceive(storeManager.$purchasedProductIds) { productIds in
                    // 購入状態が変わったらThemeManagerに通知
                    themeManager.updatePurchasedProducts(productIds)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedDataIfNeeded() async {
        let context = sharedModelContainer.mainContext
        await DataSeeder.seedAquariums(context: context)
    }
}
