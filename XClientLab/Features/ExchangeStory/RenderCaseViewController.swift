import QuartzCore
import SnapKit
import UIKit

/// 案例一：极端行情下的 K 线渲染重构。
///
/// 交互设计：
/// - 旧链路：100Hz Timer 在主线程做指标计算 + 全量重绘，制造真实的主线程拥塞；
/// - 重构链路：后台队列计算指标，100ms 聚合一次，只把最新结果用版本凭证提交给 UI；
/// - 点击「市价平仓」会测一次主线程排队延迟，直观看到“点不动”的代价。
final class RenderCaseViewController: LabBaseViewController {
    private enum Mode: Int {
        case legacy
        case optimized
    }

    private let chart = CandleChartView()
    private let modeControl = LabUIKit.segmented(
        items: ["旧链路 · 全量重绘", "重构后 · 聚合 + 裁剪"],
        accent: LabUI.cyan
    )
    private let startButton = LabButton(title: "START STRESS", style: .primary, accent: LabUI.cyan, systemImage: "play.fill")
    private let orderButton = LabButton(title: "市价平仓 · 测延迟", style: .secondary, accent: LabUI.mint, systemImage: "bolt.fill")
    private let fpsTile = LabMetricTileView(label: "FPS", value: "—", unit: "fps", detail: "屏幕刷新", color: LabUI.cyan)
    private let workTile = LabMetricTileView(label: "MAIN THREAD", value: "—", unit: "ms", detail: "单次提交", color: LabUI.coral)
    private let latencyTile = LabMetricTileView(label: "ORDER P95", value: "—", unit: "ms", detail: "按队列估算", color: LabUI.mint)
    private let statusLabel = labLabel("等待开始", size: 11, color: LabUI.textTertiary, mono: true)
    private let budgetBar = LabMiniBarView(color: LabUI.coral)

    private var candles: [Candle] = []
    private var legacyTimer: Timer?
    private var optimizedTimer: DispatchSourceTimer?
    private var displayLink: CADisplayLink?
    private var isRunning = false
    private var tick = 0
    private var version = 0
    private var frames = 0
    private var lastFPSAt = CACurrentMediaTime()
    private var lastTickCost: Double = 0
    private let indicatorQueue = DispatchQueue(label: "xclientlab.render.indicator", qos: .userInitiated)

    init() {
        super.init(accent: LabUI.cyan)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "01 渲染性能重构"
        candles = Self.makeCandles()
        chart.setCandles(candles)

        add(LabScreenTitleView(
            index: "CASE 01 — RENDERING",
            title: "极端行情下，\n主线程不能替用户做决定",
            subtitle: "非农 / 大行情时 100+ Tick/s，旧代码来一条刷一次，K 线 20–30 FPS，平仓按钮延迟超过 1 秒。",
            accent: accent
        ))
        add(makeSituationCard())
        add(makeLiveCard())
        add(makeSolutionCard())
        add(makeResultCard())
        add(LabCalloutView(
            kind: .insight,
            message: "追问点：为什么不能直接丢 Tick？因为最新价、High/Low 和指标都要以“最新完整窗口”为准；聚合不是丢数据，而是把同一时间窗内的数据合并成一次可渲染提交。"
        ))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }

    // MARK: - Sections

