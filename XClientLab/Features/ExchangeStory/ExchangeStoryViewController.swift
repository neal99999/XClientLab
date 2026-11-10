import SnapKit
import UIKit

/// 面试主线第一屏：交易所专项。
///
/// 这里刻意不按“模块清单”平铺，而是按面试官真正关心的顺序讲：
/// 现象 → 难点 → 动作 → 可验证结果。两个案例都来自 IBIT 的真实问题，
/// 下面的「进入复盘」会打开可以亲手复现的 UIKit 实验页。
final class ExchangeStoryViewController: LabBaseViewController {
    init() {
        super.init(accent: LabUI.mint)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "交易所专项"

        add(LabScreenTitleView(
            index: "INTERVIEW / 01 — EXCHANGE",
            title: "交易所专项",
            subtitle: "两个问题，都是从线上现象一路追到根因，再用可量化结果收口。",
            accent: accent
        ))

        add(makeHeroCard())
        add(makePitchCard())
        add(LabSectionHeaderView(
            kicker: "TWO CASES",
            title: "先讲这两个，不要铺功能",
            trailing: "12 MIN",
            accent: accent
        ))
        add(makeCaseCard(
            index: "CASE 01",
            title: "极端行情渲染性能重构",
            problem: "100+ Tick/s 全量刷新，K 线掉到 20–30 FPS；用户点「市价平仓」，主线程还卡着，延迟超过 1 秒。",
            hardPart: "指标计算、K 线重绘、下单交互挤在同一条主线程；不能简单丢数据，否则最新价和指标会失真。",
            actions: ["子线程指标解耦", "视口裁剪 + 脏矩形", "100ms 聚合节流"],
            result: "55+ FPS · 下单 <16ms · CPU −20%",
            accent: LabUI.cyan,
            identifier: "case.render"
        ) { [weak self] in
            self?.push(RenderCaseViewController())
        })
        add(makeCaseCard(
            index: "CASE 02",
            title: "弱网假连接与订单状态竞态",
            problem: "进电梯 / Wi-Fi 切 4G 时 TCP 不回调断开，行情早停了；HTTP 慢响应又会在 WS「已成交」之后把状态改回「挂单中」。",
            hardPart: "系统网络状态不可信；HTTP 与 WS 是两个通道，事件到达顺序天然可能颠倒。",
            actions: ["5s Ping / 2 次丢 Pong", "10s 无下行强杀重连", "Sequence 版本号 + 单向状态机"],
            result: "<3s 自愈 · 订单状态零倒流 · 账实 100%",
            accent: LabUI.mint,
            identifier: "case.network"
        ) { [weak self] in
            self?.push(ConsistencyCaseViewController())
        })

        add(makeTalkTrackCard())
        add(LabCalloutView(
            kind: .insight,
            message: "讲解顺序建议：先用一句话给结果，再讲现象和代价，最后才展开三步动作。面试官追问时再打开对应案例页，现场跑一遍。"
        ))

        let more = LabButton(title: "更多工程化实验（旧实验室）", style: .ghost, accent: LabUI.cyan, systemImage: "square.grid.2x2")
        more.accessibilityIdentifier = "story.lab"
        more.addAction(UIAction { [weak self] _ in
            self?.push(LabIndexViewController())
        }, for: .touchUpInside)
        add(more)
    }

    // MARK: - Cards

    private func makeHeroCard() -> UIView {
        let card = LabCardView(accent: accent, padding: 18)
        card.add(labLabel("IBIT · GLOBAL CRYPTO EXCHANGE", size: 9.5, weight: .bold, color: accent, mono: true, lines: 1))
        card.add(labLabel(
            "行情越剧烈，越不能让用户\n为一次点击等一秒",
            size: 24,
            weight: .bold,
            color: LabUI.textPrimary,
            rounded: true
        ))
        card.add(labLabel(
            "一个负责「画得快」，一个负责「状态对」。这两个问题覆盖了交易所客户端最难的两条链路：渲染与一致性。",
            size: 12.5,
            color: LabUI.textSecondary
        ))

        let metrics = labMetricRow([
            LabMetricTileView(label: "TICK RATE", value: "100+", unit: "/s", detail: "极端行情", color: LabUI.coral),
            LabMetricTileView(label: "FRAME", value: "55+", unit: "FPS", detail: "重构后", color: LabUI.cyan),
            LabMetricTileView(label: "ORDER", value: "<16", unit: "ms", detail: "点击响应", color: LabUI.mint),
        ])
        card.add(metrics)
        card.add(labTagRow(["IBIT", "K-LINE", "ORDER BOOK", "WEAK NETWORK"], color: accent))
        return card
    }

