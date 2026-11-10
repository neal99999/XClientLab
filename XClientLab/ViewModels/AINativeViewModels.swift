import Combine
import Foundation
import UIKit

// MARK: - Scenario 4.2 · Terminal-first automation

enum AutomationArtifactKind: String, CaseIterable, Identifiable {
    case xctest = "XCTest 桩"
    case lldb = "LLDB 断点"
    case mcp = "MCP 指令"
    case prWorkflow = "PR 工作流"
    case mcpConfig = "MCP 配置"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .xctest: return "checklist"
        case .lldb: return "ladybug"
        case .mcp: return "terminal"
        case .prWorkflow: return "checkmark.seal"
        case .mcpConfig: return "server.rack"
        }
    }

    var fileExtension: String {
        switch self {
        case .xctest: return "swift"
        case .lldb: return "lldb"
        case .mcp: return "json"
        case .prWorkflow: return "sh"
        case .mcpConfig: return "json"
        }
    }

    var fileNameSuffix: String {
        switch self {
        case .xctest: return "AutomationTests"
        case .lldb: return "Drill"
        case .mcp: return "MCP"
        case .prWorkflow: return "PRWorkflow"
        case .mcpConfig: return "MCPConfig"
        }
    }

    var accent: UIColor {
        switch self {
        case .xctest: return LabUI.mint
        case .lldb: return LabUI.amber
        case .mcp: return LabUI.cyan
        case .prWorkflow: return LabUI.violet
        case .mcpConfig: return LabUI.mint
        }
    }

    var summary: String {
        switch self {
        case .xctest: return "生成 XCTest 桩，验证异常或性能场景可稳定复现。"
        case .lldb: return "生成 LLDB 取证脚本：status → interrupt → batch → 只 resume 一次。"
        case .mcp: return "生成 MCP drill JSON，交给本地 iOS MCP Server 执行。"
        case .prWorkflow: return "生成 /submit-pr 五阶段脚本：基线、门禁、预审、人类确认、推送。"
        case .mcpConfig: return "生成 MCP 配置 JSON，连接 scripts/mcp/ios_dev_mcp.py。"
        }
    }
}

enum AutomationScenario: String, CaseIterable, Identifiable {
    case cpuStall
    case allocationStorm
    case uaf
    case race
    case reconnect
    case orderBook

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .cpuStall: return "1.1 主线程卡顿"
        case .allocationStorm: return "1.2 分配锯齿"
        case .uaf: return "2.1 系统栈 UAF"
        case .race: return "2.2 并发踩踏"
        case .reconnect: return "3.1 弱网重连"
        case .orderBook: return "3.2 盘口节流"
        }
    }

    var subtitle: String {
        switch self {
        case .cpuStall: return "Time Profiler · JSON + 正则同步阻塞"
        case .allocationStorm: return "Allocations · 256KB buffer 锯齿"
        case .uaf: return "EXC_BAD_ACCESS · 0x1d 野指针取证"
        case .race: return "TSan · 8 线程非原子自增"
        case .reconnect: return "Exponential Backoff + Jitter"
        case .orderBook: return "Throttling Queue + Diff"
        }
    }

    var slug: String {
        switch self {
        case .cpuStall: return "CPUStall"
        case .allocationStorm: return "AllocationStorm"
        case .uaf: return "UAF"
        case .race: return "Race"
        case .reconnect: return "Reconnect"
        case .orderBook: return "OrderBook"
        }
    }

    var testClass: String {
        "\(slug)AutomationTests"
    }

    var breakpointPattern: String {
        switch self {
        case .cpuStall: return "CPUStallViewModel.*runStress"
        case .allocationStorm: return "AllocationStormViewModel.*handleTick"
        case .uaf: return "CrashProbe.*armSystemStackUseAfterFree"
        case .race: return "RaceScenarioViewModel.*run"
        case .reconnect: return "ReconnectViewModel.*scheduleRetry"
        case .orderBook: return "OrderBookViewModel.*apply"
        }
    }

    var focus: String {
        switch self {
        case .cpuStall: return "Time Profiler + Main Thread Checker"
        case .allocationStorm: return "Allocations + Generation"
        case .uaf: return "Zombie / Address Sanitizer / LLDB"
        case .race: return "Thread Sanitizer + TSan report"
        case .reconnect: return "Network Link Conditioner"
        case .orderBook: return "Core Animation + CADisplayLink"
        }
    }
}

