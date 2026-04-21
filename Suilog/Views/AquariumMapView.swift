//
//  AquariumMapView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import MapKit

/// 訪問ステータスフィルタの列挙型
enum VisitStatus: String, CaseIterable, Identifiable {
    case all = "すべて"
    case visited = "訪問済み"
    case notVisited = "未訪問"

    var id: String { self.rawValue }
}

struct AquariumMapView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedAquarium: Aquarium?
    @State private var showingList = false

    // フィルタ状態（親で管理）
    @State private var searchText = ""
    @State private var selectedRegions: Set<String> = []
    @State private var visitStatusFilter: VisitStatus = .all

    /// 地域の順序（北から南へ）
    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
    ]

    /// 訪問済み水族館IDのSet（O(1)で判定可能）
    private var visitedAquariumIds: Set<UUID> {
        Set(visitRecords.compactMap { $0.aquarium?.id })
    }

    /// フィルタ済み水族館リスト
    private var filteredAquariums: [Aquarium] {
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
                switch visitStatusFilter {
                case .all:
                    return true
                case .visited:
                    return visitedAquariumIds.contains(aquarium.id)
                case .notVisited:
                    return !visitedAquariumIds.contains(aquarium.id)
                }
            }
    }

    /// アクティブなフィルタ数
    private var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if !selectedRegions.isEmpty { count += 1 }
        if visitStatusFilter != .all { count += 1 }
        return count
    }

    private var theme: Theme { themeManager.currentTheme }

    /// 現在地から近い順にソート（上位5件）
    private var nearbyAquariums: [Aquarium] {
        guard let here = locationManager.currentLocation else {
            return Array(filteredAquariums.prefix(5))
        }
        return filteredAquariums
            .sorted { a, b in
                let da = here.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude))
                let db = here.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                return da < db
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        searchCard
                        mapCard
                        nearbySection
                        filterActionRow
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedAquarium) { aquarium in
                AquariumDetailView(aquarium: aquarium)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingList) {
                AquariumListView(
                    selectedAquarium: $selectedAquarium,
                    searchText: $searchText,
                    selectedRegions: $selectedRegions,
                    visitStatusFilter: $visitStatusFilter,
                    regionOrder: regionOrder
                )
            }
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("どこへ行く？")
                .font(SuiFont.label)
                .foregroundColor(SuiColor.midText)
            Text("マップ")
                .font(SuiFont.screenTitle)
                .foregroundColor(SuiColor.heading)
        }
    }

    private var searchCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SuiColor.subText)
            TextField("水族館を検索", text: $searchText)
                .font(SuiFont.body)
                .foregroundColor(SuiColor.heading)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SuiColor.subText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: SuiRadius.cardSmall, style: .continuous)
                .fill(SuiColor.cardSurface)
        )
        .suiShadow(.card)
    }

    private var mapCard: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $position, selection: $selectedAquarium) {
                ForEach(filteredAquariums, id: \.id) { aquarium in
                    let hasVisited = visitedAquariumIds.contains(aquarium.id)
                    Annotation(
                        aquarium.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: aquarium.latitude,
                            longitude: aquarium.longitude
                        )
                    ) {
                        MapPin(isVisited: hasVisited, theme: theme)
                            .onTapGesture { selectedAquarium = aquarium }
                    }
                    .tag(aquarium)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: SuiRadius.cardLarge, style: .continuous))
            .suiShadow(.card)

            legendOverlay
                .padding(12)
        }
    }

    private var legendOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(theme.primaryColor).frame(width: 10, height: 10)
                Text("訪問済み")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SuiColor.heading)
            }
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(SuiColor.fieldBorder, lineWidth: 1))
                    Circle().fill(theme.accent).frame(width: 4, height: 4)
                        .offset(x: 3, y: -3)
                }
                Text("未訪問")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SuiColor.heading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .suiShadow(.card)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("近くの水族館") {
                Button("すべて見る") { showingList = true }
                    .font(SuiFont.label)
                    .foregroundColor(theme.primaryColor)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if nearbyAquariums.isEmpty {
                        Text("該当する水族館がありません")
                            .font(SuiFont.body)
                            .foregroundColor(SuiColor.midText)
                            .padding(.horizontal, 4)
                    } else {
                        ForEach(nearbyAquariums, id: \.id) { aquarium in
                            NearbyAquariumCard(
                                aquarium: aquarium,
                                visited: visitedAquariumIds.contains(aquarium.id),
                                distanceMeters: distanceTo(aquarium),
                                theme: theme
                            )
                            .onTapGesture { selectedAquarium = aquarium }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var filterActionRow: some View {
        HStack(spacing: 12) {
            Button {
                showingList = true
            } label: {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("リスト・フィルタ")
                        .font(SuiFont.bodyMedium)
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(theme.accent))
                    }
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                        .fill(theme.primaryColor)
                )
                .suiShadow(.primaryButton(primary: theme.primaryColor))
            }
        }
    }

    private func distanceTo(_ aquarium: Aquarium) -> Double? {
        locationManager.distance(to: CLLocationCoordinate2D(latitude: aquarium.latitude, longitude: aquarium.longitude))
    }
}

// MARK: - カスタムマップピン

private struct MapPin: View {
    let isVisited: Bool
    let theme: Theme

    var body: some View {
        ZStack {
            if isVisited {
                Circle()
                    .fill(theme.primaryColor)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .suiShadow(.card)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(theme.primaryColor.opacity(0.6), lineWidth: 2))
                    .suiShadow(.card)
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .offset(x: 8, y: -8)
            }
        }
    }
}

