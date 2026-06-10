//
//  PhotoThumbnailGrid.swift
//  Suilog
//
//  訪問記録フォームで使う写真サムネイルのグリッド表示。
//  タップで拡大表示、×ボタンで個別削除できる。
//

import SwiftUI

struct PhotoThumbnailGrid: View {
    let photos: [Data]
    let onTap: (Int) -> Void
    let onDelete: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(photos.indices, id: \.self) { index in
                if let ui = UIImage(data: photos[index]) {
                    thumbnail(ui, index: index)
                }
            }
        }
    }

    private func thumbnail(_ image: UIImage, index: Int) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { onTap(index) }
            .overlay(alignment: .topTrailing) {
                Button {
                    onDelete(index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .padding(4)
                }
            }
    }
}