struct GeneratedArtifact: Identifiable {
    let id = UUID()
    let fileName: String
    let scenario: AutomationScenario
    let kind: AutomationArtifactKind
    let content: String
    let savedURL: URL?
    let createdAt: Date

    var byteCount: Int {
        content.utf8.count
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: createdAt)
    }
}

enum AutomationStubFactory {
    static func make(kind: AutomationArtifactKind, scenario: AutomationScenario) -> (fileName: String, content: String) {
        let fileName = "\(scenario.slug)\(kind.fileNameSuffix).\(kind.fileExtension)"
        switch kind {
        case .xctest:
            return (fileName, testStub(for: scenario))
        case .lldb:
            return (fileName, lldbScript(for: scenario))
        case .mcp:
            return (fileName, mcpPlan(for: scenario))
        case .prWorkflow:
            return (fileName, prWorkflowScript(for: scenario))
        case .mcpConfig:
            return (fileName, mcpConfigJSON(for: scenario))
        }
    }

    static func shellCommand(for artifact: GeneratedArtifact) -> String {
        let base = """
        APP_DATA=$(xcrun simctl get_app_container booted e88ebfa25316fd8c.XClientLab data)
        cat "$APP_DATA/Documents/XClientLabAutomation/\(artifact.fileName)"
        """
        switch artifact.kind {
        case .xctest:
            return base + """


            # 将 Swift 文件加入 XClientLabTests target 后：
            xcodebuild test -project XClientLab.xcodeproj -scheme XClientLab \\
              -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \\
              -only-testing:XClientLabTests/\(artifact.scenario.testClass)
            """
        case .lldb:
            return base + """


            # 在 LLDB 中加载（先用 Xcode attach 到模拟器进程）：
            # (lldb) command source <path-to-file>/\(artifact.fileName)
            """
        case .mcp:
            return base + """


            # 交给 MCP 执行时，务必保留 timeout 与 process status 守卫：
            # xcode-mcp run --plan \(artifact.fileName)
            """
        case .prWorkflow:
            return base + """


            # 复制到仓库根目录后执行（对应 .claude/workflows/submit-pr.md）：
            # cp <path-to-file>/\(artifact.fileName) ./submit-pr.sh
            # cd <repo-root> && bash submit-pr.sh

            # 脚本会在 push 前停下来等待人工输入 CONFIRM
            """
        case .mcpConfig:
            return base + """


            # 注册到项目级 MCP 配置：
            # cp <path-to-file>/\(artifact.fileName) ./.mcp.json

            # 验证 Server 能完成 initialize 握手：
            echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python3 scripts/mcp/ios_dev_mcp.py | head -n 5

            # 在 Claude Code 中执行 /mcp，确认 xclientlab-ios-tools 状态为 connected
            """
        }
    }

    // MARK: XCTest

