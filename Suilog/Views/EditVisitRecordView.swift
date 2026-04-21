//
//  EditVisitRecordView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//  Redesigned per design_handoff_suilog spec (edit mode).
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditVisitRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @Bindable var visit: VisitRecord

    @State private var visitDate: Date
    @State private var memo: String
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingDiscardAlert = false
    @State private var showingSaveErrorAlert = false
    @State private var saveErrorMessage = ""

    private var hasChanges: Bool {
        visitDate != visit.visitDate ||
        memo != visit.memo ||
        photoData != visit.photoData
    }

    private var theme: Theme { themeManager.currentTheme }

    init(visit: VisitRecord) {
        self.visit = visit
        _visitDate = State(initialValue: visit.visitDate)
        _memo = State(initialValue: visit.memo)
        _photoData = State(initialValue: visit.photoData)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        checkInInfoCard
                        aquariumCard
                        dateCard
                        memoCard
                        photoCard
                        saveButton
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("訪問記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        if hasChanges { showingDiscardAlert = true } else { dismiss() }
                    }
                    .foregroundColor(SuiColor.midText)
                }
            }
            .alert("変更を破棄しますか？", isPresented: $showingDiscardAlert) {
                Button("編集を続ける", role: .cancel) { }
                Button("破棄", role: .destructive) { dismiss() }
            } message: {
                Text("保存されていない変更があります。")
            }
            .alert("保存に失敗しました", isPresented: $showingSaveErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { @MainActor in
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let compressed = image.jpegData(compressionQuality: 0.8) {
                        photoData = compressed
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(imageData: $photoData)
            }
        }
    }

    // MARK: - Sections

    private var checkInInfoCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            HStack {
                fieldLabel("チェックイン方法")
                Spacer()
                CheckInBadge(type: visit.checkInType)
            }
        }
    }

    @ViewBuilder
    private var aquariumCard: some View {
        if let aquarium = visit.aquarium {
            SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("水族館")
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.primaryBg)
                                .frame(width: 44, height: 44)
                            Text("🐠").font(.system(size: 22))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(aquarium.name)
                                .font(SuiFont.bodyMedium)
                                .foregroundColor(SuiColor.heading)
                            Text(aquarium.region)
                                .font(SuiFont.caption)
                                .foregroundColor(SuiColor.subText)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var dateCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("訪問日")
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(theme.primaryColor)
                }
                DatePicker(
                    "",
                    selection: $visitDate,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(theme.primaryColor)
            }
        }
    }

    private var memoCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("メモ")
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SuiColor.fieldBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(SuiColor.fieldBorder, lineWidth: 1)
                        )
                    if memo.isEmpty {
                        Text("訪問時の感想をメモしよう")
                            .font(SuiFont.body)
                            .foregroundColor(SuiColor.subText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $memo)
                        .font(SuiFont.body)
                        .foregroundColor(SuiColor.heading)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .frame(minHeight: 100)
            }
        }
    }

    @ViewBuilder
    private var photoCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("写真")
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(role: .destructive) {
                        photoData = nil
                        selectedPhoto = nil
                    } label: {
                        Label("写真を削除", systemImage: "trash")
                            .font(SuiFont.label)
                    }
                } else {
                    photoUploadArea
                }
            }
        }
    }

    private var photoUploadArea: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                uploadTile(icon: "photo.on.rectangle", label: "選択")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showingCamera = true
                } label: {
                    uploadTile(icon: "camera", label: "撮影")
                }
            }
        }
    }

    private func uploadTile(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.primaryColor)
            Text(label)
                .font(SuiFont.label)
                .foregroundColor(SuiColor.midText)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SuiColor.fieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            theme.primaryLight,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                        )
                )
        )
    }

    private var saveButton: some View {
        Button {
            saveChanges()
        } label: {
            Text("記録を保存する 🐠")
                .font(SuiFont.bodyMedium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                        .fill(hasChanges ? theme.primaryColor : theme.primaryColor.opacity(0.5))
                )
                .suiShadow(.primaryButton(primary: theme.primaryColor))
        }
        .disabled(!hasChanges)
        .padding(.top, 4)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(SuiFont.tinyLabel)
            .tracking(0.5)
            .foregroundColor(SuiColor.subText)
            .textCase(.uppercase)
    }

    private func saveChanges() {
        visit.visitDate = visitDate
        visit.memo = memo
        visit.photoData = photoData

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveErrorAlert = true
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
    .environmentObject(ThemeManager())
}
