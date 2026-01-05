//
//  ContentView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MyTankView()
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Aquarium.self, inMemory: true)
}
