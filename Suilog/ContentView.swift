//
//  ContentView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storeManager: StoreManager
    @State private var selectedTab = 0
    @State private var showingThemeStore = false

    var body: some View {
        TabView(selection: $selectedTab) {
            MyTankView()
                .overlay(alignment: .topTrailing) {
                    // テーマストアへのボタン
                    Button {
                        showingThemeStore = true
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.8))
                                    .shadow(radius: 4)
                            )
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                }
                .tabItem {
                    Label("マイ水槽", systemImage: "fish.fill")
                }
                .tag(0)

            AquariumMapView()
                .tabItem {
                    Label("マップ", systemImage: "map.fill")
                }
                .tag(1)

            PassportView()
                .tabItem {
                    Label("訪問記録", systemImage: "book.closed.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingThemeStore) {
            ThemeStoreView()
                .environmentObject(storeManager)
                .environmentObject(themeManager)
        }
        .onReceive(storeManager.$purchasedProductIds) { productIds in
            // 購入状態が変わったらThemeManagerに通知
            themeManager.updatePurchasedProducts(productIds)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(ThemeManager())
        .environmentObject(StoreManager())
}
