//
//  NewVisitRecordView.swift
//  Suilog
//
//  デザイン仕様 §4 新規訪問記録フォームに合わせた統合チェックインフォーム。
//  ゴールド（位置情報）/ シルバー（手動）を 1 画面のトグルで切り替える。
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct NewVisitRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var locationManager: LocationManager

    let aquarium: Aquarium
    /// 画面起動時のデフォルトモード
    let initialMode: CheckInType

    @State private var mode: CheckInType
    @State private var visitDate = Date()
    @State private var memo = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photosData: [Data] = []
    @State private var photoMetadatas: [PhotoMetadata] = []
    @State private var cameraPhotoData: Data?
    @State private var photoToView: ViewedPhotos?
    @State private var showingCamera = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoadingPhoto = false
    @State private var isSaving = false

    init(aquarium: Aquarium, initialMode: CheckInType = .location) {
        self.aquarium = aquarium
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    private var theme: Theme { themeManager.currentTheme }

    private var canLocationCheckIn: Bool {
        locationManager.isWithinRange(of: aquarium, radius: 1000)
    }

    /// いずれかの写真の撮影場所が1km圏内か
    private var isPhotoLocationValid: Bool {
        photoMetadatas.contains { metadata in
            guard let coordinate = metadata.coordinate else { return false }
            return PhotoMetadataExtractor.isWithinRange(coordinate: coordinate, of: aquarium)
        }
    }

    /// 位置情報を持つ写真のうち、水族館に最も近いものの距離
    private var distanceFromPhoto: CLLocationDistance? {
        photoMetadatas
            .compactMap { metadata in
                metadata.coordinate.map { PhotoMetadataExtractor.distance(from: $0, to: aquarium) }
            }
            .min()
    }

    /// 最終的に保存されるチェックインタイプ
    /// - ゴールドモード: .location（1km 圏内で有効化済みのため）
    /// - シルバーモード: 写真 Exif が 1km 圏内なら .location に自動昇格
    private var finalCheckInType: CheckInType {
        if mode == .location { return .location }
        return isPhotoLocationValid ? .location : .manual
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        methodToggleCard
                        aquariumCard
                        if mode == .manual {
                            dateCard
                        }
                        photoCard
                        if mode == .manual, !photosData.isEmpty {
                            typeResultCard
                        }
                        memoCard
                        saveButton
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("新規訪問記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(SuiColor.midText)
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                guard !newItems.isEmpty else { return }
                isLoadingPhoto = true
                Task { @MainActor in
                    defer {
                        isLoadingPhoto = false
                        selectedPhotos = []
                    }
                    for item in newItems {
                        guard photosData.count < VisitRecord.maxPhotoCount else { break }
                        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                        addPhoto(data)
                    }
                }
            }
            .onChange(of: cameraPhotoData) { _, newValue in
                guard let data = newValue else { return }
                cameraPhotoData = nil
                addPhoto(data)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(imageData: $cameraPhotoData)
            }
            .fullScreenCover(item: $photoToView) { photos in
                PhotoViewerView(images: photos.images, startIndex: photos.startIndex)
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

    // MARK: - Method Toggle

    private var methodToggleCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("チェックイン方法")
                HStack(spacing: 10) {
                    methodOption(
                        type: .location,
                        emoji: "📍",
                        title: "ゴールド",
                        subtitle: canLocationCheckIn ? "現地で記録" : "1km圏内のみ"
                    )
                    methodOption(
                        type: .manual,
                        emoji: "📷",
                        title: "シルバー",
                        subtitle: "写真＆日付"
                    )
                }

                if mode == .location, !canLocationCheckIn {
                    Text("※ 水族館から1km以内でのみ利用できます。シルバーチェックインを選んでください。")
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.goldText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SuiColor.goldBg)
                        )
                }
            }
        }
    }

    private func methodOption(
        type: CheckInType,
        emoji: String,
        title: String,
        subtitle: String
    ) -> some View {
        let selected = mode == type
        let disabled = (type == .location && !canLocationCheckIn)

        return Button {
            guard !disabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) { mode = type }
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 24))
                Text(title)
                    .font(SuiFont.bodyMedium)
                    .foregroundColor(selected ? theme.primaryColor : SuiColor.heading)
                Text(subtitle)
                    .font(SuiFont.caption)
                    .foregroundColor(SuiColor.subText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? theme.primaryBg : SuiColor.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selected ? theme.primaryColor : SuiColor.fieldBorder,
                        lineWidth: selected ? 2 : 1
                    )
            )
            .opacity(disabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Aquarium Card

    private var aquariumCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("水族館")
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.primaryBg)
                            .frame(width: 44, height: 44)
                        Text(aquariumEmoji).font(.system(size: 22))
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

    private var aquariumEmoji: String {
        let n = aquarium.representativeFish.lowercased()
        if n.contains("whale") || n.contains("orca") { return "🐋" }
        if n.contains("penguin") { return "🐧" }
        if n.contains("shark") { return "🦈" }
        if n.contains("jellyfish") { return "🪼" }
        if n.contains("dolphin") { return "🐬" }
        return "🐠"
    }

    // MARK: - Date Card (manual only)

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

    // MARK: - Photo Card

    private var photoCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("写真（任意・最大\(VisitRecord.maxPhotoCount)枚）")

                if !photosData.isEmpty {
                    PhotoThumbnailGrid(
                        photos: photosData,
                        onTap: { index in
                            let images = photosData.compactMap { UIImage(data: $0) }
                            photoToView = ViewedPhotos(images: images, startIndex: index)
                        },
                        onDelete: { index in
                            photosData.remove(at: index)
                            if index < photoMetadatas.count {
                                photoMetadatas.remove(at: index)
                            }
                        }
                    )

                    if mode == .manual {
                        photoMetaRow
                    }
                }

                if isLoadingPhoto {
                    loadingTile
                } else if photosData.count < VisitRecord.maxPhotoCount {
                    photoUploadArea
                    if mode == .manual, photosData.isEmpty {
                        Text("撮影日時と位置情報からチェックインタイプを自動判定します")
                            .font(SuiFont.caption)
                            .foregroundColor(SuiColor.subText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var photoMetaRow: some View {
        let hasAnyLocation = photoMetadatas.contains { $0.hasLocation }
        let firstDateTaken = photoMetadatas.compactMap { $0.dateTaken }.first

        VStack(alignment: .leading, spacing: 6) {
            if hasAnyLocation, let d = distanceFromPhoto {
                HStack(spacing: 6) {
                    Image(systemName: d <= 1000 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(d <= 1000 ? .green : .orange)
                    Text(d <= 1000 ? "位置情報あり" : "位置情報あり（範囲外）")
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.heading)
                    Text("・水族館まで \(formatDistance(d))")
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.subText)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash").foregroundColor(SuiColor.subText)
                    Text("位置情報なし")
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.subText)
                }
            }
            if let dateTaken = firstDateTaken {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").foregroundColor(SuiColor.subText)
                    Text("撮影日時: \(formatDate(dateTaken))")
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.subText)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SuiColor.fieldBg)
        )
    }

    private var typeResultCard: some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("自動判定結果")
                    Spacer()
                    CheckInBadge(type: finalCheckInType)
                }
                Text(resultMessage)
                    .font(SuiFont.caption)
                    .foregroundColor(SuiColor.midText)
            }
        }
    }

    private var resultMessage: String {
        if isPhotoLocationValid {
            return "写真の撮影場所が1km以内のため、ゴールドチェックインになります。"
        } else if photoMetadatas.contains(where: { $0.hasLocation }) {
            return "写真の撮影場所が1km以上離れているため、シルバーチェックインになります。"
        } else {
            return "写真に位置情報がないため、シルバーチェックインになります。"
        }
    }

    // MARK: - Memo

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

    // MARK: - Upload tiles

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
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: VisitRecord.maxPhotoCount - photosData.count,
                matching: .images
            ) {
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

    // MARK: - Save

    private var saveButton: some View {
        let disabled = isSaving || (mode == .location && !canLocationCheckIn)
        return Button { save() } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                    Text("保存中...")
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
                    .fill(disabled ? theme.primaryColor.opacity(0.4) : theme.primaryColor)
            )
            .suiShadow(.primaryButton(primary: theme.primaryColor))
        }
        .disabled(disabled)
        .accessibilityIdentifier("newRecord.saveButton")
        .padding(.top, 4)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(SuiFont.tinyLabel)
            .tracking(0.5)
            .foregroundColor(SuiColor.subText)
            .textCase(.uppercase)
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 { return String(format: "%.0fm", distance) }
        return String(format: "%.1fkm", distance / 1000)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }

    /// 写真を圧縮して追加し、メタデータを抽出する
    @MainActor
    private func addPhoto(_ data: Data) {
        guard photosData.count < VisitRecord.maxPhotoCount else { return }
        let metadata = PhotoMetadataExtractor.extractMetadata(from: data)
        // 訪問日の自動設定は最初の1枚のみ反映する
        if mode == .manual, photosData.isEmpty, let dateTaken = metadata.dateTaken, dateTaken <= Date() {
            visitDate = dateTaken
        }
        guard let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.8) else { return }
        photosData.append(compressed)
        photoMetadatas.append(metadata)
    }

    private func save() {
        isSaving = true
        let visit = VisitRecord(
            visitDate: mode == .location ? Date() : visitDate,
            memo: memo,
            photoData: photosData.first,
            additionalPhotosData: photosData.count > 1 ? Array(photosData.dropFirst()) : nil,
            checkInType: finalCheckInType,
            aquarium: aquarium
        )
        modelContext.insert(visit)
        do {
            try modelContext.save()
            isSaving = false
            showingSuccess = true
        } catch {
            modelContext.rollback()
            isSaving = false
            errorMessage = "チェックインの保存に失敗しました。\nもう一度お試しください。"
            showingError = true
        }
    }
}

#Preview {
    NewVisitRecordView(
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
    .environmentObject(LocationManager())
}
