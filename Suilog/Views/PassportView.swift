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
    @State private var showDeleteConfirmation = false
    @State private var visitToDelete: VisitRecord?
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showingAquariumPicker = false
    @State private var pickerSelectedAquarium: Aquarium?
    @State private var pickerSearchText = ""
    @State private var pickerSelectedRegions: Set<String> = []
    @State private var pickerVisitStatus: VisitStatus = .all

    private let regionOrder: [String] = [
        "北海道", "東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"
    ]

    private var theme: Theme { themeManager.currentTheme }

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
                            VStack(spacing: SuiSpacing.cardGap) {
                                ForEach(visitRecords, id: \.id) { visit in
                                    if let aquarium = visit.aquarium {
                                        VisitRecordCard(
                                            visit: visit,
                                            aquarium: aquarium,
                                            theme: theme
                                        )
                                        .onTapGesture { selectedVisit = visit }
                                        .contextMenu {
                                            Button("編集") { selectedVisit = visit }
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
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedVisit) { visit in
                EditVisitRecordView(visit: visit)
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
                Text("\(visitRecords.count) 件の記録")
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
