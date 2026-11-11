import Combine
import SnapKit
import UIKit

/// Scenario 3.2 — 高频盘口节流与差分更新。
///
/// 古法排查痛点：每条推送都直接 setState / reloadData，主线程被「事件数量」
/// 而不是屏幕刷新率驱动；全量重建 24 档视图会让 120Hz 预算瞬间爆掉。
///
/// AI MCP 新实践切入点：让 Agent 从 Instruments 的 hitch / time profile 读取
/// 实际 coalesced 比例与 apply 耗时，再调整节流窗口和 diff 粒度；不是凭感觉
/// 改 Timer 间隔。
final class OrderBookViewController: LabBaseViewController {
    private let viewModel = OrderBookViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let inTile = LabMetricTileView(label: "IN / SEC", value: "0", detail: "feed 推送", color: LabUI.mint)
    private let appliedTile = LabMetricTileView(label: "APPLIED / S", value: "0", detail: "实际渲染", color: LabUI.cyan)
    private let coalescedTile = LabMetricTileView(label: "COALESCED", value: "0%", detail: "被合并的中间态", color: LabUI.amber)
    private let spreadLabel = labLabel("SPREAD —", size: 11, weight: .bold, color: LabUI.textSecondary, mono: true, lines: 1)
    private let startButton = LabButton(title: "START FEED", style: .primary, accent: LabUI.mint)
    private let resetButton = LabButton(title: "RESET", style: .ghost)
    private lazy var modeControl = LabUIKit.segmented(
        items: OrderBookViewModel.Mode.allCases.map(\.title),
        accent: LabUI.mint,
        selected: 2
    )
    private let askRows = (0 ..< 12).map { _ in BookLevelRow(color: LabUI.coral) }
    private let bidRows = (0 ..< 12).map { _ in BookLevelRow(color: LabUI.mint) }
    private let sparkline = LabSparklineView(color: LabUI.cyan)

