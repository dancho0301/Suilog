//
//  LocationCheckInView.swift
//  Suilog
//
//  Created by dancho on 2025/12/31.
//

import SwiftUI
import SwiftData
import PhotosUI

struct LocationCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aquarium: Aquarium

    @State private var memo = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingCamera = false
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("写真（任意）")) {
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
                            Image(systemName: "location.circle.fill")
                            Text("チェックインする")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                }
            }
            .navigationTitle("位置情報チェックイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
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
            .alert("チェックイン完了！", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\(aquarium.name)にチェックインしました！")
            }
        }
    }

    private func checkIn() {
        let visit = VisitRecord(
            memo: memo,
            photoData: photoData,
            checkInType: .location,
            aquarium: aquarium
        )
        modelContext.insert(visit)

        do {
            try modelContext.save()
            showingSuccess = true
        } catch {
            print("❌ チェックインに失敗: \(error)")
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

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
}
