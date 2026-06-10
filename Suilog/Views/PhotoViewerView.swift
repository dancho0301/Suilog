//
//  PhotoViewerView.swift
//  Suilog
//
//  訪問記録の写真をフルスクリーンで拡大表示するビューア。
//  複数枚の場合は横スワイプでページングできる。
//

import SwiftUI

/// fullScreenCover(item:) で表示するための写真ラッパー
struct ViewedPhotos: Identifiable {
    let id = UUID()
    let images: [UIImage]
    var startIndex: Int = 0

    init(images: [UIImage], startIndex: Int = 0) {
        self.images = images
        self.startIndex = startIndex
    }

    init(image: UIImage) {
        self.init(images: [image])
    }
}

/// ピンチズーム・ダブルタップズーム・ページング対応のフルスクリーン写真ビューア
struct PhotoViewerView: View {
    let images: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(images: [UIImage], startIndex: Int = 0) {
        self.images = images
        _currentIndex = State(initialValue: min(max(startIndex, 0), max(images.count - 1, 0)))
    }

    init(image: UIImage) {
        self.init(images: [image])
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImageView(image: images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                if images.count > 1 {
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(SuiFont.bodyMedium)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.leading, 20)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(16)
                }
            }
        }
    }
}

// MARK: - ズーム可能な1枚表示

private struct ZoomableImageView: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4
    private let doubleTapScale: CGFloat = 2.5

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnificationGesture)
            .simultaneousGesture(dragGesture)
            .onTapGesture(count: 2) {
                toggleZoom()
            }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    resetPosition()
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // 拡大中のみパン可能
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if scale > minScale {
                resetPosition()
            } else {
                scale = doubleTapScale
                lastScale = doubleTapScale
            }
        }
    }

    private func resetPosition() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }
}
