import Combine
import SnapKit
import UIKit

/// Scenario 2.1 — 真实野指针踩踏，制造系统栈黑盒崩溃。
///
/// 古法排查痛点：崩溃栈全是 libsystem / libdispatch，人容易停在「系统 bug」；
/// 没有地址、寄存器、队列归属与释放时序，就无法证明是自己的生命周期问题。
/// 这个页面会真的把进程打崩，适合演示「取证纪律」而不是只讲概念。
///
/// AI MCP 新实践切入点：让 Agent 先 process status、必要时 interrupt 并轮询
/// 到 stopped，再批量 thread list / bt all / register read / image lookup；
/// 整个过程只允许 continue 一次，避免把现场放跑。
final class UAFScenarioViewController: LabBaseViewController {
    private let viewModel = UAFScenarioViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let stageLabel = labLabel("IDLE", size: 11, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
    private let countdownLabel = labLabel("3", size: 56, weight: .bold, color: LabUI.coral, rounded: true, lines: 1)
    private let fireButton = LabButton(title: "ARM SYSTEM-STACK UAF", style: .destructive, accent: LabUI.coral)
    private let cancelButton = LabButton(title: "CANCEL", style: .ghost)

    init() { super.init(accent: LabUI.coral) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "2.1 UAF Crash"
        buildUI()
        bind()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 2.1  /  EXC_BAD_ACCESS",
            title: "DispatchSource UAF",
            subtitle: "Timer 释放瞬间，回调仍持有悬垂指针；3 秒后向 0x1d 执行 memcpy，制造系统栈黑盒崩溃。",
            accent: LabUI.coral
        ))

        let danger = LabCardView(accent: LabUI.coral)
        danger.add(labLabel("⚠️ 真实崩溃实验", size: 13, weight: .bold, color: LabUI.coral, rounded: true, lines: 1))
        danger.add(labLabel(
            "点击后会真的终止 App。演示前先 attach LLDB；如果只想讲流程，不要点确认。",
            size: 12,
            color: LabUI.textSecondary
        ))
        danger.add(labMetricRow([
            LabMetricTileView(label: "SIGNAL", value: "SIGSEGV", detail: "EXC_BAD_ACCESS", color: LabUI.coral),
            LabMetricTileView(label: "ADDRESS", value: "0x1d", detail: "KERN_INVALID_ADDRESS", color: LabUI.amber),
            LabMetricTileView(label: "FRAME", value: "libsystem", detail: "_platform_memmove", color: LabUI.cyan),
        ]))
        add(danger)

        let stateCard = LabCardView(accent: LabUI.coral)
        let stateRow = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        stateRow.addArrangedSubview(LabStatusDotView(color: LabUI.coral))
        stateRow.addArrangedSubview(labLabel("LIFECYCLE", size: 9.5, weight: .bold, color: LabUI.coral, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stateRow.addArrangedSubview(spacer)
        stateRow.addArrangedSubview(stageLabel)
        stateCard.add(stateRow)
        countdownLabel.textAlignment = .center
        stateCard.add(countdownLabel)
        stateCard.add(LabUIKit.actionRow([fireButton, cancelButton]))
        stateCard.add(labLabel("0x1d 是演示用的哨兵地址；真实事故里通常是已释放对象的 isa 或缓冲区首地址。", size: 10, color: LabUI.textTertiary))
        add(stateCard)

        let mechanism = LabCardView(accent: LabUI.coral)
        mechanism.add(labLabel("MECHANISM", size: 9.5, weight: .bold, color: LabUI.coral, mono: true, lines: 1))
        mechanism.add(LabCodeBlockView(
            code: "timer.cancel()  →  source released\ncallback still captures raw pointer\nmemcpy(dst: 0x1d, src: 0x41, n: 64)\n    ↓\nEXC_BAD_ACCESS (SIGSEGV)\nKERN_INVALID_ADDRESS at 0x1d",
            accent: LabUI.coral
        ))
        add(mechanism)

        let forensic = LabCardView(accent: LabUI.amber)
        forensic.add(labLabel("EXPECTED CRASH REPORT", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        let report = labLabel(CrashProbe.expectedSystemStackReport, size: 9.5, color: LabUI.textSecondary, mono: true)
        forensic.add(report)
        let copy = LabButton(title: "COPY REPORT", style: .secondary, accent: LabUI.amber, systemImage: "doc.on.doc")
        copy.addTarget(self, action: #selector(copyReport), for: .touchUpInside)
        forensic.add(copy)
        add(forensic)

        let lldb = LabCardView(accent: LabUI.cyan)
        lldb.add(labLabel("LLDB / MCP BATCH", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        lldb.add(LabCodeBlockView(
            code: "(lldb) process status\n(lldb) process interrupt\n(lldb) process status   # 轮询到 stopped\n(lldb) thread list\n(lldb) bt all\n(lldb) register read x0 x1\n(lldb) image lookup -a $pc\n(lldb) process continue  # 只允许一次",
            accent: LabUI.cyan
        ))
        add(lldb)

        add(LabCalloutView(
            kind: .problem,
            message: "「系统栈崩溃」不是结论：没有地址/寄存器/队列归属，就无法区分对象释放、缓冲区越界和系统 bug。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "把异步通道纪律写进 MCP 状态机：先 status，必要时 interrupt 并轮询，再批量取证，最后只 resume 一次；Agent 不靠记忆，也不会在 running 状态下误发 bt all。"
        ))
        add(LabCalloutView(
            kind: .insight,
            message: "面试讲解顺序：先承认这是真实崩溃 → 说明 0x1d 的含义 → 展示系统栈 → 用寄存器/队列归属把锅从系统挪回生命周期。"
        ))

        add(LabConsoleView(store: viewModel.console, title: "UAF LOG", height: 170, accent: LabUI.coral))
        fireButton.accessibilityIdentifier = "uaf.trigger"
        fireButton.addTarget(self, action: #selector(armTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func bind() {
        viewModel.$stage
            .receive(on: RunLoop.main)
            .sink { [weak self] stage in
                self?.stageLabel.text = stage.rawValue
                self?.stageLabel.textColor = stage == .idle ? LabUI.textTertiary : LabUI.coral
                self?.fireButton.isEnabled = stage == .idle
            }
            .store(in: &cancellables)

        viewModel.$countdown
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.countdownLabel.text = "\(value)"
                self?.countdownLabel.textColor = value <= 1 ? LabUI.coral : LabUI.amber
            }
            .store(in: &cancellables)
    }

    @objc private func armTapped() {
        LabUIKit.alert(
            on: self,
            title: "确认制造真实崩溃？",
            message: "App 会立即退出。请先 attach LLDB，或确保你只想演示「不点确认」的安全路径。",
            confirmTitle: "ARM & CRASH",
            destructive: true
        ) { [weak self] in self?.viewModel.arm() }
    }

    @objc private func cancelTapped() { viewModel.cancel() }

    @objc private func copyReport() {
        UIPasteboard.general.string = CrashProbe.expectedSystemStackReport
        viewModel.console.log("崩溃报告已复制到剪贴板", level: .success)
    }
}
