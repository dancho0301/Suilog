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
    @State private var hasCenteredOnUser = false
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
                // 検索テキストフィルタ（名前・地域・住所）
                if !searchText.isEmpty {
                    return aquarium.matchesSearch(searchText)
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
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                centerOnUserIfNeeded()
            }
            .onChange(of: locationManager.currentLocation) { _, _ in
                centerOnUserIfNeeded()
            }
        }
    }

    /// 現在地を取得できたら、初回のみ現在地周辺の拡大図に初期表示を合わせる。
    /// ユーザーが手動で地図を操作した後に勝手に戻らないよう、一度だけ実行する。
    private func centerOnUserIfNeeded() {
        guard !hasCenteredOnUser,
              let coordinate = locationManager.currentLocation?.coordinate else { return }
        hasCenteredOnUser = true
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 30_000,
            longitudinalMeters: 30_000
        )
        withAnimation {
            position = .region(region)
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
            TextField("名前・地域・住所で検索", text: $searchText)
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
            Map(position: $position) {
                UserAnnotation()
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
                // 検索テキストフィルタ（名前・地域・住所）
                if !searchText.isEmpty {
                    return aquarium.matchesSearch(searchText)
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
            .searchable(text: $searchText, prompt: "名前・地域・住所で検索")
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
    @Query private var visitRecords: [VisitRecord]

    let aquarium: Aquarium

    @State private var showingNewRecordForm = false
    @State private var newRecordInitialMode: CheckInType = .location

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

    /// 圏外時の案内文（現在地が取得できていれば残り距離を併記）
    private var locationCheckInHint: String {
        let coordinate = CLLocationCoordinate2D(latitude: aquarium.latitude, longitude: aquarium.longitude)
        guard let distance = locationManager.distance(to: coordinate), distance > 1000 else {
            return "※ 水族館から1km以内で利用可能"
        }
        let remaining = distance - 1000
        let remainingText = remaining < 1000
            ? "\(Int(remaining))m"
            : String(format: "%.1fkm", remaining / 1000)
        return "※ 水族館から1km以内で利用可能（あと約\(remainingText)）"
    }

    private var theme: Theme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard
                        infoCard(title: "説明", icon: "text.alignleft") {
                            Text(aquarium.aquariumDescription)
                                .font(SuiFont.body)
                                .foregroundColor(SuiColor.midText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let address = aquarium.address, !address.isEmpty {
                            infoCard(title: "住所", icon: "mappin.and.ellipse") {
                                Text(address)
                                    .font(SuiFont.body)
                                    .foregroundColor(SuiColor.midText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let url = validatedWebURL(aquarium.officialUrl) {
                            linkCard(title: "公式HP", icon: "safari", url: url, label: "公式サイトを開く")
                        }

                        if let url = validatedWebURL(aquarium.affiliateLink) {
                            linkCard(title: "チケット購入", icon: "ticket", url: url, label: "オンラインでチケット購入")
                        }

                        if !aquarium.safeVisits.isEmpty {
                            historyCard
                        }

                        checkInActions
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.primaryColor)
                }
            }
            .sheet(isPresented: $showingNewRecordForm) {
                NewVisitRecordView(aquarium: aquarium, initialMode: newRecordInitialMode)
            }
        }
    }

    private var heroCard: some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Group {
                        if isCustomAsset(aquarium.representativeFish) {
                            Image(theme.creatureImageName(aquarium.representativeFish))
                                .renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                        } else {
                            Image(systemName: aquarium.representativeFish)
                                .font(.system(size: 80))
                                .foregroundColor(theme.primaryColor)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: SuiRadius.cardMedium, style: .continuous)
                        .fill(theme.primaryBg)
                )

                Text(aquarium.name)
                    .font(SuiFont.screenTitle)
                    .foregroundColor(SuiColor.heading)

                HStack(spacing: 12) {
                    Label(aquarium.region, systemImage: "mappin.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(SuiFont.caption)
                        .foregroundColor(theme.primaryColor)
                    Label("現在地から \(distanceText)", systemImage: "location.fill")
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.subText)
                }
            }
        }
    }

    @ViewBuilder
    private func infoCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 14, weight: .semibold))
                    Text(title)
                        .font(SuiFont.section)
                        .foregroundColor(SuiColor.heading)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 外部データ由来のURL文字列を検証し、http/https のみ許可する
    private func validatedWebURL(_ string: String?) -> URL? {
        guard let string, !string.isEmpty,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private func linkCard(title: String, icon: String, url: URL, label: String) -> some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 14, weight: .semibold))
                    Text(title)
                        .font(SuiFont.section)
                        .foregroundColor(SuiColor.heading)
                }
                Link(destination: url) {
                    HStack {
                        Text(label)
                            .font(SuiFont.bodyMedium)
                            .foregroundColor(theme.primaryColor)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(theme.primaryColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var historyCard: some View {
        let locationCheckIns = aquarium.safeVisits.filter { $0.checkInType == .location }.count
        let manualCheckIns = aquarium.safeVisits.filter { $0.checkInType == .manual }.count
        let lastVisit = aquarium.safeVisits.sorted(by: { $0.visitDate > $1.visitDate }).first

        return SuiCard(radius: SuiRadius.cardLarge, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 14, weight: .semibold))
                    Text("訪問履歴")
                        .font(SuiFont.section)
                        .foregroundColor(SuiColor.heading)
                }

                HStack(spacing: 0) {
                    StatItem(value: "\(aquarium.safeVisits.count)", label: "訪問回数", primary: theme.primaryColor)
                    Divider().frame(height: 32).background(SuiColor.divider)
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text("🥇\(locationCheckIns)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(SuiColor.goldText)
                            Text("🥈\(manualCheckIns)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(SuiColor.silverText)
                        }
                        Text("チェックイン")
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let lastVisit {
                    HStack {
                        Text("最終訪問")
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                        Spacer()
                        Text(lastVisit.visitDate.formatted(Date.FormatStyle(date: .long).locale(Locale(identifier: "ja_JP"))))
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.heading)
                        CheckInBadge(type: lastVisit.checkInType)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var checkInActions: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Button {
                    newRecordInitialMode = .location
                    showingNewRecordForm = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: canLocationCheckIn ? "location.circle.fill" : "location.slash")
                        Text("位置情報でチェックイン")
                            .font(SuiFont.bodyMedium)
                        Spacer()
                        Text("🥇")
                    }
                    .foregroundColor(canLocationCheckIn ? .white : SuiColor.subText)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                            .fill(canLocationCheckIn ? theme.primaryColor : SuiColor.fieldBg)
                    )
                }
                .disabled(!canLocationCheckIn)
                .shadow(
                    color: canLocationCheckIn ? theme.primaryColor.opacity(0.31) : .clear,
                    radius: canLocationCheckIn ? 20 : 0,
                    x: 0,
                    y: canLocationCheckIn ? 6 : 0
                )

                if canLocationCheckIn {
                    Text("チェックイン可能！")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green))
                        .offset(x: 8, y: -8)
                }
            }

            if !canLocationCheckIn {
                Text(locationCheckInHint)
                    .font(SuiFont.caption)
                    .foregroundColor(SuiColor.subText)
            }

            Button {
                newRecordInitialMode = .manual
                showingNewRecordForm = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                    Text("手動でチェックイン")
                        .font(SuiFont.bodyMedium)
                    Spacer()
                    Text("🥈")
                }
                .foregroundColor(SuiColor.heading)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                        .fill(SuiColor.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                        .stroke(SuiColor.fieldBorder, lineWidth: 1)
                )
            }

            Text("※ 訪問日を自由に設定できます。写真をアップすると撮影日時と位置情報から自動判定します")
                .font(SuiFont.caption)
                .foregroundColor(SuiColor.subText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
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

fileprivate extension Aquarium {
    /// 検索テキストが名前・地域・住所のいずれかに一致するか
    func matchesSearch(_ text: String) -> Bool {
        name.localizedCaseInsensitiveContains(text)
            || region.localizedCaseInsensitiveContains(text)
            || (address?.localizedCaseInsensitiveContains(text) ?? false)
    }
}

#Preview {
    AquariumMapView()
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(LocationManager())
}
