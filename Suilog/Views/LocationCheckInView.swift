//
//  LocationCheckInView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//  Redesigned per design_handoff_suilog spec.
//

import SwiftUI
import SwiftData
import PhotosUI

struct LocationCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let aquarium: Aquarium

    @State private var memo = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingCamera = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoadingPhoto = false
    @State private var isCheckingIn = false

    private var theme: Theme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        methodCard
                        aquariumCard
                        memoCard
                        photoCard
                        saveButton
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("位置情報チェックイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(SuiColor.midText)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard newValue != nil else { return }
                isLoadingPhoto = true
                Task { @MainActor in
                    defer { isLoadingPhoto = false }
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
            .alert("チェックイン完了！", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(aquarium.name)にチェックインしました！")
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage) }
        }
    }

    private var methodCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            HStack(spacing: 12) {
                Text("📍").font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ゴールドチェックイン")
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(SuiColor.heading)
                    Text("現地でGPS確認済み")
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.midText)
                }
                Spacer()
                CheckInBadge(type: .location)
            }
        }
    }

    private var aquariumCard: some View {
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

    private var memoCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("メモ（任意）")
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

    private var photoCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("写真（任意）")
                if isLoadingPhoto {
                    loadingTile
                } else if let data = photoData, let ui = UIImage(data: data) {
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

    private var loadingTile: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                ProgressView().scaleEffect(1.3)
                Text("写真を読み込み中...")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.midText)
            }
            Spacer()
        }
        .frame(height: 100)
    }

    private var photoUploadArea: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                uploadTile(icon: "photo.on.rectangle", label: "選択")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showingCamera = true } label: {
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
        Button { checkIn() } label: {
            HStack(spacing: 8) {
                if isCheckingIn {
                    ProgressView().tint(.white)
                    Text("チェックイン中...")
                } else {
                    Text("記録を保存する 🐠")
                }
            }
            .font(SuiFont.bodyMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                    .fill(theme.primaryColor)
            )
            .suiShadow(.primaryButton(primary: theme.primaryColor))
        }
        .disabled(isCheckingIn)
        .padding(.top, 4)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(SuiFont.tinyLabel)
            .tracking(0.5)
            .foregroundColor(SuiColor.subText)
            .textCase(.uppercase)
    }

    private func checkIn() {
        isCheckingIn = true
        let visit = VisitRecord(
            memo: memo,
            photoData: photoData,
            checkInType: .location,
            aquarium: aquarium
        )
        modelContext.insert(visit)
        do {
            try modelContext.save()
            isCheckingIn = false
            showingSuccess = true
        } catch {
            modelContext.rollback()
            isCheckingIn = false
            errorMessage = "チェックインの保存に失敗しました。\nもう一度お試しください。"
            showingError = true
        }
    }
}

// カメラ用のImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    LocationCheckInView(
        aquarium: Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト用の水族館です",
            region: "東京"
        )
    )
    .modelContainer(for: VisitRecord.self, inMemory: true)
    .environmentObject(ThemeManager())
}
