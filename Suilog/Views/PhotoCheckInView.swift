//
//  PhotoCheckInView.swift
//  Suilog
//
//  Created by Claude on 2026/02/05.
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct PhotoCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aquarium: Aquarium

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoMetadata: PhotoMetadata?
    @State private var memo = ""
    @State private var showingCamera = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoadingPhoto = false
    @State private var isCheckingIn = false

    /// 写真の位置情報が水族館の近く（1km以内）かどうか
    private var isPhotoLocationValid: Bool {
        guard let coordinate = photoMetadata?.coordinate else { return false }
        return PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)
    }

    /// 写真の位置情報から水族館までの距離（メートル）
    private var distanceFromPhoto: CLLocationDistance? {
        guard let coordinate = photoMetadata?.coordinate else { return nil }
        return PhotoMetadataExtractor.distance(from: coordinate, to: aquarium)
    }

    /// 判定されたチェックインタイプ
    private var determinedCheckInType: CheckInType {
        isPhotoLocationValid ? .location : .manual
    }

    /// 訪問日（写真の撮影日または現在日）
    private var visitDate: Date {
        if let dateTaken = photoMetadata?.dateTaken, dateTaken <= Date() {
            return dateTaken
        }
        return Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                // 写真選択セクション（必須）
                Section {
                    if isLoadingPhoto {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("写真を読み込み中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 100)
                            Spacer()
                        }
                    } else if let photoData = photoData,
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

                        // 写真の位置情報表示
                        if let metadata = photoMetadata {
                            PhotoLocationInfoView(
                                metadata: metadata,
                                aquarium: aquarium,
                                distance: distanceFromPhoto
                            )
                        }

                        Button(role: .destructive) {
                            self.photoData = nil
                            self.selectedPhoto = nil
                            self.photoMetadata = nil
                        } label: {
                            Label("写真を変更", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)

                            Text("水族館で撮影した写真を選択してください")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Label("写真を選択", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
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
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("写真（必須）")
                } footer: {
                    Text("写真の撮影日が訪問日に、位置情報からチェックインタイプが自動判定されます")
                        .font(.caption)
                }

                // 判定結果セクション（写真選択後に表示）
                if photoData != nil {
                    Section(header: Text("チェックイン情報")) {
                        // 訪問日
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("訪問日")
                            Spacer()
                            if photoMetadata?.dateTaken != nil {
                                Text(visitDate.formatted(Date.FormatStyle(date: .long).locale(Locale(identifier: "ja_JP"))))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("撮影日不明（本日）")
                                    .foregroundColor(.orange)
                            }
                        }

                        // チェックインタイプ
                        HStack {
                            Image(systemName: determinedCheckInType == .location ? "location.circle.fill" : "hand.tap")
                                .foregroundColor(determinedCheckInType == .location ? .yellow : .gray)
                            Text("チェックインタイプ")
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(determinedCheckInType.color)
                                Text(determinedCheckInType.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 判定理由
                        if isPhotoLocationValid {
                            Text("写真の撮影場所が水族館の近く（1km以内）のため、位置情報チェックイン（ゴールド）になります")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if photoMetadata?.hasLocation == true {
                            Text("写真の撮影場所が水族館から1km以上離れているため、手動チェックイン（シルバー）になります")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("写真に位置情報がないため、手動チェックイン（シルバー）になります")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("メモ（任意）")) {
                    TextEditor(text: $memo)
                        .frame(height: 100)
                }

                Section {
                    Button {
                        checkIn()
                    } label: {
                        HStack {
                            Spacer()
                            if isCheckingIn {
                                ProgressView()
                                    .tint(determinedCheckInType == .location ? .black : .white)
                                Text("チェックイン中...")
                            } else {
                                Image(systemName: "camera.circle.fill")
                                Text("写真でチェックインする")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(determinedCheckInType == .location ? .yellow : .gray)
                    .disabled(photoData == nil || isCheckingIn)
                }
            }
            .navigationTitle("写真でチェックイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard newValue != nil else { return }
                isLoadingPhoto = true
                Task { @MainActor in
                    defer { isLoadingPhoto = false }
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        // 先にEXIFメタデータを抽出（圧縮前の元データから）
                        let metadata = PhotoMetadataExtractor.extractMetadata(from: data)
                        photoMetadata = metadata

                        // 表示・保存用に圧縮
                        if let image = UIImage(data: data),
                           let compressedData = image.jpegData(compressionQuality: 0.8) {
                            photoData = compressedData
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(imageData: $photoData)
            }
            .alert("チェックイン完了！", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                let typeText = determinedCheckInType == .location ? "位置情報チェックイン（ゴールド）" : "手動チェックイン（シルバー）"
                Text("\(aquarium.name)に\(typeText)しました！")
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func checkIn() {
        isCheckingIn = true

        let visit = VisitRecord(
            visitDate: visitDate,
            memo: memo,
            photoData: photoData,
            checkInType: determinedCheckInType,
            aquarium: aquarium
        )
        modelContext.insert(visit)

        do {
            try modelContext.save()
            isCheckingIn = false
            showingSuccess = true
        } catch {
            print("❌ チェックインに失敗: \(error)")
            modelContext.rollback()
            isCheckingIn = false
            errorMessage = "チェックインの保存に失敗しました。\nもう一度お試しください。"
            showingError = true
        }
    }
}

#Preview {
    PhotoCheckInView(
        aquarium: Aquarium(
            name: "テスト水族館",
            latitude: 35.6812,
            longitude: 139.7671,
            description: "テスト用の水族館です",
            region: "東京"
        )
    )
    .modelContainer(for: VisitRecord.self, inMemory: true)
}