    private static func testStub(for scenario: AutomationScenario) -> String {
        switch scenario {
        case .cpuStall:
            return """
            import XCTest
            @testable import XClientLab

            /// Auto-generated by XClientLab 4.2.
            /// 目标：证明极端档确实在主线程制造 >500ms 的同步停顿。
            final class CPUStallAutomationTests: XCTestCase {
                @MainActor
                func testExtremePayloadBlocksMainThreadForAtLeast500ms() async throws {
                    let viewModel = CPUStallViewModel()
                    viewModel.intensity = .extreme
                    viewModel.runStress()

                    try await Task.sleep(nanoseconds: 2_500_000_000)

                    XCTAssertFalse(viewModel.passes.isEmpty, "压力轮次没有执行")
                    XCTAssertGreaterThan(viewModel.worstPassMs, 500.0, "极端档应产生 >500ms 停顿")
                }
            }
            """
        case .allocationStorm:
            return """
            import XCTest
            @testable import XClientLab

            /// Auto-generated by XClientLab 4.2.
            /// 目标：确认 tick 与 churn 发生，并把 footprint 采样交给 Allocations 对照。
            final class AllocationStormAutomationTests: XCTestCase {
                @MainActor
                func testAllocationStormProducesSawtooth() async throws {
                    let viewModel = AllocationStormViewModel()
                    viewModel.intensity = .extreme
                    viewModel.start()

                    try await Task.sleep(nanoseconds: 1_200_000_000)
                    viewModel.stop()

                    XCTAssertGreaterThan(viewModel.tickCount, 0)
                    XCTAssertGreaterThan(viewModel.churnedMB, 0)
                    XCTAssertFalse(viewModel.samples.isEmpty)
                }
            }
            """
        case .uaf:
            return """
            import XCTest
            @testable import XClientLab

            /// Auto-generated by XClientLab 4.2.
            /// 默认只校验取证文本，不主动触发崩溃。
            /// 真正触发需要显式设置 XCLIENTLAB_DESTRUCTIVE=1。
            final class UAFStubTests: XCTestCase {
                func testForensicReportContainsWildPointerAddress() {
                    let report = CrashProbe.expectedSystemStackReport
                    XCTAssertTrue(report.contains("EXC_BAD_ACCESS"))
                    XCTAssertTrue(report.contains("0x000000000000001d"))
                }

                @MainActor
                func testArmUseAfterFree() throws {
                    guard ProcessInfo.processInfo.environment["XCLIENTLAB_DESTRUCTIVE"] == "1" else {
                        throw XCTSkip("Destructive crash drill disabled")
                    }
                    let viewModel = UAFScenarioViewModel()
                    viewModel.arm()
                    RunLoop.main.run(until: Date().addingTimeInterval(5))
                }
            }
            """
        case .race:
            return """
            import XCTest
            @testable import XClientLab

            /// Auto-generated by XClientLab 4.2.
            /// 目标：在 unsafe 模式下观察 lostWrites > 0；用 .locked 做对照。
            final class RaceAutomationTests: XCTestCase {
                @MainActor
                func testUnsafeIncrementLosesWrites() async throws {
                    let viewModel = RaceScenarioViewModel()
                    viewModel.mode = .unsafe
                    viewModel.scale = .large
                    viewModel.run()

                    try await Task.sleep(nanoseconds: 4_000_000_000)

                    XCTAssertGreaterThan(viewModel.observed, 0)
                    print("expected=\\(viewModel.expected) observed=\\(viewModel.observed) lost=\\(viewModel.lostWrites)")
                }
            }
            """
        case .reconnect:
            return """
            import Foundation
            import XCTest

            /// Auto-generated by XClientLab 4.2.
            /// 目标：验证退避公式的单调性与 8s 上限；不依赖真实网络。
            final class ReconnectAutomationTests: XCTestCase {
                func testBackoffFormulaIsCapped() {
                    let baseDelay = 0.5
                    let maxDelay = 8.0
                    let delays = (1...10).map { retry in
                        min(maxDelay, baseDelay * pow(2.0, Double(retry - 1)))
                    }

                    XCTAssertTrue(delays.allSatisfy { $0 <= maxDelay })
                    XCTAssertEqual(delays.last, maxDelay, accuracy: 0.0001)
                    XCTAssertTrue(zip(delays, delays.dropFirst()).allSatisfy { $0 <= $1 })
                }
            }
            """
        case .orderBook:
            return """
            import XCTest
            @testable import XClientLab

            /// Auto-generated by XClientLab 4.2.
            /// 目标：证明一槽合并队列会把突发流量压缩成一次 take。
            final class OrderBookAutomationTests: XCTestCase {
                func testPipelineCoalescesBurstTraffic() {
                    let pipeline = OrderBookPipeline()
                    for sequence in 1...200 {
                        pipeline.submit(BookFactory.make(sequence: sequence, mid: 42_000))
                    }

                    XCTAssertNotNil(pipeline.take())
                    let stats = pipeline.stats()
                    XCTAssertEqual(stats.submitted, 200)
                    XCTAssertGreaterThan(stats.coalesced, 0)
                    XCTAssertNil(pipeline.take(), "一帧只能取走一个合并后的快照")
                }
            }
            """
        }
    }

