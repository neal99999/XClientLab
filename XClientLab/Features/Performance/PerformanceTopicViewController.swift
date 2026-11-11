import SnapKit
import UIKit

/// 单个性能主题的详情页。
///
/// 页面结构固定为「目标 → 清单 → 古法痛点 → AI/MCP 切入点 → 现场证据」，
/// 这样五个主题讲起来是同一套节奏，面试官不会在版式上分心。
final class PerformanceTopicViewController: LabBaseViewController {
    private let topic: PerformanceTopic
    private var evidenceRoutes: [PerformanceTopic.Evidence] = []

    init(topic: PerformanceTopic) {
        self.topic = topic
        super.init(accent: topic.accent)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = topic.title

        add(LabScreenTitleView(
            index: "PERFORMANCE / \(topic.index)",
            title: topic.title,
            subtitle: topic.subtitle,
            accent: topic.accent
        ))

        add(makeStatRow())
        add(makeGoalCard())

        if topic.id == "launch" {
            add(makeLaunchDiagnostics())
        }

        addSpacer(2)
        add(LabSectionHeaderView(
            kicker: "PLAYBOOK",
            title: "优化清单",
            trailing: "MEASURE FIRST",
            accent: topic.accent
        ))

        for section in topic.sections {
            add(makeSectionCard(section))
        }

        add(LabCalloutView(kind: .problem, message: topic.pitfall))
        add(LabCalloutView(kind: .ai, message: topic.aiNote))

        addEvidenceSection()
    }

    // MARK: - Sections

    private func makeStatRow() -> UIView {
        let tiles = topic.stats.map {
            LabMetricTileView(
                label: $0.label,
                value: $0.value,
                unit: $0.unit,
                detail: $0.detail,
                color: $0.color
            )
        }
        return labMetricRow(tiles)
    }

    private func makeGoalCard() -> UIView {
        let card = LabCardView(accent: topic.accent, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "TARGET",
            title: "这一层优化什么",
            trailing: "ONE SENTENCE",
            accent: topic.accent
        ))
        card.add(labLabel(topic.goal, size: 13, color: LabUI.textSecondary, lines: 0))
        return card
    }

    private func makeSectionCard(_ section: PerformanceTopic.Section) -> UIView {
        let card = LabCardView(accent: topic.accent, padding: 15)
        card.add(LabSectionHeaderView(
            kicker: section.kicker,
            title: section.title,
            trailing: String(format: "%02d STEPS", section.points.count),
            accent: topic.accent
        ))

        for (index, point) in section.points.enumerated() {
            let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
            let number = labLabel(
                String(format: "%02d", index + 1),
                size: 9,
                weight: .bold,
                color: topic.accent,
                mono: true,
                lines: 1
            )
            number.setContentHuggingPriority(.required, for: .horizontal)
            number.snp.makeConstraints { make in make.width.equalTo(18) }
            row.addArrangedSubview(number)

            let text = labStack(spacing: 3)
            text.addArrangedSubview(labLabel(
                point.lead,
                size: 12.5,
                weight: .semibold,
                color: LabUI.textPrimary,
                lines: 0
            ))
            text.addArrangedSubview(labLabel(
                point.body,
                size: 11.5,
                color: LabUI.textSecondary,
                lines: 0
            ))
            row.addArrangedSubview(text)
            card.add(row)
        }
        return card
    }

    private func makeLaunchDiagnostics() -> UIView {
        let snapshot = PerformanceDiagnostics.snapshot()
        let card = LabCardView(accent: topic.accent, padding: 15)
        card.add(LabSectionHeaderView(
            kicker: "THIS LAUNCH",
            title: "本次启动的现场数字",
            trailing: "LIVE",
            accent: topic.accent
        ))

        let firstRow = labMetricRow([
            LabMetricTileView(
                label: "START → FRAME",
                value: snapshot.coldStartText,
                detail: "didFinish → 首帧",
                color: LabUI.cyan
            ),
            LabMetricTileView(
                label: "OBJC CLASSES",
                value: snapshot.classCountText,
                detail: "runtime 注册类",
                color: LabUI.amber
            ),
        ])
        let secondRow = labMetricRow([
            LabMetricTileView(
                label: "DYLD IMAGES",
                value: snapshot.imageCountText,
                detail: "已加载镜像",
                color: LabUI.mint
            ),
            LabMetricTileView(
                label: "APP BUNDLE",
                value: snapshot.binarySizeText,
                detail: "主 Bundle",
                color: LabUI.violet
            ),
        ])
        card.add(firstRow)
        card.add(secondRow)
        card.add(labLabel(
            "说明：冷启动是本次进程启动到首帧的差值，模拟器数字仅用于相对比较；类/镜像/包大小才是可横向回归的 pre-main 复杂度指标。",
            size: 10,
            color: LabUI.textTertiary,
            lines: 0
        ))
        return card
    }

    private func addEvidenceSection() {
        guard !topic.evidence.isEmpty else { return }
        addSpacer(2)
        add(LabSectionHeaderView(
            kicker: "LIVE EVIDENCE",
            title: "别只讲结论，现场跑一遍",
            trailing: String(format: "%02d DRILLS", topic.evidence.count),
            accent: topic.accent
        ))

        evidenceRoutes = topic.evidence
        for (index, evidence) in topic.evidence.enumerated() {
            let card = LabCardView(accent: topic.accent, padding: 13)
            let button = LabButton(
                title: evidence.title,
                style: .secondary,
                accent: topic.accent,
                systemImage: "arrow.up.right"
            )
            button.tag = index
            button.accessibilityIdentifier = evidence.identifier
            button.addTarget(self, action: #selector(openEvidence(_:)), for: .touchUpInside)
            card.add(button)
            card.add(labLabel(evidence.subtitle, size: 10.5, color: LabUI.textTertiary, lines: 0))
            add(card)
        }
    }

    @objc private func openEvidence(_ sender: LabButton) {
        guard evidenceRoutes.indices.contains(sender.tag) else { return }
        push(evidenceRoutes[sender.tag].destination())
    }
}
