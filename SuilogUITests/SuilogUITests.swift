//
//  SuilogUITests.swift
//  SuilogUITests
//
//  Created by dancho on 2025/12/31.
//

import XCTest

final class SuilogUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// タブID（CustomTabBarのaccessibilityIdentifierに対応）
    private enum Tab: Int {
        case myTank = 0
        case map = 1
        case passport = 2
        case profile = 3
    }

    /// タブボタンをタップする
    private func tapTab(_ tab: Tab) {
        let button = app.buttons["tabButton_\(tab.rawValue)"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "タブ \(tab.rawValue) が存在するべき")
        button.tap()
    }

    /// 要素が表示されるまでスワイプでスクロールする
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    /// アプリを起動してタブが操作可能になるまで待つ
    /// （オンボーディングはUserDefaults引数でスキップ）
    private func launchAppAndWaitForTabs(extraArguments: [String] = []) {
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            let labels = [
                "1度だけ許可", "Appの使用中は許可", "許可",
                "Allow While Using App", "Allow Once", "Allow", "OK"
            ]
            for label in labels {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }

        app.launchArguments += ["-HasCompletedOnboarding", "YES"]
        app.launchArguments += extraArguments
        app.launch()

        // SpringBoardのアラートを処理
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemAlert = springboard.alerts.firstMatch
        if systemAlert.waitForExistence(timeout: 3) {
            let labels = ["1度だけ許可", "Appの使用中は許可", "許可", "Allow While Using App", "Allow Once", "Allow", "OK"]
            for label in labels {
                if systemAlert.buttons[label].exists {
                    systemAlert.buttons[label].tap()
                    break
                }
            }
        }

        // アプリのエラーアラートを処理（初回データ取得失敗など）
        let appAlert = app.alerts.firstMatch
        if appAlert.waitForExistence(timeout: 3) {
            if appAlert.buttons["キャンセル"].exists {
                appAlert.buttons["キャンセル"].tap()
            } else if appAlert.buttons["あとで"].exists {
                appAlert.buttons["あとで"].tap()
            }
        }

        XCTAssertTrue(
            app.buttons["tabButton_0"].waitForExistence(timeout: 15),
            "タブバーが表示されるべき"
        )
    }

    /// マップタブの「すべて見る」から水族館リストを開き、最初の水族館の詳細を表示する。
    /// データ未取得（オフライン等）の場合はテストをスキップする。
    private func openFirstAquariumDetail() throws {
        tapTab(.map)

        let seeAll = app.buttons["map.seeAllButton"]
        scrollTo(seeAll, maxSwipes: 3)
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "すべて見るボタンが存在するべき")
        seeAll.tap()

        // リスト表示（初回はFirebaseからのデータ取得を待つ）
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 20) else {
            throw XCTSkip("水族館データが取得できないためスキップ（ネットワーク未接続の可能性）")
        }
        firstCell.tap()

        // 詳細シートが開く（チェックインボタンの存在で確認）
        let manualButton = app.buttons["detail.manualCheckInButton"]
        scrollTo(manualButton)
        XCTAssertTrue(manualButton.waitForExistence(timeout: 10), "水族館詳細が表示されるべき")
    }

    // MARK: - アプリ起動テスト

    @MainActor
    func testAppLaunches() throws {
        launchAppAndWaitForTabs()
    }

    // MARK: - オンボーディングテスト

    @MainActor
    func testOnboarding_firstLaunchFlow() throws {
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments += ["-HasCompletedOnboarding", "NO"]
        app.launch()

        // 1ページ目が表示される
        let nextButton = app.buttons["onboarding.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10), "オンボーディングが表示されるべき")

        // 3回「次へ」で最終ページへ
        nextButton.tap()
        nextButton.tap()
        nextButton.tap()

        // 位置情報未設定なので「あとで設定する」が表示される
        let laterButton = app.buttons["onboarding.laterButton"]
        XCTAssertTrue(laterButton.waitForExistence(timeout: 5), "最終ページが表示されるべき")
        laterButton.tap()

        // メイン画面（タブバー）に遷移する
        XCTAssertTrue(app.buttons["tabButton_0"].waitForExistence(timeout: 10), "オンボーディング完了後にメイン画面が表示されるべき")
    }

    @MainActor
    func testOnboarding_skipButton() throws {
        app.launchArguments += ["-HasCompletedOnboarding", "NO"]
        app.launch()

        let skipButton = app.buttons["onboarding.skipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 10), "スキップボタンが表示されるべき")
        skipButton.tap()

        // 最終ページのいずれかのボタンで完了できる
        let laterButton = app.buttons["onboarding.laterButton"]
        let closeButton = app.buttons["onboarding.closeButton"]
        if laterButton.waitForExistence(timeout: 5) {
            laterButton.tap()
        } else if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        } else {
            XCTFail("最終ページの完了ボタンが見つからない")
        }

        XCTAssertTrue(app.buttons["tabButton_0"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testOnboarding_replayFromProfile() throws {
        launchAppAndWaitForTabs()
        tapTab(.profile)

        let replayButton = app.buttons["onboardingReplayButton"]
        scrollTo(replayButton)
        XCTAssertTrue(replayButton.waitForExistence(timeout: 5), "使い方を見るボタンが存在するべき")
        replayButton.tap()

        // オンボーディングが再表示される → スキップして最終ページから閉じる
        let skipButton = app.buttons["onboarding.skipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "オンボーディングが再表示されるべき")
        skipButton.tap()

        let closeButton = app.buttons["onboarding.closeButton"]
        let laterButton = app.buttons["onboarding.laterButton"]
        if closeButton.waitForExistence(timeout: 5) {
            closeButton.tap()
        } else if laterButton.waitForExistence(timeout: 3) {
            laterButton.tap()
        }

        // プロフィール画面に戻る
        XCTAssertTrue(replayButton.waitForExistence(timeout: 10), "プロフィールに戻るべき")
    }

    // MARK: - タブ切り替えテスト

    @MainActor
    func testTabNavigation_allTabs() throws {
        launchAppAndWaitForTabs()

        tapTab(.map)
        XCTAssertTrue(app.textFields["map.searchField"].waitForExistence(timeout: 5), "マップの検索欄が表示されるべき")

        tapTab(.passport)
        let passportTitle = app.staticTexts["訪問記録"]
        let addButton = app.buttons["passport.addButton"]
        XCTAssertTrue(passportTitle.waitForExistence(timeout: 5) || addButton.exists, "記録画面が表示されるべき")

        tapTab(.profile)
        XCTAssertTrue(app.buttons["themeStoreButton"].waitForExistence(timeout: 5) || app.staticTexts["獲得したバッジ"].exists, "プロフィール画面が表示されるべき")

        tapTab(.myTank)
        let emptyStateText = app.staticTexts["水族館に行って魚を見つけよう！"]
        let visitedText = app.staticTexts["訪問した水族館"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5) || visitedText.exists, "マイ水槽が表示されるべき")
    }

    // MARK: - チェックインフロー（E2E）

    @MainActor
    func testManualCheckInFlow() throws {
        launchAppAndWaitForTabs()
        try openFirstAquariumDetail()

        // 手動（シルバー）チェックイン
        app.buttons["detail.manualCheckInButton"].tap()

        // 新規記録フォームで保存（手動モードは常に保存可能）
        let saveButton = app.buttons["newRecord.saveButton"]
        scrollTo(saveButton, maxSwipes: 8)
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10), "保存ボタンが表示されるべき")
        saveButton.tap()

        // 完了アラート
        let successAlert = app.alerts["チェックイン完了！"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 10), "チェックイン完了アラートが表示されるべき")
        successAlert.buttons["OK"].tap()
    }

    @MainActor
    func testGoldCheckInViaDebugMenu() throws {
        launchAppAndWaitForTabs()

        // デバッグメニューで「常時チェックイン可能」をON（DEBUGビルドのみ）
        let debugButton = app.buttons["debugMenuButton"]
        guard debugButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("デバッグメニューが利用できないためスキップ（RELEASEビルド）")
        }
        debugButton.tap()

        let masterToggle = app.switches["debug.masterToggle"]
        XCTAssertTrue(masterToggle.waitForExistence(timeout: 5), "デバッグメニューが表示されるべき")
        if (masterToggle.value as? String) == "0" {
            masterToggle.switches.firstMatch.tap()
        }

        let alwaysToggle = app.switches["debug.alwaysCheckInToggle"]
        XCTAssertTrue(alwaysToggle.waitForExistence(timeout: 5), "チェックイン設定が表示されるべき")
        if (alwaysToggle.value as? String) == "0" {
            alwaysToggle.switches.firstMatch.tap()
        }
        app.buttons["閉じる"].tap()

        // 詳細を開いてゴールドチェックイン
        try openFirstAquariumDetail()
        let locationButton = app.buttons["detail.locationCheckInButton"]
        scrollTo(locationButton)
        XCTAssertTrue(locationButton.isEnabled, "常時チェックインONなら位置情報チェックインが有効のはず")
        locationButton.tap()

        let saveButton = app.buttons["newRecord.saveButton"]
        scrollTo(saveButton, maxSwipes: 8)
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        let successAlert = app.alerts["チェックイン完了！"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 10), "チェックイン完了アラートが表示されるべき")
        successAlert.buttons["OK"].tap()

        // 後始末: デバッグ設定を元に戻す（ベストエフォート）
        tapTab(.myTank)
        if debugButton.waitForExistence(timeout: 3) {
            debugButton.tap()
            if masterToggle.waitForExistence(timeout: 3), (masterToggle.value as? String) == "1" {
                masterToggle.switches.firstMatch.tap()
            }
            if app.buttons["閉じる"].exists {
                app.buttons["閉じる"].tap()
            }
        }
    }

    // MARK: - プロフィールテスト

    @MainActor
    func testNicknameEditor_opensAndCancels() throws {
        launchAppAndWaitForTabs()
        tapTab(.profile)

        let nicknameButton = app.buttons["nicknameEditButton"]
        XCTAssertTrue(nicknameButton.waitForExistence(timeout: 5), "ニックネーム編集ボタンが存在するべき")
        nicknameButton.tap()

        let alert = app.alerts["ニックネームを変更"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "ニックネーム編集アラートが表示されるべき")
        XCTAssertTrue(alert.textFields.firstMatch.exists, "入力欄が存在するべき")

        alert.buttons["キャンセル"].tap()
        XCTAssertFalse(alert.exists, "キャンセルでアラートが閉じるべき")
    }

    @MainActor
    func testThemeStoreButton_opensSheet() throws {
        launchAppAndWaitForTabs()
        tapTab(.profile)

        let themeButton = app.buttons["themeStoreButton"]
        XCTAssertTrue(themeButton.waitForExistence(timeout: 5), "テーマストアボタンが存在するべき")
        scrollTo(themeButton)
        themeButton.tap()

        let themeStoreTitle = app.staticTexts["テーマストア"]
        XCTAssertTrue(themeStoreTitle.waitForExistence(timeout: 5), "テーマストアが表示されるべき")

        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()

        XCTAssertTrue(themeButton.waitForExistence(timeout: 5))
    }

    // MARK: - 起動パフォーマンステスト

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments += ["-HasCompletedOnboarding", "YES"]
            app.launch()
        }
    }
}