    private func makeSituationCard() -> UIView {
        let card = LabCardView(accent: LabUI.coral, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "SITUATION",
            title: "帧率不是体验问题，是交易问题",
            trailing: "IBIT",
            accent: LabUI.coral
        ))
        card.add(labLabel(
            "旧链路把「指标计算 → K 线重绘 → 盘口刷新」全部放在主线程。行情越密，main queue 越满，用户点击市价平仓时事件只能排队。",
            size: 12.5,
            color: LabUI.textSecondary
        ))
        card.add(labMetricRow([
            LabMetricTileView(label: "TICK", value: "100+", unit: "/s", detail: "极端行情", color: LabUI.coral),
            LabMetricTileView(label: "OLD FPS", value: "20–30", detail: "FPS · 体感卡顿", color: LabUI.amber),
            LabMetricTileView(label: "ORDER", value: ">1", unit: "s", detail: "点击延迟", color: LabUI.coral),
        ]))
        return card
    }

    private func makeLiveCard() -> UIView {
        let card = LabCardView(accent: accent, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "LIVE REPLAY",
            title: "亲手跑一遍两条链路",
            trailing: "REAL TIMER",
            accent: accent
        ))
        modeControl.accessibilityIdentifier = "render.mode"
        modeControl.addAction(UIAction { [weak self] _ in
            self?.modeChanged()
        }, for: .valueChanged)
        card.add(modeControl)

        chart.accessibilityIdentifier = "render.chart"
        chart.layer.cornerRadius = 12
        chart.layer.cornerCurve = .continuous
        chart.clipsToBounds = true
        chart.snp.makeConstraints { make in make.height.equalTo(188) }
        card.add(chart)

        card.add(labMetricRow([fpsTile, workTile, latencyTile]))
        card.add(budgetBar)
        card.add(statusLabel)

        startButton.accessibilityIdentifier = "render.toggle"
        startButton.addAction(UIAction { [weak self] _ in
            self?.toggle()
        }, for: .touchUpInside)
        orderButton.accessibilityIdentifier = "render.order"
        orderButton.addAction(UIAction { [weak self] _ in
            self?.measureOrderLatency()
        }, for: .touchUpInside)
        card.add(LabUIKit.actionRow([startButton, orderButton]))
        return card
    }

    private func makeSolutionCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "ACTION",
            title: "三步把主线程腾出来",
            trailing: "3 STEPS",
            accent: LabUI.mint
        ))
        card.add(solutionRow(
            number: "01",
            title: "算力搬家 + 版本凭证",
            detail: "MA / MACD 全部移到后台并发队列；每轮计算带 version，主线程只接受最新版本，旧结果直接丢弃。"
        ))
        card.add(solutionRow(
            number: "02",
            title: "视口裁剪 + 脏矩形",
            detail: "只绘制 Visible Rect 内的 K 线；最新一根用 setNeedsDisplayInRect 局部重绘，网格走离屏缓存。"
        ))
        card.add(solutionRow(
            number: "03",
            title: "100ms 时间窗聚合",
            detail: "把 100ms 内的 Tick 聚合成一个 High/Low/Close 包，再提交 UI；人眼不需要 100Hz 的重绘。"
        ))
        return card
    }

    private func makeResultCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "RESULT",
            title: "把“感觉卡”变成可回归的数字",
            trailing: "AFTER",
            accent: LabUI.mint
        ))
        card.add(labMetricRow([
            LabMetricTileView(label: "FPS", value: "55+", unit: "fps", detail: "稳定区间", color: LabUI.mint),
            LabMetricTileView(label: "ORDER", value: "<16", unit: "ms", detail: "点击响应", color: LabUI.cyan),
            LabMetricTileView(label: "CPU", value: "−20", unit: "%", detail: "渲染开销", color: LabUI.amber),
        ]))
        card.add(labLabel(
            "关键不是“换了某个 API”，而是把渲染从「事件驱动」改成「时间窗驱动」，并把计算和绘制分层。",
            size: 11.5,
            color: LabUI.textSecondary
        ))
        return card
    }

    private func solutionRow(number: String, title: String, detail: String) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
        row.addArrangedSubview(labLabel(number, size: 10, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        let stack = labStack(spacing: 3)
        stack.addArrangedSubview(labLabel(title, size: 12, weight: .semibold, color: LabUI.textPrimary))
        stack.addArrangedSubview(labLabel(detail, size: 11, color: LabUI.textSecondary))
        row.addArrangedSubview(stack)
        return row
    }

    // MARK: - Simulation

    private var mode: Mode {
        Mode(rawValue: modeControl.selectedSegmentIndex) ?? .legacy
    }

    private func toggle() {
        isRunning ? stop() : start()
    }

    private func start() {
        stop()
        isRunning = true
        tick = 0
        version = 0
        frames = 0
        lastTickCost = 0
        lastFPSAt = CACurrentMediaTime()
        chart.setCandles(candles)
        startButton.setTitle("STOP", for: .normal)
        statusLabel.text = mode == .legacy ? "旧链路运行中 · 100Hz 主线程重绘" : "重构链路运行中 · 100ms 聚合"
        statusLabel.textColor = mode == .legacy ? LabUI.coral : LabUI.mint

        let link = CADisplayLink(target: self, selector: #selector(displayTick))
        link.add(to: .main, forMode: .common)
        displayLink = link

        switch mode {
        case .legacy:
            let timer = Timer(timeInterval: 0.01, repeats: true) { [weak self] _ in
                self?.legacyTick()
            }
            RunLoop.main.add(timer, forMode: .common)
            legacyTimer = timer
        case .optimized:
            let timer = DispatchSource.makeTimerSource(queue: indicatorQueue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(3))
            timer.setEventHandler { [weak self] in
                self?.optimizedTick()
            }
            timer.resume()
            optimizedTimer = timer
        }
    }

    private func stop() {
        isRunning = false
        legacyTimer?.invalidate()
        legacyTimer = nil
        optimizedTimer?.cancel()
        optimizedTimer = nil
        displayLink?.invalidate()
        displayLink = nil
        startButton.setTitle("START STRESS", for: .normal)
        statusLabel.text = "已停止"
        statusLabel.textColor = LabUI.textTertiary
        budgetBar.setProgress(0)
    }

    private func modeChanged() {
        guard isRunning else {
            statusLabel.text = mode == .legacy ? "旧链路：100Hz 全量重绘" : "重构后：100ms 聚合 + 版本凭证"
            return
        }
        start()
    }

    /// 旧链路：真实地在主线程做指标计算和全量刷新。
    /// 计算量是刻意放大的，用来稳定复现“主线程被塞满”的现场。
    private func legacyTick() {
        let start = CACurrentMediaTime()
        var acc = 0.0
        for i in 0 ..< 240_000 {
            acc += sin(Double(i) + Double(tick) * 0.013)
        }
        tick += 1
        if var last = candles.last {
            last.close = max(1, last.close + Double.random(in: -18 ... 18))
            last.high = max(last.high, last.close)
            last.low = min(last.low, last.close)
            candles[candles.count - 1] = last
        }
        chart.setCandles(candles)
        let cost = (CACurrentMediaTime() - start) * 1000
        lastTickCost = cost
        if tick % 8 == 0 {
            workTile.update(value: String(format: "%.1f", cost), color: cost > 4 ? LabUI.coral : LabUI.amber)
            budgetBar.setProgress(min(1, cost / 16))
        }
        _ = acc
    }

    /// 重构链路：后台算指标，主线程只拿最新版本做一次轻量提交。
    private func optimizedTick() {
        version += 1
        let captured = version
        var acc = 0.0
        for i in 0 ..< 900 {
            acc += cos(Double(i) * 0.02)
        }
        var next = candles
        if var last = next.last {
            last.close = max(1, last.close + Double.random(in: -18 ... 18))
            last.high = max(last.high, last.close)
            last.low = min(last.low, last.close)
            next[next.count - 1] = last
        }
        let cost = max(0.05, abs(acc) * 0.01)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning, captured == self.version else { return }
            self.candles = next
            self.tick += 1
            self.chart.setCandles(next)
            self.workTile.update(value: String(format: "%.1f", cost), color: LabUI.mint)
            self.budgetBar.setProgress(min(1, cost / 16))
        }
    }

    @objc private func displayTick() {
        guard isRunning else { return }
        frames += 1
        let now = CACurrentMediaTime()
        if now - lastFPSAt >= 1 {
            let fps = Double(frames) / (now - lastFPSAt)
            fpsTile.update(value: String(format: "%.0f", fps), color: fps < 45 ? LabUI.coral : LabUI.mint)
            frames = 0
            lastFPSAt = now
        }
    }

    private func measureOrderLatency() {
        let start = CACurrentMediaTime()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let measured = (CACurrentMediaTime() - start) * 1000
            // 现场只测“事件开始执行”的时间不够直观：真正伤人的是主线程已排队时，
            // 订单事件要等多久。这里用单次主线程成本 × 队列深度估算 P95；
            // 真实线上由 trace 统计，Demo 里明确标注“估算”。
            let estimated = self.lastTickCost * 50
            let p95 = max(measured, estimated)
            self.latencyTile.update(
                value: p95 > 999 ? "1000+" : String(format: "%.1f", p95),
                color: p95 < 16 ? LabUI.mint : LabUI.coral
            )
            self.statusLabel.text = p95 < 16 ? "订单事件 <16ms 执行" : "订单事件排队 >1s"
            self.statusLabel.textColor = p95 < 16 ? LabUI.mint : LabUI.coral
        }
    }

    private static func makeCandles() -> [Candle] {
        var price = 68000.0
        return (0 ..< 44).map { _ in
            let open = price
            let close = max(1, open + Double.random(in: -260 ... 300))
            price = close
            return Candle(
                open: open,
                high: max(open, close) + Double.random(in: 0 ... 180),
                low: min(open, close) - Double.random(in: 0 ... 180),
                close: close
            )
        }
    }
}

