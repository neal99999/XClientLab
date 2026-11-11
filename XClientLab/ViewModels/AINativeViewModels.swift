import Combine
import Foundation
import UIKit

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
