import Combine
import SnapKit
import UIKit

/// Scenario 3.1 — 弱网 WebSocket 重连状态机。
///
/// 古法排查痛点：断线就立刻重连，弱网下会形成重连风暴；没有重试上限、
/// 退避与抖动，客户端和网关一起被打挂。日志只有「重连中」，没有状态迁移。
///
/// AI MCP 新实践切入点：让 Agent 读取网络 trace 与状态迁移日志，按真实
/// RTT/失败率调参（base / cap / jitter），并验证「预算耗尽后停止」而不是
/// 无限重试。
final class ReconnectViewController: LabBaseViewController {
    private let viewModel = ReconnectViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let stateTile = LabMetricTileView(label: "STATE", value: "OFFLINE", detail: "连接状态机", color: LabUI.amber)
    private let budgetTile = LabMetricTileView(label: "RETRY", value: "0 / 6", detail: "已用 / 上限", color: LabUI.cyan)
    private let delayTile = LabMetricTileView(label: "NEXT DELAY", value: "—", unit: "s", detail: "退避 + jitter", color: LabUI.mint)
    private let stateLabel = labLabel("OFFLINE", size: 12, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
    private let countdownLabel = labLabel("—", size: 30, weight: .bold, color: LabUI.amber, rounded: true, lines: 1)
    private let ledgerStack = labStack(spacing: 7)
    private let connectButton = LabButton(title: "CONNECT", style: .primary, accent: LabUI.mint)
    private let dropButton = LabButton(title: "DROP 1006", style: .secondary, accent: LabUI.amber)
    private let chaosSwitch = UISwitch()

    init() {
        super.init(accent: LabUI.mint)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "3.1 Reconnect"
        buildUI()
        bind()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.reset()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 3.1  /  WEBSOCKET",
            title: "弱网重连与指数退避",
            subtitle: "断线 → 指数退避 → ±20% jitter → 重试上限。状态机保证不会在弱网下形成重连风暴。",
            accent: LabUI.mint
        ))
        add(labMetricRow([stateTile, budgetTile, delayTile]))

        let stateCard = LabCardView(accent: LabUI.mint)
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.addArrangedSubview(LabStatusDotView(color: LabUI.mint))
        row.addArrangedSubview(labLabel("LINK STATE", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(stateLabel)
        stateCard.add(row)
        stateCard.add(makeStateStrip())
        countdownLabel.textAlignment = .center
        stateCard.add(countdownLabel)
        stateCard.add(LabUIKit.actionRow([connectButton, dropButton]))
        add(stateCard)

        let chaosCard = LabCardView(accent: LabUI.amber)
        let chaosRow = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        let chaosText = labStack(spacing: 3)
        chaosText.addArrangedSubview(labLabel("弱网自动抖动", size: 13, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 1))
        chaosText.addArrangedSubview(labLabel("连接稳定 1.5–3.5s 后强制 1006 断线", size: 10.5, color: LabUI.textTertiary))
        chaosRow.addArrangedSubview(chaosText)
        chaosSwitch.onTintColor = LabUI.amber
        chaosRow.addArrangedSubview(chaosSwitch)
        chaosCard.add(chaosRow)
        add(chaosCard)

        let policy = LabCardView(accent: LabUI.cyan)
        policy.add(labLabel("RETRY POLICY", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        policy.add(LabCodeBlockView(
            code: "base = min(8, 0.5 × 2^(retry-1))\njitter = random(0.8...1.2)\ndelay = min(8, base × jitter)\nif retry >= 6: state = EXHAUSTED",
            accent: LabUI.cyan
        ))
        add(policy)

        let ledger = LabCardView(accent: LabUI.amber)
        ledger.add(labLabel("RETRY LEDGER", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        ledger.add(ledgerStack)
        add(ledger)

        add(LabCalloutView(
            kind: .problem,
            message: "「断线就重连」在弱网下是重连风暴：没有上限会持续打网关，没有 jitter 会让所有客户端同时重试。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "让 Agent 读取网络 trace 与状态日志，按失败率/RTT 调整 base、cap 和 jitter；再验证预算耗尽后确实停止，而不是偷偷无限重试。"
        ))
        add(LabConsoleView(store: viewModel.console, title: "WS LOG", height: 190, accent: LabUI.mint))
        connectButton.accessibilityIdentifier = "ws.connect"
        dropButton.accessibilityIdentifier = "ws.drop"
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        dropButton.addTarget(self, action: #selector(dropTapped), for: .touchUpInside)
        chaosSwitch.addTarget(self, action: #selector(chaosChanged), for: .valueChanged)
    }

    private func makeStateStrip() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 5, alignment: .center)
        row.distribution = .fillEqually
        for state in [ReconnectViewModel.LinkState.offline, .connecting, .connected, .backoff, .exhausted] {
            let chip = labLabel(state.rawValue, size: 8, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
            chip.textAlignment = .center
            chip.backgroundColor = LabUI.surfaceRaised
            chip.layer.cornerRadius = 6
            chip.layer.masksToBounds = true
            chip.snp.makeConstraints { make in make.height.equalTo(24) }
            row.addArrangedSubview(chip)
        }
        return row
    }

    private func bind() {
        viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                stateLabel.text = state.rawValue
                stateLabel.textColor = state.color
                stateTile.update(
                    value: state.rawValue,
                    detail: state.title,
                    color: state.color
                )
                connectButton.setTitle(state == .connected ? "DISCONNECT" : "CONNECT", for: .normal)
            }
            .store(in: &cancellables)

        viewModel.$retryCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self else { return }
                budgetTile.update(value: "\(count) / \(viewModel.maxRetries)")
            }
            .store(in: &cancellables)

        viewModel.$retryRemaining
            .receive(on: RunLoop.main)
            .sink { [weak self] remaining in
                guard let self else { return }
                if remaining > 0 {
                    countdownLabel.text = String(format: "%.1fs", remaining)
                    countdownLabel.textColor = LabUI.amber
                } else {
                    countdownLabel.text = "—"
                }
                delayTile.update(value: viewModel.nextDelay > 0 ? String(format: "%.1f", viewModel.nextDelay) : "—")
            }
            .store(in: &cancellables)

        viewModel.$history
            .receive(on: RunLoop.main)
            .sink { [weak self] history in self?.renderHistory(history) }
            .store(in: &cancellables)
    }

    private func renderHistory(_ history: [ReconnectViewModel.RetryRecord]) {
        ledgerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !history.isEmpty else {
            ledgerStack.addArrangedSubview(labLabel("还没有重试记录。连接后断开即可观察退避账本。", size: 11, color: LabUI.textTertiary))
            return
        }
        for record in history {
            let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
            row.addArrangedSubview(labLabel("#\(record.index)", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
            row.addArrangedSubview(labLabel(record.reason, size: 9.5, color: LabUI.textSecondary, lines: 1))
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(spacer)
            row.addArrangedSubview(labLabel(
                String(format: "base %.1fs  %@  → %.1fs", record.baseDelay, record.jitterLabel, record.finalDelay),
                size: 9,
                color: LabUI.textTertiary,
                mono: true,
                lines: 1
            ))
            ledgerStack.addArrangedSubview(row)
        }
    }

    @objc private func connectTapped() {
        viewModel.connect()
    }

    @objc private func dropTapped() {
        viewModel.simulateWeakNetworkDrop()
    }

    @objc private func chaosChanged() {
        viewModel.chaosEnabled = chaosSwitch.isOn
    }
}