// MARK: - 「近くの水族館」横スクロールカード

private struct NearbyAquariumCard: View {
    let aquarium: Aquarium
    let visited: Bool
    let distanceMeters: Double?
    let theme: Theme

    private var emoji: String {
        let n = aquarium.representativeFish.lowercased()
        if n.contains("whale") || n.contains("orca") { return "🐋" }
        if n.contains("penguin") { return "🐧" }
        if n.contains("shark") { return "🦈" }
        if n.contains("jellyfish") { return "🪼" }
        if n.contains("dolphin") { return "🐬" }
        return "🌊"
    }

    private var distanceText: String {
        guard let d = distanceMeters else { return aquarium.region }
        if d < 1000 { return "\(Int(d))m" }
        return String(format: "%.1fkm", d / 1000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.primaryBg)
                        .frame(width: 44, height: 44)
                    Text(emoji).font(.system(size: 22))
                }
                Spacer()
                if visited {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 18))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(aquarium.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SuiColor.heading)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(distanceText)
                        .font(.system(size: 12))
                }
                .foregroundColor(SuiColor.subText)
            }
        }
        .padding(14)
        .frame(width: 180, height: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: SuiRadius.cardMedium, style: .continuous)
                .fill(SuiColor.cardSurface)
        )
        .suiShadow(.card)
    }
}

struct AquariumListView: View {
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord]
    @Binding var selectedAquarium: Aquarium?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // フィルタ用のBinding変数（親から受け取る）
    @Binding var searchText: String
    @Binding var selectedRegions: Set<String>
    @Binding var visitStatusFilter: VisitStatus
    let regionOrder: [String]

    @State private var showFilterSheet = false

    /// 訪問済み水族館IDのSet（O(1)で判定可能）
    private var visitedAquariumIds: Set<UUID> {
        Set(visitRecords.compactMap { $0.aquarium?.id })
    }

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
                switch visitStatusFilter {
                case .all:
                    return true
                case .visited:
                    return visitedAquariumIds.contains(aquarium.id)
                case .notVisited:
                    return !visitedAquariumIds.contains(aquarium.id)
                }
            }
            .sorted { a, b in
                let aVisited = visitedAquariumIds.contains(a.id)
                let bVisited = visitedAquariumIds.contains(b.id)

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
                                Image(themeManager.currentTheme.creatureImageName(aquarium.representativeFish))
                                    .renderingMode(.original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                            } else {
                                Image(systemName: aquarium.representativeFish)
                                    .font(.system(size: 40))
                                    .foregroundColor(visitedAquariumIds.contains(aquarium.id) ? .blue : .gray.opacity(0.5))
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

                        if visitedAquariumIds.contains(aquarium.id) {
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
                                    Image(themeManager.currentTheme.creatureImageName(aquarium.representativeFish))
                                        .renderingMode(.original)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                } else {
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

                    // 公式HP
                    if let officialUrl = aquarium.officialUrl, !officialUrl.isEmpty,
                       let url = URL(string: officialUrl) {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("公式HP")
                                .font(.headline)
                            Link(destination: url) {
                                HStack {
                                    Text("公式サイトを開く")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "safari")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // チケット購入
                    if let affiliateLink = aquarium.affiliateLink, !affiliateLink.isEmpty,
                       let url = URL(string: affiliateLink) {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("チケット購入")
                                .font(.headline)
                            Link(destination: url) {
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
                    if !aquarium.safeVisits.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("訪問履歴")
                                .font(.headline)

                            let locationCheckIns = aquarium.safeVisits.filter { $0.checkInType == .location }.count
                            let manualCheckIns = aquarium.safeVisits.filter { $0.checkInType == .manual }.count

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("訪問回数")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(aquarium.safeVisits.count)回")
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

                            if let lastVisit = aquarium.safeVisits.sorted(by: { $0.visitDate > $1.visitDate }).first {
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
                        // 位置情報チェックインボタン
                        ZStack(alignment: .topTrailing) {
                            Button {
                                showingLocationCheckInForm = true
                            } label: {
                                HStack {
                                    Image(systemName: canLocationCheckIn ? "location.circle.fill" : "location.slash")
                                    Text("位置情報でチェックイン")
                                    Spacer()
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.yellow)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(canLocationCheckIn ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(canLocationCheckIn ? .black : .secondary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(canLocationCheckIn ? Color.yellow : Color.gray.opacity(0.5), lineWidth: canLocationCheckIn ? 0 : 1)
                                )
                            }
                            .disabled(!canLocationCheckIn)
                            .opacity(canLocationCheckIn ? 1.0 : 0.5)
                            .accessibilityLabel(canLocationCheckIn ? "位置情報でチェックイン、チェックイン可能" : "位置情報でチェックイン、水族館から1km以内で利用可能")

                            // チェックイン可能バッジ
                            if canLocationCheckIn {
                                Text("チェックイン可能！")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                    .offset(x: 8, y: -8)
                                    .accessibilityHidden(true)
                            }
                        }

                        if !canLocationCheckIn {
                            Text("※ 水族館から1km以内で利用可能")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

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

                        Text("※ 訪問日を自由に設定できます。写真をアップすると撮影日時と位置情報から自動判定します")
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
    @Binding var visitStatusFilter: VisitStatus
    let regionOrder: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // 訪問ステータスセクション
                Section {
                    Picker("訪問ステータス", selection: $visitStatusFilter) {
                        ForEach(VisitStatus.allCases) { status in
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
fileprivate func isCustomAsset(_ name: String) -> Bool {
    return !name.contains(".")
}

#Preview {
    AquariumMapView()
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(LocationManager())
}