    // MARK: LLDB

    private static func lldbScript(for scenario: AutomationScenario) -> String {
        """
        # XClientLab · \(scenario.title)
        # Auto-generated LLDB drill · \(scenario.focus)
        #
        # 通道纪律：status → interrupt → poll stopped → batch → 只 resume 一次。
        # 用法：先在 Xcode attach，再执行：
        #   (lldb) command source <path-to-file>/\(scenario.slug)Drill.lldb

        # 1. 先问状态，不要假设已经 stopped
        process status
        process interrupt
        process status

        # 2. 只有确定 stopped 后才设置断点
        breakpoint set -r '\(scenario.breakpointPattern)'

        # 3. 下一次命中后一次性固定现场
        thread list
        bt all
        register read x0 x1 x2 x3
        image lookup -a $pc

        # 4. 取证结束，统一恢复一次
        process continue
        """
    }

    // MARK: MCP

    private static func mcpPlan(for scenario: AutomationScenario) -> String {
        """
        {
          "schema": "xclientlab.mcp.drill/v1",
          "scenario": "\(scenario.rawValue)",
          "focus": "\(scenario.focus)",
          "guardrails": {
            "timeoutMs": 180000,
            "requireProcessStatus": true,
            "maxResumes": 1,
            "rejectCommandsWhileRunning": true
          },
          "steps": [
            {
              "tool": "xcode.build",
              "arguments": {
                "project": "XClientLab.xcodeproj",
                "scheme": "XClientLab",
                "destination": "generic/platform=iOS Simulator",
                "derivedDataPath": "./DerivedData"
              }
            },
            {
              "tool": "xcode.lldb",
              "arguments": {
                "input": "\(scenario.slug)Drill.lldb",
                "pollIntervalMs": 150
              }
            },
            {
              "tool": "xcode.result.parse",
              "arguments": {
                "keep": ["crash", "stack", "registers", "timing"]
              }
            }
          ],
          "acceptance": [
            "process status observed before the first query",
            "no command sent while state=running",
            "exactly one process continue at the end"
          ]
        }
        """
    }

}

extension AutomationStubFactory {
    // MARK: PR Workflow

    static func prWorkflowScript(for scenario: AutomationScenario) -> String {
        """
        #!/usr/bin/env bash
        # XClientLab · \(scenario.title)
        # /submit-pr 五阶段质量流水线 · 对应 .claude/workflows/submit-pr.md
        #
        # 用法：cd <repo-root> && bash \(scenario.slug)PRWorkflow.sh
        set -euo pipefail

        echo "== 1/5 基线：确认分支与改动范围 =="
        git rev-parse --show-toplevel
        git branch --show-current
        git status --short
        git diff --stat

        echo "== 2/5 自测门禁：任何 Error 立即中止 =="
        make lint
        make test
        make format-check

        echo "== 3/5 独立只读预审：只报 Blocker / Risk =="
        # 审查维度：资金精度 / 线程死锁 / 生命周期 / 幂等重试
        # 风险分级：低（UI、文档）/ 中（业务流）/ 高（TradingCore、并发、迁移、鉴权）
        git diff --unified=0 | head -n 400

        echo "== 4/5 人类掌舵门禁 =="
        read -r -p "预审通过且风险已分级？输入 CONFIRM 继续：" approval
        if [ "$approval" != "CONFIRM" ]; then
          echo "已中止：等待人类确认，未执行任何 push。"
          exit 1
        fi

        echo "== 5/5 推送分支并创建 PR =="
        git push -u origin "$(git branch --show-current)"
        gh pr create --fill --body "Scenario: \(scenario.title)"

        echo "OK：PR 已创建，等待评审。"
        """
    }

