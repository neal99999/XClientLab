import XCTest

final class XClientLabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 新演示结构：启动先看到“古法 vs AI”的对照，而不是模块清单。
    @MainActor
    func testLaunchShowsDemoComparison() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["同一个问题，两种排查"].waitForExistence(timeout: 10),
            "The AI-vs-traditional comparison should be the first screen"
        )
        XCTAssertTrue(app.buttons["demo.play"].exists, "Comparison should expose a playback button")
    }

    @MainActor
    func testDemoComparisonCanOpenRealDrill() {
        let app = XCUIApplication()
        app.launch()

        let open = app.buttons["demo.open"]
        tapWhenHittable(open, in: app)
        XCTAssertTrue(
            app.navigationBars["1.1 CPU 卡顿"].waitForExistence(timeout: 6),
            "The comparison CTA should push the selected real drill"
        )
    }

    @MainActor
    func testOpenCPUStallDrill() {
        let app = XCUIApplication()
        app.launch()

        openLabModule("lab.performance", in: app)
        let entry = app.buttons["perf.scenario.cpu"]
        tapWhenHittable(entry, in: app)

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

        openLabModule("lab.performance", in: app)
        tapWhenHittable(app.buttons["perf.scenario.cpu"], in: app)

        let runButton = app.buttons["cpu.run"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 6))
        XCTAssertEqual(runButton.label, "RUN BLOCKING WORK")
        runButton.tap()

        let finished = expectation(
            for: NSPredicate(format: "label == %@", "RUN BLOCKING WORK"),
            evaluatedWith: runButton
        )
        // 负载是 8 轮同步的 3MB JSON 解析 + 全文正则，按工作量计耗时；GitHub 的
        // runner 比本机慢得多，30s 会超时（run #4 验证）。仍然要求真的执行完并
        // 回到 IDLE，只是给慢环境留余量。
        wait(for: [finished], timeout: 90)
    }

    /// 回归：控制台在 `reset()` 清空日志时不能因为排队中的 publisher 回调
    /// 继续滚动旧行号而崩溃（UITableView NSInternalInconsistencyException）。
    @MainActor
    func testCPUStressRunThenResetDoesNotCrash() {
        let app = XCUIApplication()
        app.launch()

        openLabModule("lab.performance", in: app)
        tapWhenHittable(app.buttons["perf.scenario.cpu"], in: app)

        let runButton = app.buttons["cpu.run"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 6))
        runButton.tap()

        let resetButton = app.buttons["cpu.reset"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 6))
        // RUN 会阻塞主线程；这个点击会被排队到本轮结束后执行，正好覆盖
        // “日志已写入、reset 清空、旧 entries 回调仍在队列中”的时序。
        resetButton.tap()

        let idle = expectation(
            for: NSPredicate(format: "label == %@", "RUN BLOCKING WORK"),
            evaluatedWith: runButton
        )
        wait(for: [idle], timeout: 90)
    }

    /// 核心业务链路 2：盘口推送从 START 到 STOP 的状态切换。
    @MainActor
    func testOrderBookStreamingStartsAndStops() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["tab.lab"].tap()
        tapWhenHittable(app.buttons["lab.exchange"], in: app)
        tapWhenHittable(app.buttons["exc.scenario.book"], in: app)

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

    // MARK: - Navigation helpers

    @MainActor
    private func openLabModule(_ moduleIdentifier: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons["tab.lab"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Lab tab should exist")
        tab.tap()
        tapWhenHittable(app.buttons[moduleIdentifier], in: app)
    }

    /// 卡片在滚动页里，XCUITest 不会自动滚动；统一用 swipe 找到可点击位置。
    @MainActor
    private func tapWhenHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 5
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), "\(element) should exist")
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "\(element) should become hittable after scrolling")
        element.tap()
    }
}
