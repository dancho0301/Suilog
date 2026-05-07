//
//  CustomTabBar.swift
//  Suilog
//
//  デザイン仕様に合わせた自作タブバー。
//  iOS 26 の Liquid Glass 浮遊タブバーを避け、画面端まで伸びた
//  従来型のレイアウトを再現する。
//

import SwiftUI

struct CustomTabBarItem: Identifiable {
    let id: Int
    let title: String
    let icon: (Bool) -> AnyView
}

struct CustomTabBar: View {
    @Binding var selected: Int
    let items: [CustomTabBarItem]
    let primary: Color

    private let inactiveText = Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.5)
    private let topBorder = Color.black.opacity(0.08)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = item.id
                    }
                } label: {
                    VStack(spacing: 3) {
                        item.icon(selected == item.id)
                            .frame(height: 26)
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(selected == item.id ? primary : inactiveText)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.white.opacity(0.92))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(topBorder)
                .frame(height: 0.5)
        }
    }
}