    // MARK: MCP Config

    static func mcpConfigJSON(for scenario: AutomationScenario) -> String {
        """
        {
          "mcpServers": {
            "xclientlab-ios-tools": {
              "command": "python3",
              "args": ["scripts/mcp/ios_dev_mcp.py"],
              "env": {
                "PROJECT_ROOT": ".",
                "XCL_SCENARIO": "\(scenario.rawValue)"
              }
            }
          }
        }
        """
    }
}

@MainActor
final class TerminalAutomationViewModel: NSObject, ObservableObject {
    @Published var kind: AutomationArtifactKind = .xctest
    @Published var scenario: AutomationScenario = .cpuStall
    @Published private(set) var artifacts: [GeneratedArtifact] = []
    @Published private(set) var lastError: String?

    let console = LabLogStore()

    private let folderName = "XClientLabAutomation"

    var documentsPath: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
            .path
    }

    func generate() {
        let payload = AutomationStubFactory.make(kind: kind, scenario: scenario)
        var savedURL: URL?
        do {
            savedURL = try save(fileName: payload.fileName, content: payload.content)
        } catch {
            lastError = error.localizedDescription
            console.log("写入 Documents 失败：\(error.localizedDescription)", level: .error)
        }

        let artifact = GeneratedArtifact(
            fileName: payload.fileName,
            scenario: scenario,
            kind: kind,
            content: payload.content,
            savedURL: savedURL,
            createdAt: Date()
        )
        artifacts.insert(artifact, at: 0)
        if artifacts.count > 8 {
            artifacts.removeLast()
        }

        console.log("生成 \(payload.fileName) · \(payload.content.utf8.count) bytes", level: .success)
        console.log("产物已写入 Documents/\(folderName)（若失败则仅保留在内存）", level: .debug)
    }

    func copy(_ text: String, label: String) {
        UIPasteboard.general.string = text
        console.log("已复制：\(label)", level: .info)
    }

    func copyContent(of artifact: GeneratedArtifact) {
        copy(artifact.content, label: artifact.fileName)
    }

    func copyTerminal(for artifact: GeneratedArtifact) {
        copy(AutomationStubFactory.shellCommand(for: artifact), label: "terminal command")
    }

    func reset() {
        artifacts.removeAll()
        lastError = nil
        console.clear()
        console.log("已清空列表；Documents 中的历史产物仍保留", level: .debug)
    }

    private func save(fileName: String, content: String) throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

/// Scenario 4.1a — Xcode MCP channel discipline.
///
/// 古法排查痛点：在 Xcode 里点 Pause 之后直接 `bt all`，如果进程其实还在
/// running，LLDB 会报 "process is running" 或直接卡住；再点一次 Continue
/// 又可能把刚拿到的现场放跑。异步崩溃（Timer / DispatchSource）尤其容易
/// 踩这个坑。
///
/// AI MCP 新实践切入点：把「先 process status、需要时 interrupt、轮询到
/// stopped、再批量取证、最后只 resume 一次」固化成通道状态机，让自动化
/// 工具按同一套纪律执行，而不是每次靠人记忆。
@MainActor
final class MCPChannelViewModel: NSObject, ObservableObject {
    enum ChannelState: String {
        case idle = "IDLE"
        case running = "RUNNING"
        case interrupting = "INTERRUPTING"
        case stopped = "STOPPED"
        case batching = "BATCHING"
        case done = "DONE"

