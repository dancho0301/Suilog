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

    /// タブボタンをタップする（iPhone/iPad両対応）
    /// iPadの Floating Tab Bar はボタンがネストされてXCTestで複数マッチするため、
    /// coordinate経由でタップすることで回避する
    private func tapTab(_ label: String) {
        let tabBarButton = app.tabBars.buttons[label].firstMatch
        if tabBarButton.exists {
            tabBarButton.tap()
            return
        }
        let button = app.buttons[label].firstMatch
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// タブボタンが存在するか確認
    private func tabExists(_ label: String) -> Bool {
        if app.tabBars.buttons[label].firstMatch.exists {
            return true
        }
        return app.buttons[label].firstMatch.exists
    }

    /// タブボタンが表示されるまで待つ
    private func waitForTab(_ label: String, timeout: TimeInterval = 15) -> Bool {
        let tabBarButton = app.tabBars.buttons[label].firstMatch
        if tabBarButton.waitForExistence(timeout: timeout) {
            return true
        }
        return app.buttons[label].firstMatch.waitForExistence(timeout: 3)
    }

    /// アプリを起動してタブが操作可能になるまで待つ
    private func launchAppAndWaitForTabs() {
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

        // アプリのエラーアラートを処理
        let appAlert = app.alerts.firstMatch
        if appAlert.waitForExistence(timeout: 3) {
            if appAlert.buttons["キャンセル"].exists {
                appAlert.buttons["キャンセル"].tap()
            }
        }

        // マイ水槽タブが表示されるまで待つ
        XCTAssertTrue(waitForTab("マイ水槽"), "タブが表示されるべき")
    }

    // MARK: - アプリ起動テスト

    @MainActor
    func testAppLaunches() throws {
        launchAppAndWaitForTabs()
    }

    // MARK: - タブ切り替えテスト

    @MainActor
    func testTabNavigation_myTank() throws {
        launchAppAndWaitForTabs()

        tapTab("マイ水槽")

        let emptyStateText = app.staticTexts["水族館に行って魚を見つけよう！"]
        let visitedText = app.staticTexts["訪問した水族館"]
        let exists = emptyStateText.waitForExistence(timeout: 5) || visitedText.exists
        XCTAssertTrue(exists, "マイ水槽の画面要素が表示されるべき")
    }

    @MainActor
    func testTabNavigation_map() throws {
        launchAppAndWaitForTabs()

        tapTab("マップ")

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "マップが表示されるべき")
    }

    @MainActor
    func testTabNavigation_passport() throws {
        launchAppAndWaitForTabs()

        tapTab("訪問記録")

        let emptyStateText = app.staticTexts["まだ訪問記録がありません"]
        let navTitle = app.navigationBars["訪問記録"]
        let exists = emptyStateText.waitForExistence(timeout: 5) || navTitle.exists
        XCTAssertTrue(exists, "訪問記録の画面要素が表示されるべき")
    }

    @MainActor
    func testTabSwitching_allTabs() throws {
        launchAppAndWaitForTabs()

        XCTAssertTrue(tabExists("マイ水槽"), "マイ水槽タブが存在するべき")
        XCTAssertTrue(tabExists("マップ"), "マップタブが存在するべき")
        XCTAssertTrue(tabExists("訪問記録"), "訪問記録タブが存在するべき")

        tapTab("マップ")
        sleep(1)
        tapTab("訪問記録")
        sleep(1)
        tapTab("マイ水槽")
        sleep(1)
    }

    // MARK: - テーマストアテスト

    @MainActor
    func testThemeStoreButton_opensSheet() throws {
        launchAppAndWaitForTabs()

        tapTab("マイ水槽")

        let themeButton = app.buttons["themeStoreButton"]
        XCTAssertTrue(themeButton.waitForExistence(timeout: 5), "テーマストアボタンが存在するべき")
        themeButton.tap()

        let themeStoreTitle = app.staticTexts["テーマストア"]
        XCTAssertTrue(themeStoreTitle.waitForExistence(timeout: 5), "テーマストアが表示されるべき")

        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()

        XCTAssertTrue(themeButton.waitForExistence(timeout: 5))
    }

    // MARK: - マップ画面テスト

    @MainActor
    func testMapView_listToggle() throws {
        launchAppAndWaitForTabs()

        tapTab("マップ")

        let listButton = app.buttons["list.bullet"]
        if listButton.waitForExistence(timeout: 5) {
            listButton.tap()
            sleep(1)

            let mapButton = app.buttons["map.fill"]
            if mapButton.exists {
                mapButton.tap()
            }
        }
    }

    // MARK: - 起動パフォーマンステスト

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
