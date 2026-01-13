//
//  EditVisitRecordView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditVisitRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var visit: VisitRecord

    @State private var visitDate: Date
    @State private var memo: String
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingDiscardAlert = false

    /// 変更があるかどうかを判定
    private var hasChanges: Bool {
        visitDate != visit.visitDate ||
        memo != visit.memo ||
        photoData != visit.photoData
    }

    init(visit: VisitRecord) {
        self.visit = visit
        _visitDate = State(initialValue: visit.visitDate)
        _memo = State(initialValue: visit.memo)
        _photoData = State(initialValue: visit.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("訪問日")) {
                    DatePicker(
                        "日付を選択",
                        selection: $visitDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section(header: Text("写真")) {
                    if let photoData = photoData,
                       let uiImage = UIImage(data: photoData) {
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                            Spacer()
                        }

                        Button(role: .destructive) {
                            self.photoData = nil
                            self.selectedPhoto = nil
                        } label: {
                            Label("写真を削除", systemImage: "trash")
                        }
                    } else {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("写真を選択", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showingCamera = true
                            } label: {
                                Label("撮影", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section(header: Text("メモ")) {
                    TextEditor(text: $memo)
                        .frame(height: 100)
                }

                Section(header: Text("チェックイン種別")) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(visit.checkInType.color)
                        Text(visit.checkInType.displayName)
                    }
                }
            }
            .navigationTitle("訪問記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                }
            }
            .alert("変更を破棄しますか？", isPresented: $showingDiscardAlert) {
                Button("編集を続ける", role: .cancel) { }
                Button("破棄", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("保存されていない変更があります。")
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { @MainActor in
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let compressedData = image.jpegData(compressionQuality: 0.8) {
                        photoData = compressedData
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(imageData: $photoData)
            }
        }
    }

    private func saveChanges() {
        visit.visitDate = visitDate
        visit.memo = memo
        visit.photoData = photoData

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 保存に失敗: \(error)")
        }
    }
}

#Preview {
    EditVisitRecordView(
        visit: VisitRecord(
            visitDate: Date(),
            memo: "テストメモ",
            checkInType: .location
        )
    )
    .modelContainer(for: VisitRecord.self, inMemory: true)
}
