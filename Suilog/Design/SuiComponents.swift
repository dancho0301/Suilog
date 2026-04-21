//
//  SuiComponents.swift
//  Suilog
//
//  デザイン仕様の共通UIコンポーネント。
//

import SwiftUI

/// 白背景・角丸・標準シャドウの共通カード
struct SuiCard<Content: View>: View {
    let radius: CGFloat
    let padding: CGFloat
    let content: Content

    init(
        radius: CGFloat = SuiRadius.cardMedium,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(SuiColor.cardSurface)
            )
            .suiShadow(.card)
    }
}

/// チェックイン種別を示すpill形状のバッジ
struct CheckInBadge: View {
    let type: CheckInType

    var body: some View {
        HStack(spacing: 4) {
            Text(type == .location ? "🥇" : "🥈")
                .font(.system(size: 12))
            Text(type == .location ? "ゴールド" : "シルバー")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.3)
        }
        .foregroundColor(type == .location ? SuiColor.goldText : SuiColor.silverText)
        .padding(.vertical, 3)
        .padding(.horizontal, 10)
        .background(
            Capsule().fill(type == .location ? SuiColor.goldBg : SuiColor.silverBg)
        )
        .overlay(
            Capsule().strokeBorder(
                type == .location ? SuiColor.goldBorder : SuiColor.silverBorder,
                lineWidth: 1
            )
        )
    }
}

/// 「セクション名」＋ 右端リンクのヘッダー
struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(SuiFont.section)
                .foregroundColor(SuiColor.heading)
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title, trailing: { EmptyView() })
    }
}

/// 統計バー内の1項目（数値＋ラベル）
struct StatItem: View {
    let value: String
    let label: String
    let primary: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SuiFont.stat)
                .foregroundColor(primary)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(SuiColor.subText)
        }
        .frame(maxWidth: .infinity)
    }
}
