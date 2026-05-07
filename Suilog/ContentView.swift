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
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    private var tabItems: [CustomTabBarItem] {
        let theme = themeManager.currentTheme
        return [
            CustomTabBarItem(id: 0, title: "マイ水槽", icon: { active in
                AnyView(TankTabIcon(active: active, theme: theme))
            }),
            CustomTabBarItem(id: 1, title: "マップ", icon: { active in
                AnyView(MapTabIcon(active: active, theme: theme))
            }),
            CustomTabBarItem(id: 2, title: "記録", icon: { active in
                AnyView(RecordsTabIcon(active: active, theme: theme))
            }),
            CustomTabBarItem(id: 3, title: "プロフィール", icon: { active in
                AnyView(ProfileTabIcon(active: active, theme: theme))
            })
        ]
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MyTankView(
                onTapAvatar: { showingThemeStore = true },
                onSeeAllVisits: { selectedTab = 2 }
            )
                #if DEBUG
                .overlay(alignment: .topLeading) {
                    Button {
                        showingDebugMenu = true
                    } label: {
                        Image(systemName: "ladybug.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                                    .shadow(radius: 4)
                            )
                    }
                    .padding(.top, 60)
                    .padding(.leading, 16)
                }
                .overlay(alignment: .top) {
                    if DebugSettings.shared.isDebugModeEnabled {
                        Text("DEBUG MODE")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.9))
                    }
                }
                #endif
                .toolbar(.hidden, for: .tabBar)
                .tag(0)

            AquariumMapView()
                .toolbar(.hidden, for: .tabBar)
                .tag(1)

            PassportView()
                .toolbar(.hidden, for: .tabBar)
                .tag(2)

            ProfileView()
                .toolbar(.hidden, for: .tabBar)
                .tag(3)
        }
        .tint(themeManager.currentTheme.primaryColor)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(
                selected: $selectedTab,
                items: tabItems,
                primary: themeManager.currentTheme.primaryColor
            )
        }
        .sheet(isPresented: $showingThemeStore) {
            ThemeStoreView()
                .environmentObject(storeManager)
                .environmentObject(themeManager)
        }
        #if DEBUG
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenuView()
        }
        #endif
        .sheet(isPresented: $showingCheckInSheet) {
            if let aquarium = nearbyAquarium {
                NewVisitRecordView(aquarium: aquarium, initialMode: .location)
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
