import UIKit

// MARK: - 01 Performance

final class PerformanceHomeViewController: ModuleHomeViewController {
    init() {
        super.init(
            module: .performance,
            metrics: [
                .init("TARGET", "500", unit: "ms", detail: "可感知卡顿阈值", color: LabUI.coral),
                .init("FRAME", "16.7", unit: "ms", detail: "60Hz 帧预算", color: LabUI.cyan),
                .init("SCENARIOS", "02", unit: "drills", detail: "CPU / 内存", color: LabUI.mint),
            ],
            missionTitle: "性能不是「感觉卡」",
            missionBody: "把模糊的用户反馈压缩成可复现的 trace：先制造确定的异常，再让 Instruments 给出时间、线程、调用栈三层证据。两个场景都自带实时观测面板，演示时不需要外接仪器就能看到波形。",
            scenarios: [
                .init(
                    index: "1.1",
                    title: "主线程 JSON 风暴",
                    subtitle: "同步解析 6,000 条记录 + 密集正则，连续制造 >500ms 卡顿。",
                    tags: ["Time Profiler", "Hitches", "Main Thread"],
                    expectation: "worst pass > 500ms / dropped frames",
                    identifier: "perf.scenario.cpu",
                    destination: { CPUStallViewController() }
                ),
                .init(
                    index: "1.2",
                    title: "Allocations 锯齿",
                    subtitle: "长列表里高频分配 / 释放 256KB 临时缓冲，制造内存尖峰。",
                    tags: ["Allocations", "Peak", "Churn"],
                    expectation: "sawtooth + peak footprint",
                    identifier: "perf.scenario.alloc",
                    destination: { AllocationStormViewController() }
                ),
            ],
            problemNote: "「用户说卡」无法直接进 Instruments：没有稳定的复现路径，trace 里全是噪声；只看平均帧率又会漏掉 500ms 级的主线程阻塞。",
            aiNote: "先用 MCP 让 Agent 读取 Time Profiler / Hitch 报告，按最重的主线程栈自动生成最小复现实验；再把「运行 → 采集 → 归因」固化成可重复命令。"
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 02 Exceptions

final class ExceptionsHomeViewController: ModuleHomeViewController {
    init() {
        super.init(
            module: .exceptions,
            metrics: [
                .init("SIGNAL", "EXC_BAD", detail: "SIGSEGV / SIGBUS", color: LabUI.coral),
                .init("LIFECYCLE", "0x1d", detail: "野指针地址线索", color: LabUI.amber),
                .init("SCENARIOS", "02", detail: "UAF / Race", color: LabUI.cyan),
            ],
            missionTitle: "系统栈不是答案",
            missionBody: "真实事故里，最贵的不是「复现一次」，而是从全是系统库的栈里还原生命周期。下面两个场景分别制造真实的野指针踩踏与数据竞争，再演示如何用 LLDB 通道纪律和 TSan 把黑盒拆开。",
            scenarios: [
                .init(
                    index: "2.1",
                    title: "DispatchSource UAF",
                    subtitle: "Timer 释放瞬间踩踏 0x1d，制造系统栈黑盒 EXC_BAD_ACCESS。",
                    tags: ["EXC_BAD_ACCESS", "LLDB", "MCP"],
                    expectation: "real crash / subcode 0x1d",
                    identifier: "exc.scenario.uaf",
                    destination: { UAFScenarioViewController() }
                ),
                .init(
                    index: "2.2",
                    title: "并发读写踩踏",
                    subtitle: "8 线程并发修改同一引用；对比锁与无锁的丢失计数。",
                    tags: ["TSan", "Race", "Memory"],
                    expectation: "lost updates / intermittent crash",
                    identifier: "exc.scenario.race",
                    destination: { RaceScenarioViewController() }
                ),
            ],
            problemNote: "崩溃栈全是 libsystem / libdispatch 时，人容易停在「系统 bug」；没有地址、寄存器、队列归属和释放时序，就无法证明是自己的生命周期问题。",
            aiNote: "把「process status → interrupt → 轮询 stopped → 批量取证 → 只 resume 一次」写成 MCP 通道状态机；Agent 按固定证据清单执行，避免人工在异步 resuming 状态里反复误操作。"
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 03 Exchange

final class ExchangeHomeViewController: ModuleHomeViewController {
    init() {
        super.init(
            module: .exchange,
            metrics: [
                .init("PUSH", "83", unit: "/s", detail: "全量盘口推送", color: LabUI.mint),
                .init("BACKOFF", "0.5→8", unit: "s", detail: "指数退避 + Jitter", color: LabUI.amber),
                .init("FRAME", "8.3", unit: "ms", detail: "120Hz 帧预算", color: LabUI.cyan),
            ],
            missionTitle: "稳定性不是「多试几次」",
            missionBody: "弱网重连需要状态机、重试上限、指数退避与抖动；高频行情需要把「事件」折叠成「状态」，再用差分更新喂给渲染层。两个场景都把内部队列、合并率与帧预算直接暴露在 UI 上。",
            scenarios: [
                .init(
                    index: "3.1",
                    title: "弱网重连状态机",
                    subtitle: "断线 → 退避 → Jitter → 重试上限，避免密集重连打挂网关。",
                    tags: ["WebSocket", "Backoff", "Jitter"],
                    expectation: "capped retries / smooth backoff",
                    identifier: "exc.scenario.reconnect",
                    destination: { ReconnectViewController() }
                ),
                .init(
                    index: "3.2",
                    title: "盘口节流与 Diff",
                    subtitle: "~83 条/秒全量快照：直更 vs 节流队列 vs 节流 + 差分。",
                    tags: ["Throttle", "Diff", "120Hz"],
                    expectation: "coalesced / stable frame budget",
                    identifier: "exc.scenario.book",
                    destination: { OrderBookViewController() }
                ),
            ],
            problemNote: "「断线就立刻重连」会在弱网下形成重连风暴；「每条推送都 setState」会让主线程被事件数量而不是屏幕刷新率驱动。",
            aiNote: "用 MCP 读取 Instruments 的 hitch / network trace，让 Agent 依据实际 coalesced 比例与帧预算调整节流窗口，而不是凭感觉改 Timer 间隔。"
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 04 AI-Native

final class AINativeHomeViewController: ModuleHomeViewController {
    init() {
        super.init(
            module: .aiNative,
            metrics: [
                .init("SKILLS", "03", detail: "可复用调试剧本", color: LabUI.violet),
                .init("STATES", "05", detail: "MCP 通道状态", color: LabUI.cyan),
                .init("ARTIFACTS", "03", detail: "XCTest / LLDB / MCP", color: LabUI.mint),
            ],
            missionTitle: "把调试经验变成可复用资产",
            missionBody: "AI-Native 不是「让模型猜」：而是把 LLDB 的异步通道纪律、排查步骤和终端命令沉淀成 Skill / 模板 / 命令桩，让每次演示和回归都走同一条可审计路径。",
            scenarios: [
                .init(
                    index: "4.1",
                    title: "MCP 通道 + Skills",
                    subtitle: "状态机演示 interrupt / status 轮询；内置可复制的 LLDB Skill。",
                    tags: ["Xcode MCP", "LLDB", "Skill"],
                    expectation: "no command while running",
                    identifier: "ai.scenario.skills",
                    destination: { SkillLibraryViewController() }
                ),
                .init(
                    index: "4.2",
                    title: "Terminal-first 命令桩",
                    subtitle: "一键生成 XCTest 桩、LLDB 脚本与 MCP JSON 到沙盒。",
                    tags: ["XCTest", "LLDB", "MCP"],
                    expectation: "generated artifacts on disk",
                    identifier: "ai.scenario.terminal",
                    destination: { TerminalAutomationViewController() }
                ),
            ],
            problemNote: "调试经验留在个人肌肉记忆里：换一个人、换一次会话，就要重新摸索 process status 与 interrupt 的时机，容易把现场放跑。",
            aiNote: "把「先取证再继续」写成可执行的 Skill 与 MCP guardrail，让 Agent 在异步 resuming 状态下也遵守通道纪律；终端命令桩则把一次性操作变成可回归资产。"
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 05 Architecture

final class ArchitectureHomeViewController: ModuleHomeViewController {
    init() {
        super.init(
            module: .architecture,
            metrics: [
                .init("PACKAGES", "02", detail: "Contracts / Feature", color: LabUI.amber),
                .init("PORTS", "03", detail: "POP 抽象层", color: LabUI.cyan),
                .init("DI", "01", detail: "组装根统一装配", color: LabUI.mint),
            ],
            missionTitle: "把「解耦」做成可运行的依赖图",
            missionBody: "这一页不是画架构图，而是把两个本地 SPM 包真的接进 App：契约层零依赖，Feature 包依赖契约与资源，App 只依赖协议。你可以直接切换实现、看资源从哪里来、验证容器每次 resolve 的是不是同一个实例。",
            scenarios: [
                .init(
                    index: "5.1",
                    title: "依赖图与组装根",
                    subtitle: "三个节点的 DAG、容器注册表、singleton / transient 行为。",
                    tags: ["SPM", "DI", "DAG"],
                    expectation: "same singleton / fresh transient",
                    identifier: "arch.scenario.graph",
                    destination: { ModuleGraphViewController() }
                ),
                .init(
                    index: "5.2",
                    title: "资源与实现替换",
                    subtitle: "Bundle.module 资源、协议替换、UserDirectoryService 链路。",
                    tags: ["Bundle.module", "POP", "Swap"],
                    expectation: "resource + service swap",
                    identifier: "arch.scenario.profile",
                    destination: { ProfileFeatureLabViewController() }
                ),
            ],
            problemNote: "架构图上的箭头很漂亮，但一旦没有真正的编译期依赖边界，Feature 仍会偷偷 import 实现细节，资源也会散落在主 App。",
            aiNote: "让 Agent 读取 Package.swift 与 import 图，自动检查「契约层是否零依赖」「Feature 是否反向依赖 App」，把架构约束变成 CI 可验证的规则。"
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
