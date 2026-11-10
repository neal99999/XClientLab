import SnapKit
import UIKit

/// 案例二：跨国弱网下的 TCP 假连接与订单状态竞态。
///
/// 两个演示都做了「时间压缩」：文案里是 5s Ping / 10s 无下行，
/// 这里用 0.6s / 1.2s 把同一套判定逻辑快速跑给面试官看。
final class ConsistencyCaseViewController: LabBaseViewController {
    private let heartbeatSwitch = UISwitch()
    private let guardSwitch = UISwitch()
    private let linkState = labLabel("TCP：已连接（等待注入）", size: 12, weight: .semibold, color: LabUI.textPrimary)
    private let linkDetail = labLabel("主动心跳：每 5s 一次 Ping，连续 2 次无 Pong 判定死链。", size: 10.5, color: LabUI.textTertiary)
    private let orderState = labLabel("挂单中 (pending)", size: 16, weight: .semibold, color: LabUI.amber, rounded: true)
    private let orderDetail = labLabel("Sequence 版本号：等待注入乱序事件。", size: 10.5, color: LabUI.textTertiary)
    private let ledger = labStack(spacing: 4)
    private var token = UUID()
    private var workItems: [DispatchWorkItem] = []

    init() {
        super.init(accent: LabUI.mint)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "02 弱网与一致性"
        add(LabScreenTitleView(
            index: "CASE 02 — CONSISTENCY",
            title: "弱网下，客户端不能\n相信“看起来还活着”",
            subtitle: "系统不告诉我们 Wi-Fi 已经切走；HTTP 与 WS 也不保证到达顺序。两件事都必须由客户端自己兜底。",
            accent: accent
        ))
        add(makeSituationCard())
        add(makeHeartbeatCard())
        add(makeRaceCard())
        add(makeResultCard())
        add(LabCalloutView(
            kind: .insight,
            message: "追问点：为什么不用系统 Reachability？它只能告诉你“有网络接口”，不能证明对端还活着，也不能解决两个通道的到达顺序。"
        ))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelPending()
    }

    // MARK: - Cards

