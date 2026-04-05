//
//  YourTubeUITests.swift
//  YourTubeUITests
//
//  Created by Aaron Carámbula on 3/22/26.
//

import XCTest

final class YourTubeUITests: XCTestCase {

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
    func testRootControlsExist() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["layoutToggleButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["accountButton"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
