import XCTest

final class XClientLabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsPerformanceModule() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["性能优化专项"].waitForExistence(timeout: 10),
            "The performance module header should be visible after launch"
        )
        XCTAssertTrue(app.staticTexts["选择实验入口"].exists)
    }

    @MainActor
    func testOpenCPUStallDrill() {
        let app = XCUIApplication()
        app.launch()

        let entry = app.buttons["perf.scenario.cpu"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "CPU drill entry should exist")
        entry.tap()

        XCTAssertTrue(
            app.navigationBars["1.1 CPU 卡顿"].waitForExistence(timeout: 5),
            "CPU drill should push its detail screen"
        )
        XCTAssertTrue(
            app.buttons["cpu.run"].waitForExistence(timeout: 6),
            "CPU drill should expose its run button"
        )
    }
}
