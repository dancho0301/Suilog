//
//  ContentView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var locationManager: LocationManager
    @Query private var aquariums: [Aquarium]

    @State private var selectedTab = 0
    @State private var showingThemeStore = false
    @State private var showingNearbyAlert = false
    @State private var nearbyAquarium: Aquarium?
    @State private var showingCheckInSheet = false
    @State private var hasCheckedNearbyOnLaunch = false

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
        .sheet(isPresented: $showingCheckInSheet) {
            if let aquarium = nearbyAquarium {
                LocationCheckInView(aquarium: aquarium)
            }
        }
        .onReceive(storeManager.$purchasedProductIds) { productIds in
            // 購入状態が変わったらThemeManagerに通知
            themeManager.updatePurchasedProducts(productIds)
        }
        .onReceive(locationManager.$currentLocation) { location in
            // 位置情報が更新されたら、起動時の一回だけ近くの水族館をチェック
            guard !hasCheckedNearbyOnLaunch, location != nil else { return }
            hasCheckedNearbyOnLaunch = true
            checkNearbyAquariums()
        }
        .alert("近くに水族館があります！", isPresented: $showingNearbyAlert) {
            Button("チェックインする") {
                showingCheckInSheet = true
            }
            Button("あとで", role: .cancel) { }
        } message: {
            if let aquarium = nearbyAquarium {
                let distanceText = formatDistance(to: aquarium)
                Text("\(aquarium.name)が\(distanceText)にあります。\n今すぐチェックインしますか？")
            }
        }
    }

    /// 1km以内の水族館をチェック
    private func checkNearbyAquariums() {
        // 最も近い水族館を検索（1km以内）
        var closestAquarium: Aquarium?
        var closestDistance: CLLocationDistance = .infinity

        for aquarium in aquariums {
            if locationManager.isWithinRange(of: aquarium, radius: 1000) {
                let coordinate = CLLocationCoordinate2D(latitude: aquarium.latitude, longitude: aquarium.longitude)
                if let distance = locationManager.distance(to: coordinate), distance < closestDistance {
                    closestDistance = distance
                    closestAquarium = aquarium
                }
            }
        }

        if let aquarium = closestAquarium {
            nearbyAquarium = aquarium
            showingNearbyAlert = true
        }
    }

    /// 水族館までの距離をフォーマット
    private func formatDistance(to aquarium: Aquarium) -> String {
        let coordinate = CLLocationCoordinate2D(latitude: aquarium.latitude, longitude: aquarium.longitude)
        if let distance = locationManager.distance(to: coordinate) {
            if distance < 1000 {
                return "\(Int(distance))m"
            } else {
                return String(format: "%.1fkm", distance / 1000)
            }
        }
        return "近く"
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(ThemeManager())
        .environmentObject(StoreManager())
        .environmentObject(LocationManager())
}
