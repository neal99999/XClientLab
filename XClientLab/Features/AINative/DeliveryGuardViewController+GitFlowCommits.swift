import SnapKit
import UIKit

private struct CommitTypeRule {
    let type: String
    let meaning: String
    let example: String
    let color: UIColor
}

private struct CommitCardConfig {
    let title: String
    let subtitle: String
    let trailing: String
    let accent: UIColor
    let id: String
    let formatHint: String?
    let footer: String
}

extension DeliveryGuardViewController {
    func makeCommitCoreCard() -> UIView {
        makeCommitCard(
            config: CommitCardConfig(
                title: "业务改动高频类型",
                subtitle: "覆盖日常 90% 的提交；type 必填，scope 可省。",
                trailing: "CORE 7",
                accent: LabUI.cyan,
                id: "core",
                formatHint: "<type>(<scope>): <subject>",
                footer: "标题用英文祈使句、≤72 字符、句末不加句号；破坏性改动在正文写 BREAKING CHANGE:。"
            ),
            types: [
                CommitTypeRule(type: "feat", meaning: "新功能（feature）", example: "feat(auth): add WeChat login support", color: LabUI.cyan),
                CommitTypeRule(type: "fix", meaning: "修补 Bug", example: "fix(order): fix payment timeout calculation error", color: LabUI.mint),
                CommitTypeRule(type: "docs", meaning: "文档（documentation）", example: "docs(readme): update deployment instructions", color: LabUI.steel),
                CommitTypeRule(type: "style", meaning: "格式，不影响运行", example: "style(ui): format code with Prettier", color: LabUI.violet),
                CommitTypeRule(type: "refactor", meaning: "重构，不新增功能也不修 Bug", example: "refactor(net): extract WebSocket reconnect logic", color: LabUI.amber),
                CommitTypeRule(type: "perf", meaning: "性能优化", example: "perf(chart): optimize K-line rendering frame rate", color: LabUI.coral),
                CommitTypeRule(type: "test", meaning: "增加或修改测试", example: "test(order): add unit tests for retry mechanism", color: LabUI.mint)
            ]
        )
    }

    func makeCommitOpsCard() -> UIView {
        makeCommitCard(
            config: CommitCardConfig(
                title: "工程、发布与安全类型",
                subtitle: "把构建、CI、依赖与线上安全也纳入同一套语义。",
                trailing: "OPS 7",
                accent: LabUI.violet,
                id: "ops",
                formatHint: nil,
                footer: "changelog 与 release note 直接从 type / scope 生成；不要把多个语义塞进一个 commit。"
            ),
            types: [
                CommitTypeRule(type: "chore", meaning: "构建过程或辅助工具变动", example: "chore(deps): bump axios from 1.6.0 to 1.7.0", color: LabUI.steel),
                CommitTypeRule(
                    type: "revert",
                    meaning: "撤销之前的某一 commit",
                    example: "revert: feat(order): rollback payment timeout handling",
                    color: LabUI.coral
                ),
                CommitTypeRule(
                    type: "build",
                    meaning: "构建系统或外部依赖",
                    example: "build(webpack): upgrade production config",
                    color: LabUI.amber
                ),
                CommitTypeRule(
                    type: "ci",
                    meaning: "CI 配置与脚本",
                    example: "ci(gha): add automated test workflow",
                    color: LabUI.cyan
                ),
                CommitTypeRule(
                    type: "sec",
                    meaning: "安全性修复或加固（security）",
                    example: "sec(deps): patch lodash prototype pollution vulnerability",
                    color: LabUI.coral
                ),
                CommitTypeRule(
                    type: "release",
                    meaning: "发布新版本，通常由 CI 生成",
                    example: "release: v1.2.0",
                    color: LabUI.violet
                ),
                CommitTypeRule(type: "i18n", meaning: "国际化与本地化", example: "i18n(settings): update Traditional Chinese translations", color: LabUI.mint)
            ]
        )
    }

    private func makeCommitCard(config: CommitCardConfig, types: [CommitTypeRule]) -> UIView {
        let card = LabCardView(accent: config.accent, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "CONVENTIONAL COMMITS",
            title: config.title,
            trailing: config.trailing,
            accent: config.accent
        ))
        card.add(labLabel(config.subtitle, size: 10.5, color: LabUI.textSecondary, lines: 0))
        if let formatHint = config.formatHint {
            card.add(makeCommandLine(formatHint, accent: config.accent))
        }
        for (offset, rule) in types.enumerated() {
            card.add(makeCommitRow(rule))
            if offset < types.count - 1 {
                card.add(makeDivider())
            }
        }
        card.add(labLabel(config.footer, size: 9.5, color: LabUI.textTertiary, lines: 0))
        card.accessibilityIdentifier = "gitflow.commit.\(config.id)"
        return card
    }

    private func makeCommitRow(_ rule: CommitTypeRule) -> UIView {
        let row = labStack(spacing: 5)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        let badge = labLabel(rule.type, size: 9, weight: .bold, color: rule.color, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = rule.color.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 7
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(52)
            make.height.equalTo(21)
        }
        head.addArrangedSubview(badge)
        head.addArrangedSubview(labLabel(rule.meaning, size: 10.5, weight: .semibold, color: LabUI.textPrimary, lines: 0))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        row.addArrangedSubview(head)
        row.addArrangedSubview(makeCommandLine(rule.example, accent: rule.color))
        row.accessibilityIdentifier = "gitflow.commit.type.\(rule.type)"
        return row
    }
}