        var color: UIColor {
            switch self {
            case .idle: return LabUI.textTertiary
            case .running: return LabUI.amber
            case .interrupting: return LabUI.coral
            case .stopped: return LabUI.mint
            case .batching: return LabUI.cyan
            case .done: return LabUI.violet
            }
        }
    }

    static let flow: [ChannelState] = [.idle, .running, .interrupting, .stopped, .batching, .done]

    /// Batch commands that are only legal once the process is stopped.
    static let batchCommands: [String] = [
        "thread list",
        "bt all",
        "register read x0 x1 x2 x3",
        "image lookup -a $pc",
        "process continue"
    ]

    @Published private(set) var state: ChannelState = .idle
    @Published private(set) var executedCount = 0
    @Published private(set) var rejectedCount = 0
    @Published private(set) var statusNote = "尚未 attach。先执行 process status，再决定是否 interrupt。"
    @Published private(set) var lastRunID = UUID()

    let console = LabLogStore()
    private var runToken = UUID()

    var isBusy: Bool {
        [.running, .interrupting, .batching].contains(state)
    }

    /// Simulates the disciplined MCP sequence. Each step is intentionally
    /// delayed so the audience can watch the state machine settle.
    func runBatch() {
        guard !isBusy else { return }
        let token = UUID()
        runToken = token
        lastRunID = token
        executedCount = 0
        rejectedCount = 0
        console.clear()
        state = .running
        statusNote = "process status → state = running（此刻禁止发送 bt all）"
        console.log("process status → state=running", level: .warning)
        console.log("通道纪律：running 状态下只允许 interrupt，不发送取证命令", level: .info)

        after(0.55, token: token) { viewModel in
            viewModel.state = .interrupting
            viewModel.statusNote = "process interrupt → 等待 target 真正停下"
            viewModel.console.log("process interrupt → signal sent", level: .info)
        }

        after(1.15, token: token) { viewModel in
            viewModel.state = .stopped
            viewModel.statusNote = "state = stopped · 现在可以安全地批量取证"
            viewModel.console.log("poll process status → state=stopped", level: .success)
        }

        for (index, command) in Self.batchCommands.enumerated() {
            after(1.55 + Double(index) * 0.28, token: token) { viewModel in
                viewModel.state = .batching
                viewModel.executedCount = index + 1
                viewModel.statusNote = "batch \(index + 1)/\(Self.batchCommands.count) · \(command)"
                viewModel.console.log("[\(index + 1)/\(Self.batchCommands.count)] \(command)", level: .success)
            }
        }

        after(1.55 + Double(Self.batchCommands.count) * 0.28 + 0.2, token: token) { viewModel in
            viewModel.state = .done
            viewModel.statusNote = "batch complete · resume 只发生一次，现场已固定"
            viewModel.console.log("取证完成：thread/backtrace/registers 已串行收集", level: .success)
            viewModel.console.log("MCP 将结构化结果回传，不把原始 LLDB 日志整段倒进上下文", level: .debug)
        }
    }

    /// The anti-pattern: firing a query at a running target. We never actually
    /// talk to LLDB here; the point is to make the failure mode visible.
    func sendWhileRunning() {
        rejectedCount += 1
        if state == .running || state == .interrupting {
            statusNote = "REJECTED：target 仍是 running，bt all 被通道守卫拦截"
            console.log("REJECTED bt all → process is running; interrupt + poll first", level: .error)
        } else {
            statusNote = "当前 target 不是 running，越权检查没有触发；但仍应先 process status"
            console.log("guard check: not running, command would be allowed after status poll", level: .warning)
        }
    }

    func reset() {
        runToken = UUID()
        state = .idle
        executedCount = 0
        rejectedCount = 0
        statusNote = "尚未 attach。先执行 process status，再决定是否 interrupt。"
        console.clear()
    }

    private func after(_ delay: TimeInterval, token: UUID, _ work: @escaping (MCPChannelViewModel) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.runToken == token else { return }
            work(self)
        }
    }
}