    init() {
        super.init(accent: LabUI.mint)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "3.2 Order Book"
        buildUI()
        bind()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.reset()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 3.2  /  MARKET DATA",
            title: "盘口节流与 Diff",
            subtitle: "feed 每 12ms 推一次全量 12 档盘口；对比直更、单槽节流、节流 + 差分三种渲染策略。",
            accent: LabUI.mint
        ))
        add(labMetricRow([inTile, appliedTile, coalescedTile]))

        let modeCard = LabCardView(accent: LabUI.mint)
        modeCard.add(modeControl)
        modeCard.add(LabUIKit.actionRow([startButton, resetButton]))
        modeCard.add(labLabel("单槽队列只保留最新全量快照；每帧最多消费一次，中间态被合并。", size: 10.5, color: LabUI.textTertiary))
        add(modeCard)

        let bookCard = LabCardView(accent: LabUI.cyan, padding: 12)
        let bookHeader = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        bookHeader.addArrangedSubview(labLabel("ORDER BOOK  /  12 LEVELS", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bookHeader.addArrangedSubview(spacer)
        bookHeader.addArrangedSubview(spreadLabel)
        bookCard.add(bookHeader)

        let asksStack = labStack(spacing: 2)
        askRows.reversed().forEach { asksStack.addArrangedSubview($0) }
        bookCard.add(asksStack)

        let spreadRow = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        spreadRow.addArrangedSubview(labLabel("SPREAD", size: 9, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        spreadRow.addArrangedSubview(labLabel("—", size: 9.5, color: LabUI.textTertiary, mono: true, lines: 1))
        bookCard.add(spreadRow)

        let bidsStack = labStack(spacing: 2)
        bidRows.forEach { bidsStack.addArrangedSubview($0) }
        bookCard.add(bidsStack)
        add(bookCard)

        let latency = LabCardView(accent: LabUI.cyan)
        latency.add(labLabel("MAIN-THREAD APPLY LATENCY", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        latency.add(sparkline)
        sparkline.snp.makeConstraints { make in make.height.equalTo(60) }
        latency.add(labLabel("每次 apply 的耗时；diff 模式只重建变化价位。", size: 10, color: LabUI.textTertiary))
        add(latency)

        add(LabHitchReadoutView(monitor: viewModel.hitch))

        add(LabCalloutView(
            kind: .problem,
            message: "「每条推送都刷新」让主线程被事件数量驱动；全量重建 24 档视图会打爆 120Hz 的 8.3ms 帧预算。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "让 Agent 读取 hitch / time profile 和 coalesced 比例，按真实帧预算调节流窗口与 diff 粒度，而不是凭感觉改 Timer。"
        ))
        add(LabCalloutView(
            kind: .insight,
            message: "行情 UI 的正确抽象是「状态」不是「事件」：全量快照可以安全替换，增量更新才需要 sequence gap 检查。"
        ))
        add(LabConsoleView(store: viewModel.console, title: "MARKET LOG", height: 170, accent: LabUI.mint))

        modeControl.accessibilityIdentifier = "book.mode"
        startButton.accessibilityIdentifier = "book.toggle"
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        startButton.addTarget(self, action: #selector(toggleFeed), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
    }

    private func bind() {
        viewModel.$isStreaming
            .receive(on: RunLoop.main)
            .sink { [weak self] streaming in
                self?.startButton.setTitle(streaming ? "STOP FEED" : "START FEED", for: .normal)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(viewModel.$updatesReceived, viewModel.$updatesApplied, viewModel.$coalesced)
            .receive(on: RunLoop.main)
            .sink { [weak self] received, _, coalesced in
                guard let self else { return }
                inTile.update(value: String(format: "%.0f", viewModel.receivedPerSecond))
                appliedTile.update(value: String(format: "%.0f", viewModel.appliedPerSecond))
                let ratio = received > 0 ? Double(coalesced) / Double(received) * 100 : 0
                coalescedTile.update(value: String(format: "%.0f%%", ratio))
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(viewModel.$bids, viewModel.$asks)
            .receive(on: RunLoop.main)
            .sink { [weak self] bids, asks in self?.render(bids: bids, asks: asks) }
            .store(in: &cancellables)

        viewModel.$applySamples
            .receive(on: RunLoop.main)
            .sink { [weak self] samples in self?.sparkline.update(samples) }
            .store(in: &cancellables)
    }

    private func render(bids: [BookLevel], asks: [BookLevel]) {
        spreadLabel.text = String(format: "SPREAD %.1f", viewModel.spread)
        for (index, row) in askRows.enumerated() {
            if index < asks.count {
                row.isHidden = false
                row.update(level: asks[asks.count - 1 - index], accent: LabUI.coral)
            } else {
                row.isHidden = true
            }
        }
        for (index, row) in bidRows.enumerated() {
            if index < bids.count {
                row.isHidden = false
                row.update(level: bids[index], accent: LabUI.mint)
            } else {
                row.isHidden = true
            }
        }
    }

    @objc private func toggleFeed() {
        viewModel.isStreaming ? viewModel.stopStreaming() : viewModel.startStreaming()
    }

    @objc private func resetTapped() {
        viewModel.reset()
    }

    @objc private func modeChanged() {
        viewModel.mode = OrderBookViewModel.Mode.allCases[modeControl.selectedSegmentIndex]
    }
}

private final class BookLevelRow: UIView {
    private let priceLabel = labLabel(size: 10, weight: .semibold, color: LabUI.textSecondary, mono: true, lines: 1)
    private let sizeLabel = labLabel(size: 9.5, color: LabUI.textTertiary, mono: true, lines: 1)
    private let bar = UIView()
    private var barWidth: Constraint?

    init(color: UIColor) {
        super.init(frame: .zero)
        bar.backgroundColor = color.withAlphaComponent(0.13)
        addSubview(bar)
        bar.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            barWidth = make.width.equalTo(0).constraint
        }
        priceLabel.textColor = color
        addSubview(priceLabel)
        addSubview(sizeLabel)
        priceLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
        }
        sizeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in make.height.equalTo(18) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(level: BookLevel, accent: UIColor) {
        priceLabel.text = String(format: "%.1f", level.price)
        sizeLabel.text = String(format: "%.2f", level.size)
        priceLabel.textColor = accent
        barWidth?.update(offset: CGFloat(min(1, level.size / 3.5)) * 120)
    }
}
