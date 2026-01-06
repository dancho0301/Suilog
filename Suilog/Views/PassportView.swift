//
//  PassportView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData

struct PassportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VisitRecord.visitDate, order: .reverse) private var visitRecords: [VisitRecord]

    @State private var selectedVisit: VisitRecord?
    @State private var showDeleteConfirmation = false
    @State private var indexSetToDelete: IndexSet?

    var body: some View {
        NavigationStack {
            if visitRecords.isEmpty {
                // 訪問履歴がない場合
                ContentUnavailableView(
                    "まだ訪問記録がありません",
                    systemImage: "book.closed",
                    description: Text("水族館にチェックインして\n訪問記録を残そう！")
                )
            } else {
                List {
                    ForEach(visitRecords, id: \.id) { visit in
                        if let aquarium = visit.aquarium {
                            Button {
                                selectedVisit = visit
                            } label: {
                                VisitRecordRow(visit: visit, aquarium: aquarium)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSetToDelete = indexSet
                        showDeleteConfirmation = true
                    }
                }
                .navigationTitle("訪問記録")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                .sheet(item: $selectedVisit) { visit in
                    EditVisitRecordView(visit: visit)
                }
                .alert("訪問記録を削除", isPresented: $showDeleteConfirmation) {
                    Button("キャンセル", role: .cancel) {
                        indexSetToDelete = nil
                    }
                    Button("削除", role: .destructive) {
                        if let indexSet = indexSetToDelete {
                            deleteVisits(offsets: indexSet)
                        }
                        indexSetToDelete = nil
                    }
                } message: {
                    Text("この訪問記録を削除しますか？\nこの操作は取り消せません。")
                }
            }
        }
    }

    private func deleteVisits(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(visitRecords[index])
            }
        }
    }
}

struct VisitRecordRow: View {
    let visit: VisitRecord
    let aquarium: Aquarium

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 写真またはスタンプアイコン（チェックイン種別で色分け）
            if let photoData = visit.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(visit.checkInType.color, lineWidth: 2)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(visit.checkInType.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Group {
                        if isCustomAsset(aquarium.representativeFish) {
                            // カスタムアセット
                            Image(aquarium.representativeFish)
                                .renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                        } else {
                            // SF Symbols
                            Image(systemName: aquarium.representativeFish)
                                .font(.system(size: CGFloat(aquarium.fishIconSize * 6)))
                                .foregroundColor(visit.checkInType.color)
                        }
                    }
                }
            }

            // 訪問情報
            VStack(alignment: .leading, spacing: 4) {
                Text(aquarium.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(aquarium.region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(visit.visitDate.formatted(Date.FormatStyle(date: .numeric).year(.defaultDigits).month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ja_JP"))))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(visit.checkInType.color)
                    Text(visit.checkInType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !visit.memo.isEmpty {
                    Text(visit.memo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }

            Spacer()

            // 編集アイコン
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

/// SF Symbolsかカスタムアセットかを判定するヘルパー関数
/// SF Symbolsは必ず "." を含む（例: fish.fill, seal.fill）
/// カスタムアセットは "." を含まない（例: orca, Dolphin, freshwaterfish）
fileprivate func isCustomAsset(_ name: String) -> Bool {
    return !name.contains(".")
}

#Preview {
    PassportView()
        .modelContainer(for: VisitRecord.self, inMemory: true)
}
