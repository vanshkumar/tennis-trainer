//
//  Tennis_TrainerUITests.swift
//  Tennis TrainerUITests
//
//  Created by Vansh Kumar on 8/20/25.
//

import XCTest

final class Tennis_TrainerUITests: XCTestCase {
    @MainActor
    func testBackhandSetupAndDrillSwitchControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--practice-ui-scenario", "playback-overlay"]
        app.launch()
        app.buttons["Backhand"].tap()
        let ready = app.buttons["backhand.ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 5))
        XCTAssertFalse(ready.isEnabled)
        app.buttons["camera.captureAction"].tap()
        XCTAssertTrue(ready.isEnabled)
        let live = XCTAttachment(screenshot: app.screenshot())
        live.name = "Backhand live setup"; live.lifetime = .keepAlways; add(live)
        ready.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'capturing in'")).firstMatch.exists)
        app.buttons["camera.captureAction"].tap()
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'capturing in'")).firstMatch.exists)
        XCTAssertFalse(app.buttons["backhand.checkpoint"].isEnabled)
        app.buttons["Video Playback"].tap()
        XCTAssertTrue(ready.isEnabled)
        XCTAssertTrue(app.buttons["+0.03s"].isEnabled)
        app.buttons["+0.03s"].tap()
        assertLabel(app.staticTexts["playback.status"], "Paused")
        let video = XCTAttachment(screenshot: app.screenshot())
        video.name = "Backhand video setup"; video.lifetime = .keepAlways; add(video)
        app.buttons["Serve"].tap()
        XCTAssertFalse(ready.exists)
        XCTAssertTrue(app.buttons["playback.action"].isEnabled)
    }

