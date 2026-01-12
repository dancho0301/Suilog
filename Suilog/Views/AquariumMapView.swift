//
//  AquariumMapView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import MapKit

struct AquariumMapView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationManager: LocationManager
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord] // 変更を検知するために追加

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedAquarium: Aquarium?
    @State private var showingList = false

    var body: some View {
        NavigationStack {
            ZStack {
                // マップ表示
                Map(position: $position, selection: $selectedAquarium) {
                    ForEach(aquariums, id: \.id) { aquarium in
                        let hasVisited = !aquarium.visits.isEmpty
                        // カスタムアイコンの場合は汎用アイコンを使用
                        let markerIcon = isCustomAsset(aquarium.representativeFish) ? "fish.fill" : aquarium.representativeFish
                        Marker(
                            aquarium.name,
                            systemImage: markerIcon,
                            coordinate: CLLocationCoordinate2D(
                                latitude: aquarium.latitude,
                                longitude: aquarium.longitude
                            )
                        )
                        .tint(hasVisited ? .blue : .gray)
                        .tag(aquarium)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }

                // リスト表示ボタン
                VStack {
                    Spacer()
                    Button {
                        showingList.toggle()
                    } label: {
                        Label(
                            showingList ? "マップを表示" : "リストを表示",
                            systemImage: showingList ? "map.fill" : "list.bullet"
                        )
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }
                    .padding()
                }
            }
            .navigationTitle("水族館マップ")
            .sheet(item: $selectedAquarium) { aquarium in
                AquariumDetailView(aquarium: aquarium)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingList) {
                AquariumListView(selectedAquarium: $selectedAquarium)
            }
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }
}

struct AquariumListView: View {
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord] // 変更を検知するために追加
    @Binding var selectedAquarium: Aquarium?
    @Environment(\.dismiss) private var dismiss

    /// 地域の順序（北から南へ）
    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
    ]

    /// ソート済み水族館リスト（訪問済み→未訪問、北から南へ）
    private var sortedAquariums: [Aquarium] {
        aquariums.sorted { a, b in
            let aVisited = !a.visits.isEmpty
            let bVisited = !b.visits.isEmpty

            // 1. 訪問済みを上に
            if aVisited != bVisited {
                return aVisited
            }

            // 2. 地域順（北から南へ）
            let aRegionIndex = regionOrder.firstIndex(of: a.region) ?? Int.max
            let bRegionIndex = regionOrder.firstIndex(of: b.region) ?? Int.max

            if aRegionIndex != bRegionIndex {
                return aRegionIndex < bRegionIndex
            }

            // 3. 同じ地域内では名前順
            return a.name < b.name
        }
    }

    var body: some View {
        NavigationStack {
            List(sortedAquariums, id: \.id) { aquarium in
                Button {
                    selectedAquarium = aquarium
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        // 代表的な魚のアイコン
                        Group {
                            if isCustomAsset(aquarium.representativeFish) {
                                // カスタムアセット
                                Image(aquarium.representativeFish)
                                    .renderingMode(.original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                            } else {
                                Image(systemName: aquarium.representativeFish)
                                    .font(.system(size: 40))
                                    .foregroundColor(!aquarium.visits.isEmpty ? .blue : .gray.opacity(0.5))
                            }
                        }
                        .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(aquarium.name)
                                .font(.headline)

                            Text(aquarium.region)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !aquarium.visits.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("水族館リスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AquariumDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager

    let aquarium: Aquarium

    @State private var showingLocationCheckInForm = false
    @State private var showingManualCheckIn = false

    var distanceText: String {
        if let distance = locationManager.distance(to: CLLocationCoordinate2D(latitude: aquarium.latitude, longitude: aquarium.longitude)) {
            let km = distance / 1000.0
            return String(format: "%.1f km", km)
        }
        return "不明"
    }

    var canLocationCheckIn: Bool {
        locationManager.isWithinRange(of: aquarium, radius: 1000)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ヘッダー（魚のアイコン付き）
                    VStack(alignment: .leading, spacing: 16) {
                        // 魚のアイコン
                        HStack {
                            Spacer()
                            Group {
                                if isCustomAsset(aquarium.representativeFish) {
                                    // カスタムアセット
                                    Image(aquarium.representativeFish)
                                        .renderingMode(.original)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                } else {
                                    // SF Symbols
                                    Image(systemName: aquarium.representativeFish)
                                        .font(.system(size: 80))
                                        .foregroundColor(.blue.opacity(0.7))
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)

                        Text(aquarium.name)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(aquarium.region)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("現在地から \(distanceText)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()

                    Divider()

                    // 説明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("説明")
                            .font(.headline)
                        Text(aquarium.aquariumDescription)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal)

                    // 訪問履歴
                    if !aquarium.visits.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("訪問履歴")
                                .font(.headline)

                            // 訪問回数と種別の集計
                            let locationCheckIns = aquarium.visits.filter { $0.checkInType == .location }.count
                            let manualCheckIns = aquarium.visits.filter { $0.checkInType == .manual }.count

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("訪問回数")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(aquarium.visits.count)回")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }

                                Divider()
                                    .frame(height: 30)

                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                        Text("\(locationCheckIns)")
                                            .font(.callout)
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(manualCheckIns)")
                                            .font(.callout)
                                    }
                                }
                            }

                            if let lastVisit = aquarium.visits.sorted(by: { $0.visitDate > $1.visitDate }).first {
                                Divider()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("最終訪問")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack {
                                        Text(lastVisit.visitDate.formatted(Date.FormatStyle(date: .long).locale(Locale(identifier: "ja_JP"))))
                                            .font(.callout)
                                        Spacer()
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(lastVisit.checkInType == .location ? .yellow : .gray)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    Divider()

                    // チェックインボタン
                    VStack(spacing: 12) {
                        // 位置情報ベースのチェックイン（ゴールド）
                        Button {
                            showingLocationCheckInForm = true
                        } label: {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                Text("位置情報でチェックイン")
                                Spacer()
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.yellow)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(canLocationCheckIn ? Color.yellow.opacity(0.8) : Color.gray)
                            .foregroundColor(canLocationCheckIn ? .black : .white)
                            .cornerRadius(10)
                        }
                        .disabled(!canLocationCheckIn)

                        if !canLocationCheckIn {
                            Text("※ 水族館から1km以内で利用可能")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 手動チェックイン（シルバー）
                        Button {
                            showingManualCheckIn = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("手動でチェックイン")
                                Spacer()
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        Text("※ 手動チェックインは訪問日を自由に設定できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingLocationCheckInForm) {
                LocationCheckInView(aquarium: aquarium)
            }
            .sheet(isPresented: $showingManualCheckIn) {
                ManualCheckInView(aquarium: aquarium)
            }
        }
    }
}

/// SF Symbolsかカスタムアセットかを判定するヘルパー関数
/// SF Symbolsは必ず "." を含む（例: fish.fill, seal.fill）
/// カスタムアセットは "." を含まない（例: orca, Dolphin, freshwaterfish）
fileprivate func isCustomAsset(_ name: String) -> Bool {
    return !name.contains(".")
}

#Preview {
    AquariumMapView()
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(LocationManager())
}
