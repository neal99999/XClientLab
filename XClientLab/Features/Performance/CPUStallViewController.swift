import Combine
import SnapKit
import UIKit

/// Scenario 1.1 — 主线程 JSON + 正则压力。
///
/// 古法排查痛点：只看到「卡了一下」，没有稳定的复现入口；Time Profiler 里
/// 主线程被 JSONSerialization / NSRegularExpression 占满，却很难向面试官
/// 证明这是业务代码而不是系统噪声。
///
/// AI MCP 新实践切入点：让 Agent 先读 Time Profiler 的 heaviest stack，
/// 再按同一份 payload / pass 配置生成复现实验；跑完自动对比 worst pass、
/// hitch 数与 dropped frames，而不是靠肉眼看日志。
final class CPUStallViewController: LabBaseViewController {
    private let viewModel = CPUStallViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let worstTile = LabMetricTileView(
        label: "WORST PASS", value: "—", unit: "ms", detail: "单次同步阻塞", color: LabUI.coral
    )
    private let totalTile = LabMetricTileView(
        label: "TOTAL BLOCK", value: "—", unit: "ms", detail: "累计主线程占用", color: LabUI.amber
    )
    private let payloadTile = LabMetricTileView(
        label: "PAYLOAD", value: "—", unit: "MB", detail: "JSON + regex 输入", color: LabUI.cyan
    )
    private let phaseLabel = labLabel("IDLE", size: 10, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
    private let passStack = labStack(spacing: 5)
    private let runButton = LabButton(title: "RUN BLOCKING WORK", style: .destructive, accent: LabUI.coral)
    private let resetButton = LabButton(title: "RESET", style: .ghost)
    private lazy var intensityControl = LabUIKit.segmented(
        items: CPUStallViewModel.Intensity.allCases.map(\.title),
        accent: LabUI.coral,
        selected: 1
    )

    init() {
        super.init(accent: LabUI.coral)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "1.1 CPU 卡顿"
        buildUI()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startMonitoring()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopMonitoring()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 1.1  /  TIME PROFILER",
            title: "主线程 JSON 风暴",
            subtitle: "同步解析 6,000 条记录的 JSON，再对整段文本做密集正则匹配。按钮点下后主线程会连续失去响应。",
            accent: LabUI.coral
        ))
        add(labMetricRow([worstTile, totalTile, payloadTile]))

