import Combine
import SnapKit
import UIKit

/// Scenario 1.2 — Allocations 锯齿与长列表。
///
/// 古法排查痛点：内存曲线只看到「总体不涨」，但 Allocations 的瞬时尖峰与
/// 短命对象仍会触发频繁 GC/autorelease 抖动；没有 Generation 标记，很难
/// 把尖峰归因到具体列表行或一次 tick。
///
/// AI MCP 新实践切入点：让 Agent 把 Allocations 的 generation 与滚动/定时器
/// 时间轴对齐，自动指出「哪个 tick 的 buffer 持有过久」，而不是人工比对两条曲线。
final class AllocationStormViewController: LabBaseViewController, UITableViewDataSource {
    private let viewModel = AllocationStormViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let footprintTile = LabMetricTileView(
        label: "FOOTPRINT", value: "—", unit: "MB", detail: "当前进程占用", color: LabUI.mint
    )
    private let peakTile = LabMetricTileView(
        label: "PEAK", value: "—", unit: "MB", detail: "观测窗口峰值", color: LabUI.coral
    )
    private let churnTile = LabMetricTileView(
        label: "CHURN", value: "—", unit: "MB", detail: "累计临时分配", color: LabUI.amber
    )
    private let sparkline = LabSparklineView(color: LabUI.mint)
    private let runButton = LabButton(title: "START STORM", style: .primary, accent: LabUI.mint)
    private let resetButton = LabButton(title: "RESET", style: .ghost)
    private lazy var intensityControl = LabUIKit.segmented(
        items: AllocationStormViewModel.Intensity.allCases.map(\.title),
        accent: LabUI.mint,
        selected: 1
    )
    private let table = UITableView(frame: .zero, style: .plain)