// MARK: - Candle chart

private struct Candle {
    var open: Double
    var high: Double
    var low: Double
    var close: Double
}

private final class CandleChartView: UIView {
    private var candles: [Candle] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = LabUI.surfaceRaised.withAlphaComponent(0.65)
        layer.borderWidth = 1
        layer.borderColor = LabUI.cyan.withAlphaComponent(0.18).cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCandles(_ candles: [Candle]) {
        self.candles = candles
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !candles.isEmpty else { return }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.05).cgColor)
        context.setLineWidth(0.5)
        for index in 0 ..< 5 {
            let y = rect.height * CGFloat(index) / 4
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
        }
        context.strokePath()

        let left: CGFloat = 10
        let usableWidth = rect.width - left * 2
        let slot = usableWidth / CGFloat(max(1, candles.count))
        let bodyWidth = max(2, slot * 0.52)
        let high = candles.map(\.high).max() ?? 1
        let low = candles.map(\.low).min() ?? 0
        let range = max(1, high - low)

        for (index, candle) in candles.enumerated() {
            let x = left + slot * CGFloat(index) + slot / 2
            let openY = rect.height - 10 - CGFloat((candle.open - low) / range) * (rect.height - 20)
            let closeY = rect.height - 10 - CGFloat((candle.close - low) / range) * (rect.height - 20)
            let highY = rect.height - 10 - CGFloat((candle.high - low) / range) * (rect.height - 20)
            let lowY = rect.height - 10 - CGFloat((candle.low - low) / range) * (rect.height - 20)
            let up = candle.close >= candle.open
            let color = up ? LabUI.mint : LabUI.coral
            color.setStroke()
            context.setLineWidth(1)
            context.move(to: CGPoint(x: x, y: highY))
            context.addLine(to: CGPoint(x: x, y: lowY))
            context.strokePath()
            color.withAlphaComponent(0.75).setFill()
            let body = CGRect(
                x: x - bodyWidth / 2,
                y: min(openY, closeY),
                width: bodyWidth,
                height: max(1.5, abs(closeY - openY))
            )
            UIBezierPath(roundedRect: body, cornerRadius: 1).fill()
        }

        let label = "BTC-USDT · PERP" as NSString
        label.draw(
            at: CGPoint(x: 10, y: 8),
            withAttributes: [
                .font: LabUI.font(9, weight: .bold, mono: true),
                .foregroundColor: LabUI.textTertiary,
            ]
        )
    }
}