    private func makeSituationCard() -> UIView {
        let card = LabCardView(accent: LabUI.coral, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "SITUATION",
            title: "两个隐蔽但会直接伤钱的坑",
            trailing: "GLOBAL USERS",
            accent: LabUI.coral
        ))
        card.add(labLabel(
            "① 进电梯 / 跨国漫游时，TCP 没有立刻断开，客户端仍以为长连接活着，行情其实已经停了。\n② 弱网下 HTTP 下单响应慢于 WS 成交推送，迟到的「挂单中」把「已成交」覆盖，用户看到状态反复横跳。",
            size: 12.5,
            color: LabUI.textSecondary
        ))
        card.add(labMetricRow([
            LabMetricTileView(label: "PING", value: "5", unit: "s", detail: "应用层心跳", color: LabUI.cyan),
            LabMetricTileView(label: "NO DATA", value: "10", unit: "s", detail: "判定死链", color: LabUI.amber),
            LabMetricTileView(label: "HEAL", value: "<3", unit: "s", detail: "智能重连", color: LabUI.mint),
        ]))
        return card
    }

    private func makeHeartbeatCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "A / TCP FALSE ALIVE",
            title: "应用层心跳 + 死链探测",
            trailing: "6S WINDOW",
            accent: LabUI.cyan
        ))
        card.add(labLabel(
            "系统 TCP keepalive 太慢，Reachability 又只代表“有网卡”。客户端每 5s 主动 Ping；连续 2 次没有 Pong，或 10s 没有任何下行，就强杀连接，再走 DNS 测速 + 备用节点重连。",
            size: 11.5,
            color: LabUI.textSecondary
        ))
        heartbeatSwitch.isOn = true
        heartbeatSwitch.onTintColor = LabUI.cyan
        heartbeatSwitch.accessibilityIdentifier = "net.heartbeat"
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        row.addArrangedSubview(labLabel("开启心跳探测", size: 12, color: LabUI.textPrimary))
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(heartbeatSwitch)
        card.add(row)

        let inject = LabButton(title: "注入断网 · 电梯场景", style: .secondary, accent: LabUI.cyan, systemImage: "wifi.slash")
        inject.accessibilityIdentifier = "net.drop"
        inject.addAction(UIAction { [weak self] _ in
            self?.injectDrop()
        }, for: .touchUpInside)
        card.add(inject)
        card.add(linkState)
        card.add(linkDetail)
        return card
    }

    private func makeRaceCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "B / ORDER STATE RACE",
            title: "Sequence 版本号 + 单向状态机",
            trailing: "NO ROLLBACK",
            accent: LabUI.mint
        ))
        card.add(labLabel(
            "后端给每个订单事件带单调递增 Sequence。客户端只接受比本地更新的版本；订单状态只允许 pending → filled 单向流转，迟到的历史响应直接丢弃。",
            size: 11.5,
            color: LabUI.textSecondary
        ))
        guardSwitch.isOn = true
        guardSwitch.onTintColor = LabUI.mint
        guardSwitch.accessibilityIdentifier = "net.guard"
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        row.addArrangedSubview(labLabel("开启版本号保护", size: 12, color: LabUI.textPrimary))
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(guardSwitch)
        card.add(row)

        let inject = LabButton(title: "注入乱序事件 · HTTP 慢响应", style: .secondary, accent: LabUI.mint, systemImage: "arrow.triangle.2.circlepath")
        inject.accessibilityIdentifier = "net.race"
        inject.addAction(UIAction { [weak self] _ in
            self?.injectRace()
        }, for: .touchUpInside)
        card.add(inject)
        card.add(orderState)
        card.add(orderDetail)
        card.add(ledger)
        return card
    }

    private func makeResultCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "ACTION → RESULT",
            title: "把“等网络恢复”变成“客户端主动收敛”",
            trailing: "AFTER",
            accent: LabUI.mint
        ))
        card.add(resultRow("网络层", "5s Ping / 2 次丢 Pong 或 10s 无下行 → 强杀 + 最优节点重连", LabUI.cyan))
        card.add(resultRow("业务层", "每个订单事件带 Sequence；只接受更新版本，旧版本丢弃", LabUI.mint))
        card.add(resultRow("状态层", "pending → filled 单向状态机，任何事件都不能回滚已成交", LabUI.amber))
        card.add(labMetricRow([
            LabMetricTileView(label: "SELF HEAL", value: "<3", unit: "s", detail: "电梯 / 切网", color: LabUI.mint),
            LabMetricTileView(label: "ROLLBACK", value: "0", unit: "次", detail: "订单状态倒流", color: LabUI.cyan),
            LabMetricTileView(label: "LEDGER", value: "100", unit: "%", detail: "账实一致", color: LabUI.amber),
        ]))
        return card
    }

    private func resultRow(_ left: String, _ right: String, _ color: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
        let tag = labLabel(left, size: 9.5, weight: .bold, color: color, mono: true, lines: 1)
        tag.textAlignment = .center
        tag.backgroundColor = color.withAlphaComponent(0.10)
        tag.layer.cornerRadius = 6
        tag.layer.masksToBounds = true
        tag.snp.makeConstraints { make in make.width.equalTo(46) }
        row.addArrangedSubview(tag)
        row.addArrangedSubview(labLabel(right, size: 11, color: LabUI.textSecondary))
        return row
    }

    // MARK: - Simulation

    private func cancelPending() {
        token = UUID()
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
    }

    private func after(_ delay: Double, _ block: @escaping () -> Void) {
        let current = token
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.token == current else { return }
            block()
        }
        workItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func injectDrop() {
        cancelPending()
        linkState.text = "TCP：仍显示已连接（假连接）"
        linkState.textColor = LabUI.amber
        linkDetail.text = "行情已停止，但系统没有回调断开。"

        guard heartbeatSwitch.isOn else {
            linkDetail.text = "心跳关闭：连接会一直“假活”，用户只能等下一次手动操作才发现。"
            return
        }

        after(0.6) { [weak self] in
            guard let self else { return }
            self.linkDetail.text = "Pong 丢失 1/2 · 继续等待下一次心跳"
            self.linkDetail.textColor = LabUI.amber
        }
        after(1.2) { [weak self] in
            guard let self else { return }
            self.linkDetail.text = "Pong 丢失 2/2 · 判定死链，强杀连接"
            self.linkDetail.textColor = LabUI.coral
        }
        after(1.8) { [weak self] in
            guard let self else { return }
            self.linkState.text = "RECONNECTING · DNS 测速 + 备用节点"
            self.linkState.textColor = LabUI.cyan
        }
        after(2.8) { [weak self] in
            guard let self else { return }
            self.linkState.text = "TCP：已恢复（自愈 2.8s）"
            self.linkState.textColor = LabUI.mint
            self.linkDetail.text = "8s 内完成死链识别 + 最优节点重连；线上 P95 <3s。"
            self.linkDetail.textColor = LabUI.textTertiary
        }
    }

    private func injectRace() {
        cancelPending()
        orderState.text = "挂单中 (pending) · seq=8"
        orderState.textColor = LabUI.amber
        orderDetail.text = "等待 WS 成交推送与迟到的 HTTP 响应。"
        clearLedger()

        after(0.5) { [weak self] in
            guard let self else { return }
            self.orderState.text = "已成交 (filled) · seq=12"
            self.orderState.textColor = LabUI.mint
            self.appendLedger("WS  filled  seq=12  → 已成交", color: LabUI.mint)
        }
        after(1.4) { [weak self] in
            guard let self else { return }
            if self.guardSwitch.isOn {
                self.appendLedger("HTTP pending seq=9  → 旧版本，丢弃", color: LabUI.steel)
                self.orderDetail.text = "seq 9 < 本地 12，状态保持不变；单向状态机拒绝回滚。"
                self.orderDetail.textColor = LabUI.mint
            } else {
                self.orderState.text = "挂单中 (pending) · seq=9"
                self.orderState.textColor = LabUI.coral
                self.appendLedger("HTTP pending seq=9  → 覆盖已成交 ✗", color: LabUI.coral)
                self.orderDetail.text = "没有版本号：迟到响应把状态改回 pending，用户看到状态倒流。"
                self.orderDetail.textColor = LabUI.coral
            }
        }
    }

    private func clearLedger() {
        ledger.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    private func appendLedger(_ text: String, color: UIColor) {
        let row = labLabel("→ " + text, size: 10, color: color, mono: true)
        ledger.addArrangedSubview(row)
    }
}
