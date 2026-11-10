import SnapKit
import UIKit

/// 性能实验室首页：五条优化链路 + 两个可运行的实测入口。
///
/// 这里没有沿用 `ModuleHomeViewController` 的固定双卡布局，因为性能专题
/// 需要先建立“分层”认知，再把面试官带到真实 trace；因此顶部是 5 个
/// 主题卡，底部才是 CPU / Allocations 两个 live drill。
final class PerformanceHomeViewController: LabBaseViewController {
    private var topicRoutes: [() -> UIViewController] = []
    private var drillRoutes: [() -> UIViewController] = []

    init() {
        super.init(accent: LabUI.cyan)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "性能"

        add(LabModuleHeaderView(module: .performance))
        add(makeMetricRow())
        add(makeMissionCard())

        addSpacer(2)
        add(LabSectionHeaderView(
            kicker: "OPTIMIZATION MAP",
            title: "五条优化链路",
            trailing: "05 AREAS",
            accent: LabUI.cyan
        ))

        for topic in PerformancePlaybook.topics {
            let card = LabScenarioCard(
                index: topic.index,
                title: topic.title,
                subtitle: topic.subtitle,
                tags: tags(for: topic),
                expectation: expectation(for: topic),
                accent: topic.accent,
                identifier: "perf.topic.\(topic.id)"
            )
            card.tag = topicRoutes.count
            card.addTarget(self, action: #selector(openTopic(_:)), for: .touchUpInside)
            topicRoutes.append { PerformanceTopicViewController(topic: topic) }
            add(card)
        }

        addSpacer(2)
        add(LabSectionHeaderView(
            kicker: "LIVE DRILLS",
            title: "用真实波形收尾",
            trailing: "02 AVAILABLE",
            accent: LabUI.cyan
        ))

        let cpuCard = LabScenarioCard(
            index: "LIVE",
            title: "主线程 JSON 风暴",
            subtitle: "同步解析 6,000 条记录 + 密集正则，连续制造 >500ms 卡顿。",
            tags: ["Time Profiler", "Hitches", "Main Thread"],
            expectation: "worst pass > 500ms / dropped frames",
            accent: LabUI.coral,
            identifier: "perf.scenario.cpu"
        )
        cpuCard.tag = drillRoutes.count
        cpuCard.addTarget(self, action: #selector(openDrill(_:)), for: .touchUpInside)
        drillRoutes.append { CPUStallViewController() }
        add(cpuCard)

        let allocCard = LabScenarioCard(
            index: "LIVE",
            title: "Allocations 锯齿",
            subtitle: "长列表里高频分配 / 释放 256KB 临时缓冲，制造内存尖峰。",
            tags: ["Allocations", "Peak", "Churn"],
            expectation: "sawtooth + peak footprint",
            accent: LabUI.violet,
            identifier: "perf.scenario.alloc"
        )
        allocCard.tag = drillRoutes.count
        allocCard.addTarget(self, action: #selector(openDrill(_:)), for: .touchUpInside)
        drillRoutes.append { AllocationStormViewController() }
        add(allocCard)

        add(LabCalloutView(
            kind: .problem,
            message: "古法性能优化常从“某个 API 慢”开始，结果改了半天只是把瓶颈挪了位置。启动、UI、网络、内存、CPU 是五种不同的成本；先分层定位，再让 Instruments 给出时间/调用栈/内存图证据。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "AI/MCP 的价值不是“猜一个优化点”，而是把 App Launch trace、Time Profiler、Network trace、Memory Graph 转成可比较的清单，按影响面排序，再生成可回归的 microbenchmark。"
        ))
    }

    private func makeMetricRow() -> UIView {
        labMetricRow([
            LabMetricTileView(
                label: "LAYERS",
                value: "05",
                unit: "areas",
                detail: "5 层成本",
                color: LabUI.cyan
            ),
            LabMetricTileView(
                label: "LIVE",
                value: "02",
                unit: "drills",
                detail: "CPU / Allocations",
                color: LabUI.mint
            ),
            LabMetricTileView(
                label: "RULE",
                value: "01",
                unit: "rule",
                detail: "先测量，再改",
                color: LabUI.amber
            ),
        ])
    }

    private func makeMissionCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan, padding: 17)
        card.add(LabSectionHeaderView(
            kicker: "MISSION",
            title: "先分层，再测量",
            trailing: "EVIDENCE FIRST",
            accent: LabUI.cyan
        ))
        card.add(labLabel(
            "“用户说卡”可能来自启动、渲染、网络等待、内存压力或 CPU 排队。五条链路各自有不同指标：首帧时间、FPS/hitch、请求数与命中率、峰值内存、主线程耗时。先确认是哪一层，再谈优化。",
            size: 13,
            color: LabUI.textSecondary,
            lines: 0
        ))
        card.add(makeRouteStrip())
        return card
    }

    private func makeRouteStrip() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.distribution = .fillEqually
        let steps = [("01", "分层"), ("02", "测量"), ("03", "归因"), ("04", "改造")]
        for (index, step) in steps.enumerated() {
            let cell = labStack(axis: .horizontal, spacing: 6, alignment: .center)
            let badge = labLabel(step.0, size: 9, weight: .bold, color: LabUI.cyan, mono: true, lines: 1)
            badge.textAlignment = .center
            badge.backgroundColor = LabUI.cyan.withAlphaComponent(0.10)
            badge.layer.cornerRadius = 9
            badge.layer.masksToBounds = true
            badge.snp.makeConstraints { make in make.width.height.equalTo(19) }
            cell.addArrangedSubview(badge)
            cell.addArrangedSubview(labLabel(step.1, size: 10.5, color: LabUI.textTertiary, lines: 1))
            row.addArrangedSubview(cell)
            if index < steps.count - 1 {
                let line = UIView()
                line.backgroundColor = LabUI.hairline
                line.snp.makeConstraints { make in make.height.equalTo(1) }
                row.addArrangedSubview(line)
            }
        }
        return row
    }

    private func tags(for topic: PerformanceTopic) -> [String] {
        switch topic.id {
        case "launch": return ["Pre-main", "LTO", "Assets"]
        case "ui": return ["Core Animation", "Reuse", "Offscreen"]
        case "network": return ["Coalesce", "NSCache", "MMKV"]
        case "memory": return ["Leaks", "Memory Graph", "NSCache"]
        case "cpu": return ["Time Profiler", "GCD", "Lock"]
        default: return ["Measure"]
        }
    }

    private func expectation(for topic: PerformanceTopic) -> String {
        switch topic.id {
        case "launch": return "pre-main / main-post / package size"
        case "ui": return "60-120Hz / 0 offscreen / reuse"
        case "network": return "requests / cache hit / P95"
        case "memory": return "0 retain cycle / peak footprint"
        case "cpu": return "main <16ms / O(1) lookup"
        default: return "measure first"
        }
    }

    @objc private func openTopic(_ sender: LabScenarioCard) {
        guard topicRoutes.indices.contains(sender.tag) else { return }
        push(topicRoutes[sender.tag]())
    }

    @objc private func openDrill(_ sender: LabScenarioCard) {
        guard drillRoutes.indices.contains(sender.tag) else { return }
        push(drillRoutes[sender.tag]())
    }
}
