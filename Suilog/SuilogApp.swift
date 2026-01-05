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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Aquarium.self,
            VisitRecord.self,
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainerを作成しました")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .task {
                    // 初回起動時にサンプルデータを挿入
                    await seedDataIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedDataIfNeeded() async {
        let context = sharedModelContainer.mainContext
        DataSeeder.seedAquariums(context: context)
    }
}