    private func makePitchCard() -> UIView {
        let card = LabCardView(accent: LabUI.violet, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "30-SECOND PITCH",
            title: "电梯直达版",
            trailing: "先抛结果",
            accent: LabUI.violet
        ))
        card.add(labLabel(
            "“我在 IBIT 主导过极端行情下的渲染性能重构：100+ Tick/s 时把主线程重绘拆到后台，配合视口裁剪和 100ms 聚合，把 20–30 FPS 拉到 55+，下单延迟压到 16ms 内。另一个是跨国弱网：用应用层心跳识别 TCP 假连接，用 Sequence 版本号挡住订单状态倒流，自愈 3 秒内、账实 100% 一致。”",
            size: 13,
            color: LabUI.textPrimary
        ))
        card.add(labLabel(
            "这两句只负责让面试官追问；真正的证据在下面的可交互复盘里。",
            size: 11,
            color: LabUI.textTertiary
        ))
        return card
    }

    private func makeCaseCard(
        index: String,
        title: String,
        problem: String,
        hardPart: String,
        actions: [String],
        result: String,
        accent: UIColor,
        identifier: String,
        action: @escaping () -> Void
    ) -> UIView {
        let card = LabCardView(accent: accent, padding: 16)
        let meta = labStack(axis: .horizontal, spacing: 8)
        meta.addArrangedSubview(LabTagView(text: index, color: accent, filled: true))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        meta.addArrangedSubview(spacer)
        meta.addArrangedSubview(labLabel("PROBLEM → RESULT", size: 9, weight: .semibold, color: LabUI.textTertiary, mono: true, lines: 1))
        card.add(meta)
        card.add(labLabel(title, size: 20, weight: .semibold, color: LabUI.textPrimary, rounded: true))

        card.add(narrativeRow(label: "现象", text: problem, color: LabUI.coral))
        card.add(narrativeRow(label: "难点", text: hardPart, color: LabUI.amber))
        card.add(narrativeRow(label: "动作", text: actions.joined(separator: "  ·  "), color: accent))
        card.add(narrativeRow(label: "结果", text: result, color: LabUI.mint))

        let button = LabButton(title: "进入可交互复盘", style: .secondary, accent: accent, systemImage: "arrow.right")
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        card.add(button)
        return card
    }

    private func narrativeRow(label: String, text: String, color: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
        let tag = labLabel(label, size: 9.5, weight: .bold, color: color, mono: true, lines: 1)
        tag.textAlignment = .center
        tag.backgroundColor = color.withAlphaComponent(0.10)
        tag.layer.cornerRadius = 6
        tag.layer.masksToBounds = true
        tag.snp.makeConstraints { make in make.width.equalTo(34) }
        row.addArrangedSubview(tag)
        row.addArrangedSubview(labLabel(text, size: 11.5, color: LabUI.textSecondary))
        return row
    }

    private func makeTalkTrackCard() -> UIView {
        let card = LabCardView(accent: LabUI.amber, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "TALK TRACK",
            title: "面试讲述节奏",
            trailing: "4 BEATS",
            accent: LabUI.amber
        ))
        for (index, item) in [
            ("01", "结果先行", "55+ FPS、<16ms、3s 自愈——先让面试官知道值多少。"),
            ("02", "现象有代价", "不是“卡”，而是用户平仓点不动，真实亏损。"),
            ("03", "难点说清楚", "为什么不能简单丢数据、为什么 HTTP/WS 会乱序。"),
            ("04", "动作可验证", "三步方案 + 现场复现 + 指标回归。")
        ].enumerated() {
            let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
            row.addArrangedSubview(labLabel(item.0, size: 10, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
            let text = labStack(spacing: 2)
            text.addArrangedSubview(labLabel(item.1, size: 11.5, weight: .semibold, color: LabUI.textPrimary, lines: 1))
            text.addArrangedSubview(labLabel(item.2, size: 11, color: LabUI.textSecondary))
            row.addArrangedSubview(text)
            card.add(row)
            if index < 3 {
                let line = UIView()
                line.backgroundColor = LabUI.hairline
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                card.add(line)
            }
        }
        return card
    }
}
