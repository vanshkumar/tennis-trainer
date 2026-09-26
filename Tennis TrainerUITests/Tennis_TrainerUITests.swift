//
//  Tennis_TrainerUITests.swift
//  Tennis TrainerUITests
//
//  Created by Vansh Kumar on 8/20/25.
//

import XCTest

final class Tennis_TrainerUITests: XCTestCase {
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
