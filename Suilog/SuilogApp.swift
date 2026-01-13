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

    // エラー状態
    @State private var showingInitialError = false
    @State private var initialErrorMessage = ""
    @State private var isRetrying = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Aquarium.self, VisitRecord.self])

        // シミュレータではCloudKit同期を無効化（iCloudサインインが不安定なため）
        #if targetEnvironment(simulator)
        let cloudKitSetting: ModelConfiguration.CloudKitDatabase = .none
        let modeDescription = "ローカルのみ（シミュレータ）"
        #else
        let cloudKitSetting: ModelConfiguration.CloudKitDatabase = .automatic
        let modeDescription = "CloudKit同期有効"
        #endif

        do {
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKitSetting
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: AquariumMigrationPlan.self,
                configurations: modelConfiguration
            )
            print("✅ ModelContainerを作成しました（\(modeDescription)）")
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
                .alert("データの読み込みに失敗しました", isPresented: $showingInitialError) {
                    Button("再試行") {
                        Task {
                            isRetrying = true
                            await seedDataIfNeeded()
                            isRetrying = false
                        }
                    }
                    Button("キャンセル", role: .cancel) { }
                } message: {
                    Text(initialErrorMessage)
                }
                .overlay {
                    if isRetrying {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            ProgressView("再試行中...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedDataIfNeeded() async {
        let context = sharedModelContainer.mainContext
        let result = await DataSeeder.seedAquariums(context: context)

        switch result {
        case .success, .skippedOffline:
            break // 正常
        case .errorNoData(let message):
            initialErrorMessage = message
            showingInitialError = true
        case .errorSaveFailed(let message):
            initialErrorMessage = message
            showingInitialError = true
        }
    }
}