    @MainActor
    func testVideoImportRecoveryControls() throws {
        let app = XCUIApplication()
        for scenario in ["playback-import", "playback-import-empty"] {
            app.launchArguments = ["--practice-ui-scenario", scenario]
            app.launch()
            app.buttons["Video Playback"].tap()
            let choose = app.buttons["playback.choose"]
            XCTAssertTrue(choose.waitForExistence(timeout: 5))
            choose.tap(); app.buttons["import.cancel"].tap()
            assertLabel(app.staticTexts["playback.importMessage"], scenario == "playback-import"
              ? "Video selection cancelled. Your previous video is ready to play."
              : "Video selection cancelled. Choose another video.")
            XCTAssertTrue(choose.isEnabled)
            XCTAssertEqual(app.buttons["playback.action"].exists, scenario == "playback-import")
            choose.tap(); app.buttons["import.failure"].tap()
            XCTAssertTrue(app.buttons["playback.cancelImport"].waitForExistence(timeout: 3))
            if scenario == "playback-import" { XCTAssertFalse(app.sliders["playback.slider"].isEnabled) }
            assertLabel(app.staticTexts["playback.importMessage"], scenario == "playback-import"
              ? "Video could not be imported. Your previous video is ready to play."
              : "Video could not be imported. Choose another video.")
            if scenario == "playback-import" {
                XCTAssertEqual(app.staticTexts["playback.status"].label, "Paused")
                XCTAssertTrue(app.buttons["playback.action"].isEnabled)
                XCTAssertTrue(app.sliders["playback.slider"].isEnabled)
            }
            choose.tap(); app.buttons["import.success"].tap()
            XCTAssertTrue(app.buttons["playback.cancelImport"].waitForExistence(timeout: 3))
            assertLabel(app.staticTexts["playback.status"], "Paused")
            let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback.action"])
            wait(for: [enabled], timeout: 5)
            XCTAssertTrue(app.sliders["playback.slider"].isEnabled)
            app.buttons["playback.action"].tap()
            assertLabel(app.staticTexts["playback.status"], "Playing")
            choose.tap(); app.buttons["import.success"].tap()
            let cancel = app.buttons["playback.cancelImport"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 3)); cancel.tap()
            assertLabel(app.staticTexts["playback.importMessage"], "Video selection cancelled. Your previous video is ready to play.")
            XCTAssertTrue(app.buttons["playback.action"].isEnabled)
            XCTAssertTrue(app.sliders["playback.slider"].isEnabled)
            XCTAssertEqual(app.staticTexts["playback.status"].label, "Paused")
            app.terminate()
        }
    }

    @MainActor
    func testShortClipSliderUsesActualDurationAndAccessibleTime() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--practice-ui-scenario", "playback-short"]
        app.launch()
        app.buttons["Video Playback"].tap()
        let slider = app.sliders["playback.slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(slider.label, "Playback position")
        slider.adjust(toNormalizedSliderPosition: 0.5)
        assertLabel(app.staticTexts["playback.status"], "Paused")
        let value = try XCTUnwrap(slider.value as? String)
        XCTAssertTrue(value.hasSuffix("of 0.5 seconds"))
        let elapsed = try XCTUnwrap(Double(value.split(separator: " ")[0]))
        XCTAssertGreaterThan(elapsed, 0.1)
        XCTAssertLessThan(elapsed, 0.4)
        slider.adjust(toNormalizedSliderPosition: 1)
        assertLabel(app.staticTexts["playback.status"], "Paused")
        XCTAssertEqual(slider.value as? String, "0.5 seconds of 0.5 seconds")
    }

    @MainActor
    func testVisibleOverlayClearOnStopAndPause() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--practice-ui-scenario", "playback-overlay"]
        app.launch()
        let ball = app.descendants(matching: .any)["practice.ballOverlay"].firstMatch
        let pose = app.descendants(matching: .any)["practice.poseOverlay"].firstMatch
        app.buttons["camera.captureAction"].tap()
        XCTAssertTrue(ball.waitForExistence(timeout: 5)); XCTAssertTrue(pose.exists)
        app.buttons["camera.captureAction"].tap()
        XCTAssertFalse(ball.exists); XCTAssertFalse(pose.exists)
        app.buttons["Video Playback"].tap()
        app.buttons["playback.action"].tap()
        XCTAssertTrue(ball.waitForExistence(timeout: 5)); XCTAssertTrue(pose.exists)
        app.buttons["playback.action"].tap()
        XCTAssertFalse(ball.exists); XCTAssertFalse(pose.exists)
        XCTAssertEqual(app.staticTexts["playback.status"].label, "Paused")
    }
    @MainActor
    func testPlaybackEndAndReplayControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--practice-ui-scenario", "playback-end"]
        app.launch()
        app.buttons["Video Playback"].tap()
        let action = app.buttons["playback.action"]
        let status = app.staticTexts["playback.status"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        assertLabel(status, "Ended")
        XCTAssertEqual(action.label, "Replay")
        action.tap()
        assertLabel(status, "Seeking…")
        XCTAssertEqual(action.label, "Pause")
        action.tap()
        assertLabel(status, "Paused")
        XCTAssertEqual(action.label, "Play")
        XCTAssertEqual(app.staticTexts["playback.position"].label, "0:00")
        action.tap()
        assertLabel(status, "Ended")
        action.tap()
        assertLabel(status, "Seeking…")
        assertLabel(status, "Playing")
        XCTAssertEqual(action.label, "Pause")
        XCTAssertEqual(app.staticTexts["playback.position"].label, "0:00")
    }

    @MainActor
    func testPlaybackSeekControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--practice-ui-scenario", "playback-seek"]
        app.launch()
        app.buttons["Video Playback"].tap()
        let action = app.buttons["playback.action"]
        let status = app.staticTexts["playback.status"]
        let slider = app.sliders["playback.slider"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        assertLabel(status, "Playing")
        slider.adjust(toNormalizedSliderPosition: 0.5)
        assertLabel(status, "Seeking…")
        XCTAssertEqual(action.label, "Pause")
        action.tap()
        XCTAssertEqual(action.label, "Play")
        assertLabel(status, "Paused")
        XCTAssertNotEqual(app.staticTexts["playback.position"].label, "0:00")
        slider.adjust(toNormalizedSliderPosition: 0.75)
        assertLabel(status, "Seeking…")
        action.tap()
        XCTAssertEqual(action.label, "Pause")
        assertLabel(status, "Playing")
    }

    @MainActor
    func testCameraStopDuringStartupAndRecovery() throws {
        let app = XCUIApplication()
        for scenario in ["capture-startup", "capture-recovery"] {
            app.launchArguments = ["--practice-ui-scenario", scenario]
            app.launch()
            let action = app.buttons["camera.captureAction"]
            let status = app.staticTexts["camera.captureStatus"]
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            action.tap()
            if scenario == "capture-recovery" {
                assertLabel(status, "Status: Running")
                assertLabel(status, "Status: Interrupted")
                XCTAssertEqual(action.label, "Stop")
                XCTAssertTrue(action.isEnabled)
                assertLabel(status, "Status: Recovering…")
            } else {
                assertLabel(status, "Status: Starting…")
            }
            XCTAssertEqual(action.label, "Stop")
            XCTAssertTrue(action.isEnabled)
            action.tap()
            assertLabel(status, "Status: Stopped")
            XCTAssertEqual(action.label, "Start")
            let lateRunning = expectation(for: NSPredicate(format: "label == %@", "Status: Running"),
              evaluatedWith: status)
            lateRunning.isInverted = true
            wait(for: [lateRunning], timeout: 5)
            action.tap()
            assertLabel(status, "Status: Running")
            app.terminate()
        }

        app.launchArguments = ["--practice-ui-scenario", "capture-failure"]
        app.launch()
        let action = app.buttons["camera.captureAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        assertLabel(app.staticTexts["camera.captureStatus"], "Status: Failed: Camera could not start")
        XCTAssertEqual(action.label, "Retry")
        action.tap()
        assertLabel(app.staticTexts["camera.captureStatus"], "Status: Running")
    }

    @MainActor
    private func assertLabel(_ element: XCUIElement, _ text: String) {
        let expected = expectation(for: NSPredicate(format: "label == %@", text), evaluatedWith: element)
        wait(for: [expected], timeout: 8)
    }

    @MainActor
    func testCameraPermissionControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--practice-ui-scenario", "permission-undetermined"]
        app.launch()
        let permission = app.buttons["camera.permissionAction"]
        XCTAssertTrue(permission.waitForExistence(timeout: 5))
        XCTAssertEqual(permission.label, "Request Permission")
        permission.tap()
        XCTAssertEqual(app.staticTexts["camera.permissionStatus"].label, "Requesting access…")
        XCTAssertFalse(permission.isEnabled)
        let capture = app.buttons["camera.captureAction"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        XCTAssertEqual(capture.label, "Start")
        capture.tap()
        XCTAssertEqual(capture.label, "Stop")
        capture.tap()
        XCTAssertEqual(capture.label, "Start")
        app.terminate()

        app.launchArguments = ["--practice-ui-scenario", "permission-denied-return"]
        app.launch()
        XCTAssertTrue(permission.waitForExistence(timeout: 5))
        XCTAssertEqual(permission.label, "Open Settings")
        permission.tap()
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        XCTAssertEqual(capture.label, "Start")
        XCTAssertEqual(app.staticTexts["camera.captureStatus"].label, "Status: Stopped")
        app.terminate()

        app.launchArguments = ["--practice-ui-scenario", "permission-restricted"]
        app.launch()
        XCTAssertTrue(app.staticTexts["camera.permissionStatus"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["camera.permissionStatus"].label, "Camera access is restricted")
        XCTAssertFalse(permission.exists)
        XCTAssertFalse(capture.exists)
        XCTAssertTrue(app.staticTexts["Camera access is controlled by device restrictions. Contact the device owner or administrator."].exists)
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