        let phaseCard = LabCardView(accent: LabUI.coral)
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.addArrangedSubview(LabStatusDotView(color: LabUI.coral))
        row.addArrangedSubview(labLabel("MAIN THREAD", size: 9.5, weight: .bold, color: LabUI.coral, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(phaseLabel)
        phaseCard.add(row)
        phaseCard.add(intensityControl)
        phaseCard.add(LabUIKit.actionRow([runButton, resetButton]))
        phaseCard.add(labLabel(
            "极端档 12 轮，单轮同时做 JSON 解析与全量正则扫描；按钮点击后 250ms 才真正阻塞，确保 UI 先完成一次绘制。",
            size: 10.5,
            color: LabUI.textTertiary
        ))
        add(phaseCard)

        let barsCard = LabCardView(accent: LabUI.amber)
        barsCard.add(labLabel("PER-PASS COST", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        barsCard.add(passStack)
        barsCard.add(labLabel("每根条代表一轮 pass；>500ms 时肉眼可见明显长度差。", size: 10, color: LabUI.textTertiary))
        add(barsCard)

        let mechanism = LabCardView(accent: LabUI.coral)
        mechanism.add(labLabel("MECHANISM", size: 9.5, weight: .bold, color: LabUI.coral, mono: true, lines: 1))
        mechanism.add(LabCodeBlockView(
            code: "JSONSerialization.jsonObject(with: data)\n    ↓ 6,000 records on main actor\nNSRegularExpression.numberOfMatches(in: fullText)\n    ↓ no chunk / no cancellation\nCADisplayLink gap > 500ms",
            accent: LabUI.coral
        ))
        add(mechanism)

        add(LabCalloutView(
            kind: .problem,
            message: "「用户说卡」无法直接进 Instruments：没有稳定复现路径，trace 里全是噪声；平均帧率又会掩盖 500ms 级主线程阻塞。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "用 MCP 读取 Time Profiler 的 heaviest stack，让 Agent 按同一份 payload 生成最小复现；再自动比对 worst pass 与 hitch 数，把「感觉卡」变成可验证实验。"
        ))

        let recipe = LabCardView(accent: LabUI.cyan)
        recipe.add(labLabel("INSTRUMENTS RECIPE", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        recipe.add(LabTimelineRowView(time: "01", title: "Time Profiler", detail: "Attach → 点 RUN → 等主线程恢复后 Stop。", color: LabUI.cyan))
        recipe.add(LabTimelineRowView(time: "02", title: "Call Tree", detail: "Separate by Thread + Hide System Libraries，锁定业务栈。", color: LabUI.cyan))
        recipe.add(LabTimelineRowView(time: "03", title: "Hitches", detail: "对照 worst pass 与 dropped frames，确认用户可感知。", color: LabUI.cyan))
        recipe.add(LabTimelineRowView(time: "04", title: "MCP 取证", detail: "把 trace 摘要交给 Agent，生成优化前后对比。", color: LabUI.cyan, isLast: true))
        add(recipe)

        add(LabHitchReadoutView(monitor: viewModel.hitch))
        add(LabConsoleView(store: viewModel.console, title: "STALL LOG", height: 190, accent: LabUI.coral))

        intensityControl.accessibilityIdentifier = "cpu.intensity"
        runButton.accessibilityIdentifier = "cpu.run"
        resetButton.accessibilityIdentifier = "cpu.reset"
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        intensityControl.addTarget(self, action: #selector(intensityChanged), for: .valueChanged)
    }

    private func bind() {
        viewModel.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                guard let self else { return }
                runButton.isEnabled = !running
                runButton.setTitle(running ? "BLOCKING…" : "RUN BLOCKING WORK", for: .normal)
            }
            .store(in: &cancellables)

        viewModel.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                self?.phaseLabel.text = phase
                self?.phaseLabel.textColor = phase == "IDLE" ? LabUI.textTertiary : LabUI.coral
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(viewModel.$worstPassMs, viewModel.$totalBlockedMs, viewModel.$payloadBytes)
            .receive(on: RunLoop.main)
            .sink { [weak self] worst, total, bytes in
                guard let self else { return }
                worstTile.update(value: String(format: "%.0f", worst))
                totalTile.update(value: String(format: "%.0f", total))
                payloadTile.update(value: String(format: "%.2f", Double(bytes) / 1_048_576))
            }
            .store(in: &cancellables)

        viewModel.$passes
            .receive(on: RunLoop.main)
            .sink { [weak self] passes in self?.renderPasses(passes) }
            .store(in: &cancellables)
    }

    private func renderPasses(_ passes: [CPUStallViewModel.StallPass]) {
        passStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !passes.isEmpty else {
            passStack.addArrangedSubview(labLabel("尚未运行。点击上方按钮开始制造卡顿。", size: 11, color: LabUI.textTertiary))
            return
        }
        for pass in passes {
            let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
            row.addArrangedSubview(labLabel(String(format: "%02d", pass.index), size: 9, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
            let bar = LabMiniBarView(color: pass.durationMs > 500 ? LabUI.coral : LabUI.amber)
            bar.setProgress(min(1, pass.durationMs / 900))
            bar.snp.makeConstraints { make in make.height.equalTo(7) }
            row.addArrangedSubview(bar)
            row.addArrangedSubview(labLabel(String(format: "%.0fms", pass.durationMs), size: 9.5, color: LabUI.textSecondary, mono: true, lines: 1))
            passStack.addArrangedSubview(row)
        }
    }

    @objc private func runTapped() {
        viewModel.runStress()
    }

    @objc private func resetTapped() {
        viewModel.reset()
    }

    @objc private func intensityChanged() {
        viewModel.intensity = CPUStallViewModel.Intensity(rawValue: intensityControl.selectedSegmentIndex + 1) ?? .standard
    }
}