    init() {
        super.init(accent: LabUI.mint)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "1.2 Allocations"
        buildUI()
        bind()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 1.2  /  ALLOCATIONS",
            title: "内存锯齿与突发峰值",
            subtitle: "高频分配 256KB 临时缓冲，同时滚动 5,000 行长列表；每个可见行还会瞬时分配 2KB Data。",
            accent: LabUI.mint
        ))
        add(labMetricRow([footprintTile, peakTile, churnTile]))

        let chartCard = LabCardView(accent: LabUI.mint)
        chartCard.add(labLabel("FOOTPRINT / 90 SAMPLES", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        chartCard.add(sparkline)
        sparkline.snp.makeConstraints { make in make.height.equalTo(70) }
        chartCard.add(labLabel("锯齿来自「分配若干 tick → 一次性释放」的池策略；峰值比平稳值更重要。", size: 10, color: LabUI.textTertiary))
        add(chartCard)

        let controls = LabCardView(accent: LabUI.mint)
        controls.add(intensityControl)
        controls.add(LabUIKit.actionRow([runButton, resetButton]))
        controls.add(labLabel("定时器每 80ms 分配一批 buffer；持有 4–10 tick 后整体释放。", size: 10.5, color: LabUI.textTertiary))
        add(controls)

        let listCard = LabCardView(accent: LabUI.cyan, padding: 0)
        listCard.add(labLabel("LIVE FEED  /  5,000 ROWS", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = 38
        table.dataSource = self
        table.register(MarketCell.self, forCellReuseIdentifier: MarketCell.reuseID)
        table.showsVerticalScrollIndicator = false
        table.snp.makeConstraints { make in make.height.equalTo(260) }
        listCard.add(table)
        listCard.add(labLabel("滚动列表时每行的 checksum 会分配 2KB Data——把「滚动」也变成 allocation 来源。", size: 10, color: LabUI.textTertiary))
        add(listCard)

        add(LabCalloutView(
            kind: .problem,
            message: "「内存没一直涨」不等于没问题：短命大对象会把峰值推高，触发压缩/回收，表现为滚动抖动；只看平均占用会漏掉 generation 级尖峰。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "让 Agent 读取 Allocations 的 generation 与时间轴，自动对齐 tick / 滚动事件；再按「分配点 → 持有链 → 释放点」输出可执行的优化建议。"
        ))

        let recipe = LabCardView(accent: LabUI.amber)
        recipe.add(labLabel("ALLOCATIONS RECIPE", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        recipe.add(LabTimelineRowView(time: "01", title: "Mark Generation", detail: "启动前打一个 generation 标记。", color: LabUI.amber))
        recipe.add(LabTimelineRowView(time: "02", title: "Start Storm", detail: "运行 5–8 秒，同时滚动列表。", color: LabUI.amber))
        recipe.add(LabTimelineRowView(time: "03", title: "Peak / Persistent", detail: "对比峰值与持续占用，区分 churn 与泄漏。", color: LabUI.amber))
        recipe.add(LabTimelineRowView(time: "04", title: "AI 归因", detail: "让 Agent 关联 tick 日志与 generation 曲线。", color: LabUI.amber, isLast: true))
        add(recipe)

        add(LabConsoleView(store: viewModel.console, title: "ALLOCATION LOG", height: 190, accent: LabUI.mint))
        runButton.accessibilityIdentifier = "alloc.toggle"
        intensityControl.accessibilityIdentifier = "alloc.intensity"
        runButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        intensityControl.addTarget(self, action: #selector(intensityChanged), for: .valueChanged)
    }

    private func bind() {
        viewModel.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                guard let self else { return }
                runButton.setTitle(running ? "STOP STORM" : "START STORM", for: .normal)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(viewModel.$footprintMB, viewModel.$peakMB, viewModel.$churnedMB)
            .receive(on: RunLoop.main)
            .sink { [weak self] footprint, peak, churn in
                self?.footprintTile.update(value: String(format: "%.1f", footprint))
                self?.peakTile.update(value: String(format: "%.1f", peak))
                self?.churnTile.update(value: String(format: "%.0f", churn))
            }
            .store(in: &cancellables)

        viewModel.$samples
            .receive(on: RunLoop.main)
            .sink { [weak self] samples in self?.sparkline.update(samples) }
            .store(in: &cancellables)
    }

    @objc private func toggleTapped() {
        viewModel.isRunning ? viewModel.stop() : viewModel.start()
    }

    @objc private func resetTapped() {
        viewModel.reset()
    }

    @objc private func intensityChanged() {
        viewModel.intensity = AllocationStormViewModel.Intensity(rawValue: intensityControl.selectedSegmentIndex + 1) ?? .standard
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.feed.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MarketCell.reuseID, for: indexPath) as! MarketCell
        let row = viewModel.feed[indexPath.row]
        let checksum = AllocationStormEngine.rowChecksum(indexPath.row)
        cell.configure(row: row, checksum: checksum)
        return cell
    }
}

private final class MarketCell: UITableViewCell {
    static let reuseID = "MarketCell"
    private let symbol = labLabel(size: 11, weight: .semibold, color: LabUI.textPrimary, mono: true, lines: 1)
    private let price = labLabel(size: 11, color: LabUI.cyan, mono: true, lines: 1)
    private let change = labLabel(size: 10, color: LabUI.textTertiary, mono: true, lines: 1)
    private let checksum = labLabel(size: 7, color: LabUI.textTertiary, mono: true, lines: 1)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        row.addArrangedSubview(symbol)
        row.addArrangedSubview(price)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(change)
        row.addArrangedSubview(checksum)
        contentView.addSubview(row)
        row.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(row: MarketRow, checksum: Int) {
        symbol.text = row.symbol
        price.text = String(format: "%.1f", row.price)
        change.text = String(format: "%+.2f%%", row.change)
        change.textColor = row.change >= 0 ? LabUI.mint : LabUI.coral
        self.checksum.text = String(checksum, radix: 16)
    }
}
