import Combine
import UIKit

/// 一条“排查步骤”：标题 + 单步估算耗时。
struct DemoStep {
    let title: String
    let minutes: Int
}

/// 一个可对照的场景：古法路径 vs AI/MCP 路径，最终都落到真实实验页。
struct DemoScenario {
    let id: String
    let index: String
    let module: LabModule
    let title: String
    let subtitle: String
    let traditional: [DemoStep]
    let ai: [DemoStep]
    let destination: () -> UIViewController

    var shortTitle: String {
        switch id {
        case "cpu": return "CPU"
        case "uaf": return "野指针"
        case "book": return "盘口"
        case "lldb": return "LLDB"
        default: return index
        }
    }

    var traditionalMinutes: Int { traditional.reduce(0) { $0 + $1.minutes } }
    var aiMinutes: Int { ai.reduce(0) { $0 + $1.minutes } }
    var savedMinutes: Int { max(0, traditionalMinutes - aiMinutes) }
    var savedPercent: Int {
        guard traditionalMinutes > 0 else { return 0 }
        return Int((Double(savedMinutes) / Double(traditionalMinutes) * 100).rounded())
    }
}

enum DemoLibrary {
    /// 这些数字是“演示估算”，不是生产基准：目的是把排查步骤的差异讲清楚。
    static let all: [DemoScenario] = [
        DemoScenario(
            id: "cpu",
            index: "01",
            module: .performance,
            title: "主线程 JSON 风暴",
            subtitle: "6,000 条记录 + 密集正则，连续制造 >500ms 卡顿。",
            traditional: [
                DemoStep(title: "复现与录屏", minutes: 8),
                DemoStep(title: "Instruments 手动录 trace", minutes: 10),
                DemoStep(title: "翻主线程调用栈", minutes: 7),
                DemoStep(title: "手工拼时间线证据", minutes: 6),
                DemoStep(title: "补回归用例", minutes: 4),
            ],
            ai: [
                DemoStep(title: "MCP 读取 trace / hitch 报告", minutes: 2),
                DemoStep(title: "Skill 生成最小复现负载", minutes: 2),
                DemoStep(title: "自动输出证据链 + 回归桩", minutes: 2),
            ],
            destination: { CPUStallViewController() }
        ),
        DemoScenario(
            id: "uaf",
            index: "02",
            module: .exceptions,
            title: "DispatchSource 野指针",
            subtitle: "Timer 释放瞬间踩踏 0x1d，制造系统栈黑盒 EXC_BAD_ACCESS。",
            traditional: [
                DemoStep(title: "等偶现崩溃复现", minutes: 10),
                DemoStep(title: "手工 attach + 下断点", minutes: 12),
                DemoStep(title: "running 状态误发命令", minutes: 10),
                DemoStep(title: "逐条 bt / register 取证", minutes: 8),
                DemoStep(title: "整理崩溃报告", minutes: 7),
                DemoStep(title: "补防回归用例", minutes: 5),
            ],
            ai: [
                DemoStep(title: "Skill 固定通道纪律", minutes: 3),
                DemoStep(title: "MCP 批量取证并轮询状态", minutes: 3),
                DemoStep(title: "自动生成报告 + 回归桩", minutes: 2),
            ],
            destination: { UAFScenarioViewController() }
        ),
        DemoScenario(
            id: "book",
            index: "03",
            module: .exchange,
            title: "盘口高频推送",
            subtitle: "~83 条/秒全量快照：直更 vs 节流队列 vs 节流 + 差分。",
            traditional: [
                DemoStep(title: "开多个面板看帧率", minutes: 8),
                DemoStep(title: "手动切直更 / 节流", minutes: 9),
                DemoStep(title: "猜一个 Timer 间隔", minutes: 8),
                DemoStep(title: "对比 coalesced 比例", minutes: 7),
                DemoStep(title: "记录结论与截图", minutes: 5),
            ],
            ai: [
                DemoStep(title: "MCP 读取 hitch / network trace", minutes: 2),
                DemoStep(title: "Agent 计算合并率与帧预算", minutes: 3),
                DemoStep(title: "生成参数对照 + 回归断言", minutes: 2),
            ],
            destination: { OrderBookViewController() }
        ),
        DemoScenario(
            id: "lldb",
            index: "04",
            module: .aiNative,
            title: "LLDB 异步取证",
            subtitle: "process status → interrupt → 轮询 stopped → 批量命令 → 只 resume 一次。",
            traditional: [
                DemoStep(title: "等崩溃 / 手动 attach", minutes: 12),
                DemoStep(title: "在 running 状态试探命令", minutes: 10),
                DemoStep(title: "手工轮询 process status", minutes: 8),
                DemoStep(title: "逐条 bt / register / image", minutes: 10),
                DemoStep(title: "整理命令与结论", minutes: 5),
            ],
            ai: [
                DemoStep(title: "Skill 固化通道状态机", minutes: 2),
                DemoStep(title: "MCP 批量取证 + 只 resume 一次", minutes: 3),
            ],
            destination: { SkillLibraryViewController() }
        ),
    ]
}

/// 对照页只负责“选择场景 + 播放时间差”，不承载真实实验状态；
/// 真实实验仍然由各自的 ViewModel 驱动。
@MainActor
final class DemoComparisonViewModel: ObservableObject {
    @Published private(set) var selectedIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0

    let scenarios = DemoLibrary.all
    private var playbackToken = UUID()

    var selected: DemoScenario {
        scenarios[min(max(0, selectedIndex), scenarios.count - 1)]
    }

    func select(_ index: Int) {
        guard scenarios.indices.contains(index), index != selectedIndex else { return }
        playbackToken = UUID()
        isPlaying = false
        progress = 0
        selectedIndex = index
    }

    func play() {
        let token = UUID()
        playbackToken = token
        progress = 0
        isPlaying = true
        tick(token)
    }

    func reset() {
        playbackToken = UUID()
        isPlaying = false
        progress = 0
    }

    private func tick(_ token: UUID) {
        guard token == playbackToken, isPlaying else { return }
        progress = min(1, progress + 0.025)
        if progress >= 1 {
            isPlaying = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.tick(token)
        }
    }
}
