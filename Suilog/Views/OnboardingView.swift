//
//  OnboardingView.swift
//  Suilog
//
//  初回起動時にアプリの使い方を紹介するオンボーディング画面。
//

import SwiftUI

/// 初回起動時に表示するオンボーディング画面
struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var locationManager: LocationManager

    /// オンボーディング完了済みフラグのUserDefaultsキー
    static let hasCompletedKey = "HasCompletedOnboarding"

    /// オンボーディング完了時に呼ばれる
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let lastPageIndex = 3

    private var theme: Theme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            theme.primaryBg.ignoresSafeArea()

            VStack(spacing: 0) {
                skipButton

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    checkInPage.tag(1)
                    collectionPage.tag(2)
                    locationPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                pageIndicator
                    .padding(.bottom, 24)

                bottomButtons
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - ヘッダー

    private var skipButton: some View {
        HStack {
            Spacer()
            if currentPage < lastPageIndex {
                Button("スキップ") {
                    currentPage = lastPageIndex
                }
                .font(SuiFont.bodyMedium)
                .foregroundColor(SuiColor.midText)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, SuiSpacing.screenHorizontal)
        .padding(.top, 8)
    }

    // MARK: - ページ

    private var welcomePage: some View {
        pageLayout(
            icon: "fish.fill",
            title: "スイログへようこそ！",
            description: "日本全国の水族館をめぐって、\nあなただけの訪問記録をつくるアプリです。\nマップから行きたい水族館を探してみましょう。"
        )
    }

    private var checkInPage: some View {
        pageLayout(
            icon: "mappin.and.ellipse",
            title: "2種類のチェックイン",
            description: "訪問の記録方法は2つあります。"
        ) {
            VStack(spacing: SuiSpacing.cardGap) {
                checkInExplainCard(
                    type: .location,
                    text: "水族館から1km以内にいるとき、\n位置情報でチェックインできます"
                )
                checkInExplainCard(
                    type: .manual,
                    text: "過去の思い出は日付を選んで記録。\n位置情報付きの写真ならゴールドになることも"
                )
            }
            .padding(.horizontal, SuiSpacing.screenHorizontal)
        }
    }

    private var collectionPage: some View {
        pageLayout(
            icon: "sparkles",
            title: "思い出を集めよう",
            description: "訪問するたびに、楽しみが増えていきます。"
        ) {
            VStack(spacing: SuiSpacing.cardGap) {
                featureRow(
                    icon: "camera.fill",
                    title: "写真とメモ",
                    caption: "訪問ごとに写真とメモを残せます"
                )
                featureRow(
                    icon: "fish.fill",
                    title: "マイ水槽",
                    caption: "訪問した水族館の代表の魚が水槽で泳ぎます"
                )
                featureRow(
                    icon: "medal.fill",
                    title: "バッジと統計",
                    caption: "訪問数に応じてバッジやランクを獲得できます"
                )
            }
            .padding(.horizontal, SuiSpacing.screenHorizontal)
        }
    }

    private var locationPage: some View {
        pageLayout(
            icon: "location.fill",
            title: "位置情報について",
            description: "位置情報チェックインと、近くの水族館の表示に\n位置情報を使用します。"
        ) {
            SuiCard(radius: SuiRadius.cardMedium, padding: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 22))
                        .foregroundColor(theme.primaryColor)
                    Text("位置情報は端末内での距離計算のみに使われ、外部に送信されることはありません。")
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.midText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, SuiSpacing.screenHorizontal)
        }
    }

    // MARK: - ページ共通レイアウト

    private func pageLayout(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        pageLayout(icon: icon, title: title, description: description) {
            EmptyView()
        }
    }

    @ViewBuilder
    private func pageLayout<Extra: View>(
        icon: String,
        title: String,
        description: String,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.primaryLight.opacity(0.45))
                    .frame(width: 130, height: 130)
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundColor(theme.primaryColor)
            }

            Text(title)
                .font(SuiFont.screenTitle)
                .foregroundColor(SuiColor.heading)
                .multilineTextAlignment(.center)

            Text(description)
                .font(SuiFont.body)
                .foregroundColor(SuiColor.midText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SuiSpacing.screenHorizontal)

            extra()

            Spacer()
        }
    }

    private func checkInExplainCard(type: CheckInType, text: String) -> some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                CheckInBadge(type: type)
                Text(text)
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.midText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func featureRow(icon: String, title: String, caption: String) -> some View {
        SuiCard(radius: SuiRadius.cardMedium, padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(SuiColor.heading)
                    Text(caption)
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.midText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    // MARK: - フッター

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0...lastPageIndex, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? theme.primaryColor : SuiColor.tabInactive.opacity(0.5))
                    .frame(width: index == currentPage ? 20 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
    }

    @ViewBuilder
    private var bottomButtons: some View {
        if currentPage < lastPageIndex {
            Button {
                currentPage += 1
            } label: {
                Text("次へ")
                    .font(SuiFont.bodyMedium)
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                            .fill(theme.primaryColor)
                    )
            }
            .suiShadow(.primaryButton(primary: theme.primaryColor))
        } else {
            VStack(spacing: 12) {
                Button {
                    locationManager.requestPermission()
                    onComplete()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.circle.fill")
                        Text("位置情報を許可してはじめる")
                            .font(SuiFont.bodyMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                            .fill(theme.primaryColor)
                    )
                }
                .suiShadow(.primaryButton(primary: theme.primaryColor))

                Button {
                    onComplete()
                } label: {
                    Text("あとで設定する")
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(SuiColor.midText)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(ThemeManager())
        .environmentObject(LocationManager())
}
