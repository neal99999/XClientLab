import Combine
import SnapKit
import UIKit

/// Scenario 2.2 — 多线程并发读写与野指针踩踏。
///
/// 古法排查痛点：无锁自增的丢写是「偶现」的——结果取决于调度、缓存行与
/// 编译器优化，单次运行可能完全正常；没有 TSan / 压力循环，很难稳定归因。
///
/// AI MCP 新实践切入点：让 Agent 把 TSan 报告映射到具体读写点，批量跑多轮
/// 压力并统计丢写率；对于真实 UAF，则按固定 LLDB 取证清单恢复崩溃现场。
final class RaceScenarioViewController: LabBaseViewController {
    private let viewModel = RaceScenarioViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let observedTile = LabMetricTileView(label: "OBSERVED", value: "0", detail: "实际计数", color: LabUI.cyan)
    private let lostTile = LabMetricTileView(label: "LOST", value: "0", detail: "丢失自增", color: LabUI.coral)
    private let durationTile = LabMetricTileView(label: "ELAPSED", value: "—", unit: "ms", detail: "本轮耗时", color: LabUI.amber)
    private let progress = LabMiniBarView(color: LabUI.cyan)
    private let runButton = LabButton(title: "RUN 8 THREADS", style: .primary, accent: LabUI.cyan)
    private let resetButton = LabButton(title: "RESET", style: .ghost)
    private lazy var modeControl = LabUIKit.segmented(
        items: RaceScenarioViewModel.Mode.allCases.map(\.title),
        accent: LabUI.coral,
        selected: 0
    )
    private lazy var scaleControl = LabUIKit.segmented(
        items: RaceScenarioViewModel.Scale.allCases.map(\.title),
        accent: LabUI.amber,
        selected: 1
    )

    init() { super.init(accent: LabUI.cyan) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "2.2 Race"
        buildUI()
        bind()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 2.2  /  THREAD SANITIZER",
            title: "并发读写与丢失计数",
            subtitle: "8 个线程对同一个 Int64 做非原子 read-modify-write；切到 NSLock 对比正确性代价。",
            accent: LabUI.cyan
        ))
        add(labMetricRow([observedTile, lostTile, durationTile]))

        let controls = LabCardView(accent: LabUI.cyan)
        controls.add(labLabel("MODE", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        controls.add(modeControl)
        controls.add(labLabel("SCALE / THREAD", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        controls.add(scaleControl)
        controls.add(LabUIKit.actionRow([runButton, resetButton]))
        add(controls)

        let progressCard = LabCardView(accent: LabUI.cyan)
        progressCard.add(labLabel("OBSERVED / EXPECTED", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        progressCard.add(progress)
        progress.snp.makeConstraints { make in make.height.equalTo(10) }
        progressCard.add(labLabel("每次运行结果都可能不同：这正是数据竞争最难复现的地方。", size: 10, color: LabUI.textTertiary))
        add(progressCard)

        let mechanism = LabCardView(accent: LabUI.amber)
        mechanism.add(labLabel("MECHANISM", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        mechanism.add(LabCodeBlockView(
            code: "counter.pointee += 1\n// load(old) → add(1) → store(new)\n// two cores load same old value\n// one update is lost",
            accent: LabUI.amber
        ))
        add(mechanism)

        add(LabCalloutView(
            kind: .problem,
            message: "「这次没复现」不等于没有 bug：竞态结果取决于调度与缓存行，必须用 TSan、压力循环与丢写率统计来证明。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "让 Agent 读取 TSan 报告，把「同一地址的并发读写」映射到源码行；再按固定轮次跑压力，输出丢写率与修复前后对比。"
        ))

        let danger = LabCardView(accent: LabUI.coral)
        danger.add(labLabel("DANGER ZONE", size: 9.5, weight: .bold, color: LabUI.coral, mono: true, lines: 1))
        danger.add(labLabel(
            "真实野指针踩踏：mmap → munmap → 8 线程持续 store。第一个 store 就会触发 EXC_BAD_ACCESS，进程立即退出。",
            size: 11.5,
            color: LabUI.textSecondary
        ))
        let stomp = LabButton(title: "TRIGGER CONCURRENT STOMP", style: .destructive, accent: LabUI.coral)
        stomp.accessibilityIdentifier = "race.stomp"
        stomp.addTarget(self, action: #selector(stompTapped), for: .touchUpInside)
        danger.add(stomp)
        add(danger)

        let recipe = LabCardView(accent: LabUI.mint)
        recipe.add(labLabel("TSAN → MCP RECIPE", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        recipe.add(LabTimelineRowView(time: "01", title: "Product → Scheme", detail: "勾选 Thread Sanitizer，重跑无锁模式。", color: LabUI.mint))
        recipe.add(LabTimelineRowView(time: "02", title: "Read report", detail: "定位同一地址的并发 read / write。", color: LabUI.mint))
        recipe.add(LabTimelineRowView(time: "03", title: "Agent 归因", detail: "把报告映射到 counter.pointee += 1。", color: LabUI.mint))
        recipe.add(LabTimelineRowView(time: "04", title: "验证", detail: "切 NSLock，观察 lost = 0 与耗时变化。", color: LabUI.mint, isLast: true))
        add(recipe)

        add(LabConsoleView(store: viewModel.console, title: "RACE LOG", height: 190, accent: LabUI.cyan))
        modeControl.accessibilityIdentifier = "race.mode"
        scaleControl.accessibilityIdentifier = "race.scale"
        runButton.accessibilityIdentifier = "race.run"
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        scaleControl.addTarget(self, action: #selector(scaleChanged), for: .valueChanged)
    }

    private func bind() {
        viewModel.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                self?.runButton.isEnabled = !running
                self?.runButton.setTitle(running ? "RUNNING…" : "RUN 8 THREADS", for: .normal)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(viewModel.$observed, viewModel.$lostWrites)
            .receive(on: RunLoop.main)
            .sink { [weak self] observed, lost in
                guard let self else { return }
                observedTile.update(value: LabFormat.integer(Int(observed)))
                lostTile.update(value: LabFormat.integer(Int(lost)))
                let expected = max(1, Double(viewModel.expectedForCurrentScale))
                progress.setProgress(Double(observed) / expected)
            }
            .store(in: &cancellables)

        viewModel.$lastDurationMs
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.durationTile.update(value: value > 0 ? String(format: "%.0f", value) : "—")
            }
            .store(in: &cancellables)
    }

    @objc private func runTapped() { viewModel.run() }
    @objc private func resetTapped() { viewModel.reset() }
    @objc private func modeChanged() {
        viewModel.mode = RaceScenarioViewModel.Mode.allCases[modeControl.selectedSegmentIndex]
    }
    @objc private func scaleChanged() {
        viewModel.scale = RaceScenarioViewModel.Scale.allCases[scaleControl.selectedSegmentIndex]
    }

    @objc private func stompTapped() {
        LabUIKit.alert(
            on: self,
            title: "确认触发并发踩踏？",
            message: "App 会立即崩溃。此操作用于演示真实 EXC_BAD_ACCESS 现场。",
            confirmTitle: "CRASH NOW",
            destructive: true
        ) { [weak self] in self?.viewModel.armStomp() }
    }
}
