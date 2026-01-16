//
//  ManualCheckInView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct ManualCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aquarium: Aquarium

    @State private var visitDate = Date()
    @State private var memo = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoMetadata: PhotoMetadata?
    @State private var useLocationCheckIn = false
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

                Section(header: Text("写真（任意）")) {
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
                            self.useLocationCheckIn = false
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
                }

                // 写真の位置情報が有効な場合、チェックインタイプを選択可能
                if isPhotoLocationValid {
                    Section(header: Text("チェックインタイプ")) {
                        Toggle(isOn: $useLocationCheckIn) {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("位置情報チェックイン")
                                        .font(.body)
                                    Text("写真の撮影場所が水族館の近くです")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .tint(.yellow)
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
                                    .tint(useLocationCheckIn ? .black : .white)
                                Text("チェックイン中...")
                            } else {
                                Image(systemName: useLocationCheckIn ? "location.circle.fill" : "checkmark.circle.fill")
                                Text("チェックインする")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(useLocationCheckIn ? .yellow : .gray)
                    .disabled(isCheckingIn)

                    if useLocationCheckIn {
                        Text("写真の位置情報を使って位置情報チェックイン（ゴールド）を行います")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("手動チェックイン")
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

                        // 撮影日時があれば訪問日に設定
                        if let dateTaken = metadata.dateTaken, dateTaken <= Date() {
                            visitDate = dateTaken
                        }

                        // 位置情報が有効な場合は自動的に位置情報チェックインを有効化
                        if let coordinate = metadata.coordinate,
                           PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium) {
                            useLocationCheckIn = true
                        }

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
                Text("\(aquarium.name)にチェックインしました！")
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

        // 位置情報チェックインが有効で、写真の位置情報が有効な場合はlocationタイプ
        let checkInType: CheckInType = useLocationCheckIn && isPhotoLocationValid ? .location : .manual

        let visit = VisitRecord(
            visitDate: visitDate,
            memo: memo,
            photoData: photoData,
            checkInType: checkInType,
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

/// 写真の位置情報を表示するビュー
struct PhotoLocationInfoView: View {
    let metadata: PhotoMetadata
    let aquarium: Aquarium
    let distance: CLLocationDistance?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 位置情報の状態表示
            HStack(spacing: 8) {
                if metadata.hasLocation {
                    if let distance = distance {
                        if distance <= 1000 {
                            // 1km以内 - 有効
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("位置情報あり")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("水族館まで\(formatDistance(distance))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // 1km以上 - 無効
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("位置情報あり（範囲外）")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("水族館まで\(formatDistance(distance))（1km以内で有効）")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Image(systemName: "location.slash")
                        .foregroundColor(.secondary)
                    Text("位置情報なし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 撮影日時の表示
            if let dateTaken = metadata.dateTaken {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("撮影日時: \(formatDate(dateTaken))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    ManualCheckInView(
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
