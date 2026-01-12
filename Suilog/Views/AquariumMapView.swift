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
    @EnvironmentObject private var themeManager: ThemeManager
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
                        // visitRecordsを使うことで変更検知を確実にする
                        let hasVisited = visitRecords.contains { $0.aquarium?.id == aquarium.id }
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
    @EnvironmentObject private var themeManager: ThemeManager

    // 検索・フィルタ用のState変数
    @State private var searchText = ""
    @State private var selectedRegions: Set<String> = []
    @State private var visitStatusFilter: VisitStatus = .all
    @State private var showFilterSheet = false

    /// 訪問ステータスフィルタの列挙型
    enum VisitStatus: String, CaseIterable, Identifiable {
        case all = "すべて"
        case visited = "訪問済み"
        case notVisited = "未訪問"

        var id: String { self.rawValue }
    }

    /// 地域の順序（北から南へ）
    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
    ]

    /// フィルタ済み＆ソート済み水族館リスト
    private var filteredAndSortedAquariums: [Aquarium] {
        aquariums
            .filter { aquarium in
                // 検索テキストフィルタ
                if !searchText.isEmpty {
                    return aquarium.name.localizedCaseInsensitiveContains(searchText)
                }
                return true
            }
            .filter { aquarium in
                // 地域フィルタ
                if !selectedRegions.isEmpty {
                    return selectedRegions.contains(aquarium.region)
                }
                return true
            }
            .filter { aquarium in
                // 訪問ステータスフィルタ
                let hasVisited = visitRecords.contains { $0.aquarium?.id == aquarium.id }
                switch visitStatusFilter {
                case .all:
                    return true
                case .visited:
                    return hasVisited
                case .notVisited:
                    return !hasVisited
                }
            }
            .sorted { a, b in
                // visitRecordsを使うことで変更検知を確実にする
                let aVisited = visitRecords.contains { $0.aquarium?.id == a.id }
                let bVisited = visitRecords.contains { $0.aquarium?.id == b.id }

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

    /// アクティブなフィルタ数
    private var activeFilterCount: Int {
        var count = 0
        if !selectedRegions.isEmpty { count += 1 }
        if visitStatusFilter != .all { count += 1 }
        return count
    }

    var body: some View {
        NavigationStack {
            List(filteredAndSortedAquariums, id: \.id) { aquarium in
                Button {
                    selectedAquarium = aquarium
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        // 代表的な魚のアイコン
                        Group {
                            if isCustomAsset(aquarium.representativeFish) {
                                // カスタムアセット（テーマフォルダから取得）
                                Image(themeManager.currentTheme.creatureImageName(aquarium.representativeFish))
                                    .renderingMode(.original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                            } else {
                                Image(systemName: aquarium.representativeFish)
                                    .font(.system(size: 40))
                                    .foregroundColor(visitRecords.contains { $0.aquarium?.id == aquarium.id } ? .blue : .gray.opacity(0.5))
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

                        if visitRecords.contains(where: { $0.aquarium?.id == aquarium.id }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("水族館リスト")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "水族館を検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    selectedRegions: $selectedRegions,
                    visitStatusFilter: $visitStatusFilter,
                    regionOrder: regionOrder
                )
            }
        }
    }
}

struct AquariumDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var themeManager: ThemeManager

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
                                    // カスタムアセット（テーマフォルダから取得）
                                    Image(themeManager.currentTheme.creatureImageName(aquarium.representativeFish))
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

                    Divider()

                    // 住所
                    if let address = aquarium.address, !address.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("住所")
                                .font(.headline)
                            Text(address)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal)
                    }

                    // チケット購入
                    if let affiliateLink = aquarium.affiliateLink, !affiliateLink.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("チケット購入")
                                .font(.headline)
                            Link(destination: URL(string: affiliateLink)!) {
                                HStack {
                                    Text("オンラインでチケットを購入")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

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
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(10)
                        .padding(.horizontal)
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

/// フィルタシートビュー
struct FilterSheet: View {
    @Binding var selectedRegions: Set<String>
    @Binding var visitStatusFilter: AquariumListView.VisitStatus
    let regionOrder: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // 訪問ステータスセクション
                Section {
                    Picker("訪問ステータス", selection: $visitStatusFilter) {
                        ForEach(AquariumListView.VisitStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("訪問ステータス")
                }

                // 地域セクション
                Section {
                    ForEach(regionOrder, id: \.self) { region in
                        Toggle(isOn: Binding(
                            get: { selectedRegions.contains(region) },
                            set: { isOn in
                                if isOn {
                                    selectedRegions.insert(region)
                                } else {
                                    selectedRegions.remove(region)
                                }
                            }
                        )) {
                            Text(region)
                        }
                    }
                } header: {
                    HStack {
                        Text("地域")
                        Spacer()
                        if !selectedRegions.isEmpty {
                            Button("すべて解除") {
                                selectedRegions.removeAll()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("フィルタ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("リセット") {
                        selectedRegions.removeAll()
                        visitStatusFilter = .all
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
