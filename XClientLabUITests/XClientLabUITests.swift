import XCTest

final class XClientLabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 新演示结构：启动直接进入「交易所专项」主线，而不是模块清单或通用对照表。
    @MainActor
    func testLaunchShowsExchangeStory() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.navigationBars["交易所专项"].waitForExistence(timeout: 10),
            "The exchange story should be the first screen"
        )
        XCTAssertTrue(app.buttons["case.render"].exists, "Case 01 should expose its replay entry")
        XCTAssertTrue(app.buttons["case.network"].exists, "Case 02 should expose its replay entry")
    }

    /// 第 3 个 Tab：交付与防线。验证六态资产卡片、审查过滤、收敛状态机与 Git Flow / 提交规范。
    @MainActor
    func testDeliveryGuardTabInteractiveDemos() {
        let app = XCUIApplication()
        app.launch()

        let candidates = [
            app.tabBars.buttons["tab.delivery"],
            app.tabBars.buttons["交付与防线"],
            app.buttons["tab.delivery"],
            app.buttons["交付与防线"]
        ]
        guard let tab = candidates.first(where: { $0.waitForExistence(timeout: 4) }) else {
            attachAccessibilityDump(app, name: "app-tree-tab-delivery-missing")
            XCTFail("Delivery tab should exist (identifier `tab.delivery` or label `交付与防线`)")
            return
        }
        tab.tap()

        XCTAssertTrue(
            app.navigationBars["交付与防线"].waitForExistence(timeout: 8),
            "Delivery tab should push its own navigation title"
        )
        XCTAssertTrue(app.staticTexts["全流程交付与防线"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.otherElements["metric.stages"].exists)
        attachScreenshot(app, name: "delivery-initial")

        // 审查治理：原始噪音 → 过滤后只剩 P0 BLOCKER 与 P1。
        tapWhenHittable(app.buttons["review.mode.filtered"], in: app, maxSwipes: 20)
        XCTAssertTrue(
            app.otherElements["review.comment.p0.retain-cycle"].waitForExistence(timeout: 4),
            "Filtered mode must surface the P0 retain-cycle blocker"
        )
        XCTAssertTrue(
            app.otherElements["review.comment.p0.retain-cycle"].label.contains("P0 BLOCKER"),
            "The P0 blocker tag must be visible"
        )
        attachScreenshot(app, name: "delivery-filtered")

        // 收敛状态机：三次步进后第 4 轮熔断。
        tapWhenHittable(app.buttons["review.mode.converged"], in: app, maxSwipes: 20)
        for _ in 0 ..< 3 {
            tapWhenHittable(app.buttons["review.step"], in: app, maxSwipes: 20)
        }
        XCTAssertTrue(
            app.otherElements["review.round.04"].waitForExistence(timeout: 4),
            "The 4th round must display the circuit breaker row"
        )
        attachScreenshot(app, name: "delivery-converged")

        // 资产六态：Extreme 的超长数字、Empty 的充值入口、Debounce 的防抖窗口。
        tapWhenHittable(app.buttons["asset.state.extreme"], in: app, maxSwipes: 24)
        XCTAssertTrue(
            app.staticTexts["123456789012345678901234567890.12"].waitForExistence(timeout: 4),
            "Extreme state must render the 30-digit amount"
        )
        attachScreenshot(app, name: "delivery-extreme")

        tapWhenHittable(app.buttons["asset.state.empty"], in: app, maxSwipes: 24)
        XCTAssertTrue(app.buttons["asset.empty.cta"].waitForExistence(timeout: 4))

        tapWhenHittable(app.buttons["asset.state.debounce"], in: app, maxSwipes: 24)
        tapWhenHittable(app.buttons["asset.refresh"], in: app, maxSwipes: 24)
        XCTAssertNotEqual(
            app.staticTexts["asset.debounce.accepted"].label,
            "0",
            "The first refresh must be accepted"
        )
        XCTAssertTrue(app.otherElements["asset.snapshot.badge"].exists)
        attachScreenshot(app, name: "delivery-debounce")
    }

    /// Git Flow 与 Conventional Commits：独立验证，避免长链路测试掩盖滚动失败。
    @objc @MainActor
    func testDeliveryGuardGitFlowAndCommits() {
        let app = XCUIApplication()
        app.launch()

        let tab = app.tabBars.buttons["tab.delivery"]
        if tab.waitForExistence(timeout: 4) {
            tab.tap()
        } else {
            app.buttons["交付与防线"].tap()
        }
        XCTAssertTrue(app.navigationBars["交付与防线"].waitForExistence(timeout: 8))

        let gitFlowTitle = app.staticTexts["分支、提交与发布纪律"]
        for _ in 0 ..< 40 {
            if gitFlowTitle.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(gitFlowTitle.isHittable, "Git Flow section must be reachable by scrolling")
        attachScreenshot(app, name: "delivery-gitflow")

        let branchTitle = app.staticTexts["五条分支的角色边界"]
        for _ in 0 ..< 12 {
            if branchTitle.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(branchTitle.isHittable, "Branch role card must render")
        attachScreenshot(app, name: "delivery-gitflow-branches")

        let releaseTitle = app.staticTexts["发布与热修标准动作"]
        for _ in 0 ..< 20 {
            if releaseTitle.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(releaseTitle.isHittable, "Release playbook card must render")
        attachScreenshot(app, name: "delivery-gitflow-release")

        let commitExample = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "feat(auth): add WeChat login support")
        ).firstMatch
        for _ in 0 ..< 30 {
            if commitExample.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(
            commitExample.isHittable,
            "Conventional Commits card must render the feat example"
        )
        attachScreenshot(app, name: "delivery-commits")
    }

    /// 主线必须能从“现象/难点/方案”直接进入可交互复盘。
    @MainActor
    func testExchangeStoryOpensRenderCase() {
        let app = XCUIApplication()
        app.launch()

        tapWhenHittable(app.buttons["case.render"], in: app)
        XCTAssertTrue(
            app.navigationBars["01 渲染性能重构"].waitForExistence(timeout: 6),
            "Case 01 CTA should push the rendering replay"
        )
        XCTAssertTrue(app.buttons["render.toggle"].waitForExistence(timeout: 6))
    }

    /// 核心业务链路：注入“HTTP 迟到、状态倒流”事件，版本号保护必须保持已成交。
    @MainActor
    func testConsistencyCaseRejectsStaleOrderEvent() {
        let app = XCUIApplication()
        app.launch()

        let networkCase = app.buttons["case.network"]
        XCTAssertTrue(networkCase.waitForExistence(timeout: 10), "Case 02 should be on the first screen")
        tapWhenHittable(networkCase, in: app)
        if !app.navigationBars["02 弱网与一致性"].waitForExistence(timeout: 3) {
            networkCase.tap()
        }
        XCTAssertTrue(app.navigationBars["02 弱网与一致性"].waitForExistence(timeout: 6))

        let inject = app.buttons["net.race"]
        tapWhenHittable(inject, in: app)
        XCTAssertTrue(
            app.staticTexts["已成交 (filled) · seq=12"].waitForExistence(timeout: 4),
            "WS filled event should move the order to filled first"
        )
        let rejected = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "旧版本")
        ).firstMatch
        XCTAssertTrue(
            rejected.waitForExistence(timeout: 4),
            "The stale HTTP event must be rejected instead of rolling the state back"
        )
    }

    /// 性能实验室先给“五条优化链路”，再落到可运行的 CPU/Alloc 实测。
    @MainActor
    func testPerformancePlaybookShowsFiveAreasAndLaunchDiagnostics() {
        let app = XCUIApplication()
        app.launch()

        openLabModule("lab.performance", in: app)
        XCTAssertTrue(
            app.buttons["perf.topic.launch"].waitForExistence(timeout: 8),
            "Launch topic should be the first optimization area"
        )

        let cpuTopic = app.buttons["perf.topic.cpu"]
        var swipes = 0
        while !cpuTopic.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(cpuTopic.exists, "All five optimization areas should exist")

        app.swipeDown()
        app.swipeDown()
        tapWhenHittable(app.buttons["perf.topic.launch"], in: app)
        XCTAssertTrue(app.navigationBars["启动速度与包大小"].waitForExistence(timeout: 6))
        XCTAssertTrue(
            app.staticTexts["本次启动的现场数字"].waitForExistence(timeout: 4),
            "Launch topic should show live pre-main diagnostics"
        )
        XCTAssertFalse(app.staticTexts["0 ms"].exists, "Cold start must not be the stale static 0ms value")
        XCTAssertFalse(app.staticTexts["40 KB"].exists, "Bundle size must not be the stale executable-only 40KB value")
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

        openLabModule("lab.performance", in: app)
        tapWhenHittable(app.buttons["perf.topic.network"], in: app)
        tapWhenHittable(app.buttons["perf.evidence.book"], in: app)

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

    /// iOS 26/27 模拟器的 XCUITest 快照里，`app.tabBars` 可能拿不到按钮
    /// （CI 上 identifier 和 label 都查不到，但首屏导航栏正常），所以多级候选：
    /// tabBars 里的 identifier / label → 全局任意位置的 identifier / label。
    @MainActor
    private func labTabCandidates(in app: XCUIApplication) -> [XCUIElement] {
        [
            app.tabBars.buttons["tab.lab"],
            app.tabBars.buttons["实验室"],
            app.buttons["tab.lab"],
            app.buttons["实验室"]
        ]
    }

    /// 保留截图，便于失败时定位布局与状态。
    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 把整棵无障碍树 dump 成附件，tab 查不到时用日志对症。
    @MainActor
    private func attachAccessibilityDump(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openLabIndex(in app: XCUIApplication) {
        let tab = labTabCandidates(in: app).first { $0.waitForExistence(timeout: 4) }
        guard let tab else {
            attachAccessibilityDump(app, name: "app-tree-tab-lab-missing")
            XCTFail("Lab tab should exist (identifier `tab.lab` or label `实验室`) — see app-tree-tab-lab-missing attachment")
            return
        }
        tab.tap()
        let entry = app.buttons["lab.performance"]
        // 启动转场期间点击可能被吞掉;索引没出现时补点一次再等。
        if !entry.waitForExistence(timeout: 5) {
            tab.tap()
            if !entry.waitForExistence(timeout: 10) {
                attachAccessibilityDump(app, name: "app-tree-lab-index-missing")
            }
        }
        XCTAssertTrue(
            entry.waitForExistence(timeout: 15),
            "Lab index should finish pushing before opening its modules"
        )
    }

    @MainActor
    private func openLabModule(_ moduleIdentifier: String, in app: XCUIApplication) {
        openLabIndex(in: app)
        tapWhenHittable(app.buttons[moduleIdentifier], in: app)
    }

    /// 卡片在滚动页里，XCUITest 不会自动滚动；统一用 swipe 找到可点击位置。
    @MainActor
    private func tapWhenHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 12
    ) {
        // 卡片在 UIScrollView 里时，离屏元素可能暂时不在无障碍树中；
        // 先滚动再查询，避免 waitForExistence 在首屏直接判失败。
        var swipes = 0
        while swipes <= maxSwipes {
            if element.exists, element.isHittable {
                element.tap()
                return
            }
            app.swipeUp()
            swipes += 1
        }

        // 长页面可能已经滑过目标卡片；反向再找一遍，避免把“滑过头”
        // 误判成“元素不存在”。
        swipes = 0
        while swipes <= maxSwipes {
            if element.exists, element.isHittable {
                element.tap()
                return
            }
            app.swipeDown()
            swipes += 1
        }

        XCTAssertTrue(element.exists, "\(element) should exist after scrolling")
        if element.isHittable {
            element.tap()
        } else {
            // CI 慢机器/新 runtime 的无障碍快照可能始终报 isHittable == false；
            // 元素确实存在时按 frame 坐标点击，并夹在屏幕可视区域内。
            let frame = element.frame
            let window = app.frame
            let x = min(max(frame.midX, window.minX + 10), window.maxX - 10)
            let y = min(max(frame.midY, window.minY + 80), window.maxY - 80)
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: x - window.minX, dy: y - window.minY))
                .tap()
        }
    }
}
