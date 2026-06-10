//
//  PassportView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//  Redesigned per design_handoff_suilog spec.
//

import SwiftUI
import SwiftData

struct PassportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Query(sort: \VisitRecord.visitDate, order: .reverse) private var visitRecords: [VisitRecord]

    @State private var selectedVisit: VisitRecord?
    @State private var visitToShare: VisitRecord?
    @State private var photoToView: ViewedPhotos?
    @State private var showDeleteConfirmation = false
    @State private var visitToDelete: VisitRecord?
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showingAquariumPicker = false
    @State private var pickerSelectedAquarium: Aquarium?
    @State private var pickerSearchText = ""
    @State private var pickerSelectedRegions: Set<String> = []
    @State private var pickerVisitStatus: VisitStatus = .all

    // 記録の検索・絞り込み
    @State private var searchText = ""
    @State private var typeFilter: RecordTypeFilter = .all
    @State private var yearFilter: Int?

    /// チェックイン種別の絞り込み
    enum RecordTypeFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case gold = "🥇 ゴールド"
        case silver = "🥈 シルバー"

        var id: String { rawValue }
    }

    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
    ]

    private var theme: Theme { themeManager.currentTheme }

    /// 検索・絞り込みが有効かどうか
    private var isFiltering: Bool {
        !searchText.isEmpty || typeFilter != .all || yearFilter != nil
    }

    /// 記録に存在する年の一覧（新しい順）
    private var availableYears: [Int] {
        Set(visitRecords.map { Calendar.current.component(.year, from: $0.visitDate) })
            .sorted(by: >)
    }

    /// 検索・絞り込み適用後の訪問記録
    private var filteredRecords: [VisitRecord] {
        visitRecords.filter { visit in
            if !searchText.isEmpty {
                let nameMatch = visit.aquarium?.name.localizedCaseInsensitiveContains(searchText) ?? false
                let memoMatch = visit.memo.localizedCaseInsensitiveContains(searchText)
                guard nameMatch || memoMatch else { return false }
            }
            switch typeFilter {
            case .all: break
            case .gold: guard visit.checkInType == .location else { return false }
            case .silver: guard visit.checkInType == .manual else { return false }
            }
            if let yearFilter,
               Calendar.current.component(.year, from: visit.visitDate) != yearFilter {
                return false
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if visitRecords.isEmpty {
                            emptyState
                        } else {
                            searchCard
                            filterChips
                            if filteredRecords.isEmpty {
                                noMatchState
                            } else {
                            VStack(spacing: SuiSpacing.cardGap) {
                                ForEach(filteredRecords, id: \.id) { visit in
                                    if let aquarium = visit.aquarium {
                                        VisitRecordCard(
                                            visit: visit,
                                            aquarium: aquarium,
                                            theme: theme,
                                            onPhotoTap: {
                                                let images = visit.allPhotosData.compactMap { UIImage(data: $0) }
                                                guard !images.isEmpty else { return }
                                                photoToView = ViewedPhotos(images: images)
                                            }
                                        )
                                        .onTapGesture { selectedVisit = visit }
                                        .contextMenu {
                                            Button("編集") { selectedVisit = visit }
                                            Button("シェア") { visitToShare = visit }
                                            Button("削除", role: .destructive) {
                                                visitToDelete = visit
                                                showDeleteConfirmation = true
                                            }
                                        }
                                    }
                                }
                            }
                            }
                        }
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedVisit) { visit in
                EditVisitRecordView(visit: visit)
            }
            .sheet(item: $visitToShare) { visit in
                if let aquarium = visit.aquarium {
                    VisitShareSheet(visit: visit, aquarium: aquarium, theme: theme)
                        .presentationDetents([.medium, .large])
                }
            }
            .fullScreenCover(item: $photoToView) { photos in
                PhotoViewerView(images: photos.images, startIndex: photos.startIndex)
            }
            .sheet(isPresented: $showingAquariumPicker) {
                AquariumListView(
                    selectedAquarium: $pickerSelectedAquarium,
                    searchText: $pickerSearchText,
                    selectedRegions: $pickerSelectedRegions,
                    visitStatusFilter: $pickerVisitStatus,
                    regionOrder: regionOrder
                )
            }
            .sheet(item: $pickerSelectedAquarium) { aquarium in
                AquariumDetailView(aquarium: aquarium)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("訪問記録を削除", isPresented: $showDeleteConfirmation) {
                Button("キャンセル", role: .cancel) { visitToDelete = nil }
                Button("削除", role: .destructive) {
                    if let visit = visitToDelete { deleteVisit(visit) }
                    visitToDelete = nil
                }
            } message: {
                Text("この訪問記録を削除しますか？\nこの操作は取り消せません。")
            }
            .alert("削除に失敗しました", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isFiltering
                     ? "\(filteredRecords.count) / \(visitRecords.count) 件の記録"
                     : "\(visitRecords.count) 件の記録")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.midText)
                Text("訪問記録")
                    .font(SuiFont.screenTitle)
                    .foregroundColor(SuiColor.heading)
            }
            Spacer()
            Button {
                showingAquariumPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("追加")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(theme.primaryColor))
                .suiShadow(.primaryButton(primary: theme.primaryColor))
            }
        }
    }

    private var searchCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SuiColor.subText)
            TextField("水族館名・メモで検索", text: $searchText)
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

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecordTypeFilter.allCases) { filter in
                    Button {
                        typeFilter = filter
                    } label: {
                        chipLabel(filter.rawValue, selected: typeFilter == filter)
                    }
                }

                Menu {
                    Button("すべての年") { yearFilter = nil }
                    ForEach(availableYears, id: \.self) { year in
                        Button("\(String(year))年") { yearFilter = year }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(yearFilter.map { "\(String($0))年" } ?? "年: すべて")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(SuiFont.label)
                    .foregroundColor(yearFilter != nil ? .white : SuiColor.midText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(yearFilter != nil ? theme.primaryColor : SuiColor.cardSurface)
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            yearFilter != nil ? Color.clear : SuiColor.fieldBorder,
                            lineWidth: 1
                        )
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func chipLabel(_ text: String, selected: Bool) -> some View {
        Text(text)
            .font(SuiFont.label)
            .foregroundColor(selected ? .white : SuiColor.midText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? theme.primaryColor : SuiColor.cardSurface)
            )
            .overlay(
                Capsule().strokeBorder(
                    selected ? Color.clear : SuiColor.fieldBorder,
                    lineWidth: 1
                )
            )
    }

    private var noMatchState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(theme.primaryColor.opacity(0.5))
            Text("条件に一致する記録がありません")
                .font(SuiFont.body)
                .foregroundColor(SuiColor.midText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 56))
                .foregroundColor(theme.primaryColor.opacity(0.5))
            Text("まだ訪問記録がありません")
                .font(SuiFont.heading)
                .foregroundColor(SuiColor.heading)
            Text("水族館にチェックインして\n訪問記録を残そう！")
                .font(SuiFont.body)
                .foregroundColor(SuiColor.midText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func deleteVisit(_ visit: VisitRecord) {
        withAnimation {
            modelContext.delete(visit)
        }
        do {
            try modelContext.save()
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }
}

// MARK: - 訪問記録カード（リデザイン）

private struct VisitRecordCard: View {
    let visit: VisitRecord
    let aquarium: Aquarium
    let theme: Theme
    let onPhotoTap: () -> Void

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: visit.visitDate)
    }

    private var emoji: String {
        let n = aquarium.representativeFish.lowercased()
        if n.contains("whale") || n.contains("orca") { return "🐋" }
        if n.contains("penguin") { return "🐧" }
        if n.contains("shark") { return "🦈" }
        if n.contains("jellyfish") { return "🪼" }
        if n.contains("dolphin") { return "🐬" }
        return "🐠"
    }

    var body: some View {
        SuiCard(radius: SuiRadius.cardLarge, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                // 上段: アイコン + 名前/日付 + 矢印
                HStack(spacing: 12) {
                    photoOrEmoji
                    VStack(alignment: .leading, spacing: 4) {
                        Text(aquarium.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SuiColor.heading)
                            .lineLimit(1)
                        Text(dateString)
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                    }
                    Spacer()
                }

                // 中段: チェックインバッジ
                CheckInBadge(type: visit.checkInType)

                // 下段: メモ（あれば）
                if !visit.memo.isEmpty {
                    Text(visit.memo)
                        .font(SuiFont.body)
                        .foregroundColor(SuiColor.midText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.primaryBg)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private var photoOrEmoji: some View {
        if let data = visit.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    // 2枚以上ある場合は枚数バッジを表示
                    let count = visit.allPhotosData.count
                    if count > 1 {
                        Text("+\(count - 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .padding(3)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture { onPhotoTap() }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.primaryBg)
                    .frame(width: 50, height: 50)
                Text(emoji).font(.system(size: 26))
            }
        }
    }
}

#Preview {
    PassportView()
        .modelContainer(for: VisitRecord.self, inMemory: true)
        .environmentObject(ThemeManager())
}
