import SnapKit
import UIKit

/// 五个模块首页共用的 UIKit 骨架。
///
/// 这里刻意把「页面结构」和「模块内容」拆开：子类只提供 metrics / mission /
/// routes，布局全部在基类完成。迁移到 UIKit 后仍然保持 MVVM 的边界——首页
/// 只做导航与静态说明，不承载业务状态。
class ModuleHomeViewController: LabBaseViewController {
    struct Metric {
        let label: String
        let value: String
        let unit: String?
        let detail: String?
        let color: UIColor

        init(_ label: String, _ value: String, unit: String? = nil, detail: String? = nil, color: UIColor = LabUI.cyan) {
            self.label = label
            self.value = value
            self.unit = unit
            self.detail = detail
            self.color = color
        }
    }

    struct Scenario {
        let index: String
        let title: String
        let subtitle: String
        let tags: [String]
        let expectation: String
        let identifier: String
        let destination: () -> UIViewController
    }

    let module: LabModule
    let metrics: [Metric]
    let missionKicker: String
    let missionTitle: String
    let missionBody: String
    let scenarios: [Scenario]
    let problemNote: String
    let aiNote: String

    init(
        module: LabModule,
        metrics: [Metric],
        missionKicker: String = "MISSION",
        missionTitle: String,
        missionBody: String,
        scenarios: [Scenario],
        problemNote: String,
        aiNote: String
    ) {
        self.module = module
        self.metrics = metrics
        self.missionKicker = missionKicker
        self.missionTitle = missionTitle
        self.missionBody = missionBody
        self.scenarios = scenarios
        self.problemNote = problemNote
        self.aiNote = aiNote
        super.init(accent: LabUI.accent(for: module))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = module.shortTitle
        navigationItem.largeTitleDisplayMode = .always

        add(LabModuleHeaderView(module: module))
        addMetricRow()
        addMissionCard()
        addScenarioSection()
        addSpacer(2)
        add(LabCalloutView(kind: .problem, message: problemNote))
        add(LabCalloutView(kind: .ai, message: aiNote))
    }

    private func addMetricRow() {
        let tiles = metrics.map {
            LabMetricTileView(
                label: $0.label,
                value: $0.value,
                unit: $0.unit,
                detail: $0.detail,
                color: $0.color
            )
        }
        let row = labMetricRow(tiles)
        add(row)
    }

    private func addMissionCard() {
        let card = LabCardView(accent: accent, padding: 17)
        let header = LabSectionHeaderView(
            kicker: missionKicker,
            title: missionTitle,
            trailing: "EVIDENCE FIRST",
            accent: accent
        )
        card.add(header)
        card.add(labLabel(missionBody, size: 13, color: LabUI.textSecondary, lines: 0))
        card.add(makeRouteStrip())
        add(card)
    }

    private func makeRouteStrip() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.distribution = .fillEqually
        let steps = [("01", "复现"), ("02", "观测"), ("03", "归因"), ("04", "改造")]
        for (index, step) in steps.enumerated() {
            let cell = labStack(axis: .horizontal, spacing: 6, alignment: .center)
            let badge = labLabel(step.0, size: 9, weight: .bold, color: accent, mono: true, lines: 1)
            badge.textAlignment = .center
            badge.backgroundColor = accent.withAlphaComponent(0.10)
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

    private func addScenarioSection() {
        addSpacer(2)
        add(LabSectionHeaderView(
            kicker: "SCENARIOS",
            title: "选择实验入口",
            trailing: String(format: "%02d AVAILABLE", scenarios.count),
            accent: accent
        ))

        for scenario in scenarios {
            let card = LabScenarioCard(
                index: scenario.index,
                title: scenario.title,
                subtitle: scenario.subtitle,
                tags: scenario.tags,
                expectation: scenario.expectation,
                accent: accent,
                identifier: scenario.identifier
            )
            card.addTarget(self, action: #selector(openScenario(_:)), for: .touchUpInside)
            card.tag = scenarios.firstIndex { $0.identifier == scenario.identifier } ?? 0
            add(card)
        }
    }

    @objc private func openScenario(_ sender: LabScenarioCard) {
        guard scenarios.indices.contains(sender.tag) else { return }
        push(scenarios[sender.tag].destination())
    }
}
