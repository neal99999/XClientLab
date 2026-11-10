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

    /// 核心业务链路 1：主线程风暴必须真的执行完并回到可再次触发的 IDLE。
    @MainActor
    func testCPUStallRunCompletesAndReturnsToIdle() {
        let app = XCUIApplication()
        app.launch()

        let entry = app.buttons["perf.scenario.cpu"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        let runButton = app.buttons["cpu.run"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 6))
        XCTAssertEqual(runButton.label, "RUN BLOCKING WORK")
        runButton.tap()

        let finished = expectation(
            for: NSPredicate(format: "label == %@", "RUN BLOCKING WORK"),
            evaluatedWith: runButton
        )
        wait(for: [finished], timeout: 30)
    }

    /// 核心业务链路 2：盘口推送从 START 到 STOP 的状态切换。
    @MainActor
    func testOrderBookStreamingStartsAndStops() {
        let app = XCUIApplication()
        app.launch()

        let exchangeTab = app.tabBars.buttons["tab.exchange"]
        XCTAssertTrue(exchangeTab.waitForExistence(timeout: 10), "Exchange tab should exist")
        exchangeTab.tap()

        let entry = app.buttons["exc.scenario.book"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8), "Order book entry should exist")
        entry.tap()
        XCTAssertTrue(
            app.navigationBars["3.2 Order Book"].waitForExistence(timeout: 6),
            "Order book detail should be pushed"
        )

        let toggle = app.buttons["book.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 6))
        XCTAssertEqual(toggle.label, "START FEED")
        toggle.tap()

        let streaming = expectation(
            for: NSPredicate(format: "label == %@", "STOP FEED"),
            evaluatedWith: toggle
        )
        wait(for: [streaming], timeout: 8)

        toggle.tap()
        let stopped = expectation(
            for: NSPredicate(format: "label == %@", "START FEED"),
            evaluatedWith: toggle
        )
        wait(for: [stopped], timeout: 8)
    }
}
