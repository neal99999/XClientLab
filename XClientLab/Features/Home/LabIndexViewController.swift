import SnapKit
import UIKit

/// 第二层入口：把 5 个模块收进一张“实验索引”，避免底部 tab 被模块数量撑满。
/// 演示动线是「先讲交易所两个案例，再从这里按追问进入真实实验」。
final class LabIndexViewController: LabBaseViewController {
    init() {
        super.init(accent: LabUI.cyan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "实验室"

        add(LabScreenTitleView(
            index: "LAB / ALL DRILLS",
            title: "选择实验模块",
            subtitle: "5 个模块、10 个可运行场景。每个场景都能单独复现；面试官追问哪一层，就从这里进哪一层。",
            accent: LabUI.cyan
        ))

        add(makeIntroCard())
        addSpacer(2)
        add(LabSectionHeaderView(
            kicker: "MODULES",
            title: "模块索引",
            trailing: "05 AVAILABLE",
            accent: LabUI.cyan
        ))

        add(makeCard(
            index: "01",
            title: "性能优化专项",
            subtitle: "主线程卡顿与 Allocations 锯齿，Instruments 两类高频场景。",
            tags: ["Time Profiler", "Allocations", "Hitches"],
            accent: LabUI.cyan,
            identifier: "lab.performance",
            destination: { PerformanceHomeViewController() }
        ))
        add(makeCard(
            index: "02",
            title: "交易所专项",
            subtitle: "弱网重连状态机与 83 条/秒盘口节流、差分更新。",
            tags: ["WebSocket", "Backoff", "Diff"],
            accent: LabUI.mint,
            identifier: "lab.exchange",
            destination: { ExchangeHomeViewController() }
        ))
        add(makeCard(
            index: "03",
            title: "异常处理攻坚",
            subtitle: "DispatchSource UAF 与 8 线程数据竞争，真实崩溃现场。",
            tags: ["LLDB", "UAF", "TSan"],
            accent: LabUI.coral,
            identifier: "lab.exceptions",
            destination: { ExceptionsHomeViewController() }
        ))
        add(makeCard(
            index: "05",
            title: "模块化架构",
            subtitle: "两个本地 SPM 包、POP + DI、Bundle.module 资源替换。",
            tags: ["SPM", "DI", "Bundle.module"],
            accent: LabUI.amber,
            identifier: "lab.architecture",
            destination: { ArchitectureHomeViewController() }
        ))

        add(LabCalloutView(
            kind: .insight,
            message: "演示动线建议：交易所主线（8–10 分钟，两个案例各一遍）→ 追问时再进实验室（性能 / 异常各 1 个）→ AI 工坊展示 Skill 与命令桩。不要把 10 个场景都跑一遍。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "AI-Native 模块单独放在底部「AI 工坊」，因为它展示的是“怎么把排查经验产品化”，不是又一个业务模块。"
        ))
    }

    private func makeIntroCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "HOW TO DEMO",
            title: "先讲价值，再看实现",
            trailing: "8–12 MIN",
            accent: LabUI.cyan
        ))
        card.add(labLabel(
            "这个 Demo 不再按「模块清单」平铺，而是先给一条对照主线：同一个主线程卡顿 / 野指针 / 盘口抖动，古法要多少步，AI + MCP 能压到几步。然后再进入实验室验证。",
            size: 12,
            color: LabUI.textSecondary,
            lines: 0
        ))
        let steps = labStack(axis: .horizontal, spacing: 6, distribution: .fillEqually)
        ["01 对照", "02 验证", "03 AI 工坊"].enumerated().forEach { index, text in
            let chip = labLabel(text, size: 9, weight: .semibold, color: LabUI.cyan, mono: true, lines: 1)
            chip.textAlignment = .center
            chip.backgroundColor = LabUI.cyan.withAlphaComponent(0.10)
            chip.layer.cornerRadius = 8
            chip.layer.masksToBounds = true
            chip.heightAnchor.constraint(equalToConstant: 24).isActive = true
            steps.addArrangedSubview(chip)
            if index < 2 {
                let line = UIView()
                line.backgroundColor = LabUI.hairline
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                steps.addArrangedSubview(line)
            }
        }
        card.add(steps)
        return card
    }

    private func makeCard(
        index: String,
        title: String,
        subtitle: String,
        tags: [String],
        accent: UIColor,
        identifier: String,
        destination: @escaping () -> UIViewController
    ) -> UIView {
        let card = LabScenarioCard(
            index: index,
            title: title,
            subtitle: subtitle,
            tags: tags,
            expectation: "OPEN MODULE",
            accent: accent,
            identifier: identifier
        )
        card.addAction(UIAction { [weak self] _ in
            self?.push(destination())
        }, for: .touchUpInside)
        return card
    }
}
