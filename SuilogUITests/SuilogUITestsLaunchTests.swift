//
//  SuilogUITestsLaunchTests.swift
//  SuilogUITests
//
//  Created by dancho on 2025/12/31.
//

import XCTest

final class SuilogUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// アプリを起動してタブが操作可能になるまで待つ
    /// （オンボーディングはUserDefaults引数でスキップ）
    private func launchAndWaitForTabs() -> XCUIApplication {
        let app = XCUIApplication()

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

        // タブが出るまで待つ
        _ = app.buttons["tabButton_0"].waitForExistence(timeout: 15)

        return app
    }

    @MainActor
    func testLaunch() throws {
        let app = launchAndWaitForTabs()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunch_mapTab() throws {
        let app = launchAndWaitForTabs()

        app.buttons["tabButton_1"].tap()
        sleep(2)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Map Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunch_passportTab() throws {
        let app = launchAndWaitForTabs()

        app.buttons["tabButton_2"].tap()
        sleep(1)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Passport Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
