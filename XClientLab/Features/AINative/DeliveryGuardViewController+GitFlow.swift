import SnapKit
import UIKit

private struct GitBranchRole {
    let key: String
    let name: String
    let flow: String
    let lifetime: String
    let rule: String
    let color: UIColor
}

private struct GitStep {
    let index: String
    let title: String
    let command: String
    let detail: String
    let color: UIColor
}

extension DeliveryGuardViewController {
    // MARK: - Lead

    func makeGitFlowLeadCallout() -> UIView {
        LabCalloutView(
            kind: .insight,
            message: "main 永远可发布；develop 集成下一版；feature / release / hotfix 都是短命分支，用完即删。"
        )
    }

    // MARK: - Branch roles

    func makeGitFlowBranchCard() -> UIView {
        let card = LabCardView(accent: LabUI.violet, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "BRANCH MODEL",
            title: "五条分支的角色边界",
            trailing: "SOURCE → MERGE",
            accent: LabUI.violet
        ))
        card.add(labLabel(
            "长期分支只有 main 与 develop；所有短分支必须能回答「从哪来、回哪去、活多久」。",
            size: 10.5,
            color: LabUI.textSecondary,
            lines: 0
        ))

        let branches = [
            GitBranchRole(
                key: "main",
                name: "main",
                flow: "来源 —  ·  合并去向 —",
                lifetime: "永久",
                rule: "永远可发布；只接受 release/* 与 hotfix/*；每次合并都在 main 打 tag。",
                color: LabUI.cyan
            ),
            GitBranchRole(
                key: "develop",
                name: "develop",
                flow: "来源 main  ·  合并去向 —",
                lifetime: "永久",
                rule: "集成主分支；接收 feature/*；代表「下一个版本的样子」。",
                color: LabUI.mint
            ),
            GitBranchRole(
                key: "feature",
                name: "feature/*",
                flow: "来源 develop  ·  合并去向 develop",
                lifetime: "天级",
                rule: "一个需求 / 一个 issue 一条分支；只做一件事，建议不超过 3 天。",
                color: LabUI.violet
            ),
            GitBranchRole(
                key: "release",
                name: "release/*",
                flow: "来源 develop  ·  合并去向 main + develop",
                lifetime: "天~周级",
                rule: "功能冻结；只允许 bugfix、版本号、元数据；发布后双回合。",
                color: LabUI.amber
            ),
            GitBranchRole(
                key: "hotfix",
                name: "hotfix/*",
                flow: "来源 main  ·  合并去向 main + develop",
                lifetime: "小时~天级",
                rule: "线上紧急修复，从 main 拉出；修完打 patch tag，并回合 develop。",
                color: LabUI.coral
            )
        ]

        for (offset, branch) in branches.enumerated() {
            card.add(makeGitBranchRow(branch))
            if offset < branches.count - 1 {
                card.add(makeDivider())
            }
        }

        card.add(makeBanner(
            text: "两条最容易踩的返工点：release 与 hotfix 合并 main 后，都必须回合 develop。",
            color: LabUI.coral,
            symbol: "exclamationmark.triangle.fill"
        ))
        return card
    }

    private func makeGitBranchRow(_ branch: GitBranchRole) -> UIView {
        let row = labStack(spacing: 5)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        head.addArrangedSubview(labLabel(
            branch.name,
            size: 12.5,
            weight: .bold,
            color: branch.color,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        head.addArrangedSubview(LabTagView(text: branch.lifetime, color: branch.color))
        row.addArrangedSubview(head)
        row.addArrangedSubview(labLabel(
            branch.flow,
            size: 9.5,
            weight: .medium,
            color: LabUI.textTertiary,
            mono: true,
            lines: 0
        ))
        row.addArrangedSubview(labLabel(branch.rule, size: 10.5, color: LabUI.textSecondary, lines: 0))
        row.accessibilityIdentifier = "gitflow.branch.\(branch.key)"
        return row
    }

    // MARK: - Naming, merge, discipline

    func makeGitFlowWorkflowCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "DAILY WORKFLOW",
            title: "命名、合并与分支纪律",
            trailing: "NO DIRECT PUSH",
            accent: LabUI.cyan
        ))
        card.add(labLabel("分支命名", size: 11, weight: .bold, color: LabUI.cyan, lines: 1))
        let naming = [
            "feature/JIRA-123-export-csv",
            "release/1.4.0",
            "hotfix/1.4.1",
            "",
            "# 语义化版本；tag 只打在 main",
            "git tag -a v1.4.0 -m \"XClientLab 1.4.0\""
        ].joined(separator: "\n")
        card.add(LabCodeBlockView(
            code: naming,
            accent: LabUI.cyan,
            title: "NAMING · SEMVER"
        ))

        card.add(labLabel("合并策略", size: 11, weight: .bold, color: LabUI.mint, lines: 1))
        card.add(makeBullet(lead: "feature → develop", detail: "PR + git merge --no-ff，保留「一个需求一个合并节点」。", accent: LabUI.mint))
        card.add(makeBullet(lead: "release / hotfix → main", detail: "PR + --no-ff，合并后在 main 打带注释 tag。", accent: LabUI.mint))
        card.add(makeBullet(lead: "本地同步", detail: "git fetch && git rebase origin/develop；已推送共享分支只 merge。", accent: LabUI.mint))
        card.add(makeBullet(lead: "分支保护", detail: "main / develop 禁止直接 push，必须 PR + CI 绿 + 至少 1 个 review。", accent: LabUI.mint))

        card.add(labLabel("feature 分支纪律", size: 11, weight: .bold, color: LabUI.violet, lines: 1))
        card.add(makeBullet(lead: "分支寿命", detail: "一条分支 < 3 天、只做一件事；超过就拆。", accent: LabUI.violet))
        card.add(makeBullet(lead: "每日同步", detail: "每天至少同步一次 develop，别攒到最后一天再 merge。", accent: LabUI.violet))
        card.add(makeBullet(lead: "合并前", detail: "在独占分支 rebase develop，把冲突解决在分支里。", accent: LabUI.violet))
        card.add(makeBullet(lead: "用完即删", detail: "git branch -d + git push origin --delete，避免僵尸分支。", accent: LabUI.violet))
        return card
    }

    // MARK: - Release & hotfix

    func makeGitFlowReleaseCard() -> UIView {
        let card = LabCardView(accent: LabUI.amber, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "RELEASE PLAYBOOK",
            title: "发布与热修标准动作",
            trailing: "NO SHORTCUT",
            accent: LabUI.amber
        ))
        card.add(makeReleaseSubhead(
            title: "release/*",
            detail: "功能冻结 → main → tag → 回合 develop → 删除",
            color: LabUI.amber
        ))
        let releaseSteps = [
            GitStep(
                index: "01",
                title: "冻结功能",
                command: "git switch -c release/1.4.0 develop",
                detail: "只允许 bugfix、版本号、changelog；新需求一律回 develop。",
                color: LabUI.cyan
            ),
            GitStep(
                index: "02",
                title: "合并 main",
                command: "git switch main\ngit merge --no-ff release/1.4.0",
                detail: "PR 评审通过后合并，保留发布点边界。",
                color: LabUI.mint
            ),
            GitStep(
                index: "03",
                title: "打 tag",
                command: "git tag -a v1.4.0 -m \"XClientLab 1.4.0\"\ngit push origin v1.4.0",
                detail: "tag 只打在 main；推送 tag 触发 cd.yml。",
                color: LabUI.amber
            ),
            GitStep(
                index: "04",
                title: "回合 develop",
                command: "git switch develop\ngit merge --no-ff main",
                detail: "漏掉这步，下一轮 release 会缺版本号与已修 bug。",
                color: LabUI.coral
            ),
            GitStep(
                index: "05",
                title: "清理分支",
                command: "git branch -d release/1.4.0\ngit push origin --delete release/1.4.0",
                detail: "本地与远端同时清理，避免僵尸分支。",
                color: LabUI.violet
            )
        ]
        for step in releaseSteps {
            card.add(makeGitStepRow(step))
        }

        card.add(makeDivider())
        card.add(makeReleaseSubhead(
            title: "hotfix/*",
            detail: "线上止血 → main → patch tag → 回合 develop → 清理",
            color: LabUI.coral
        ))
        let hotfixSteps = [
            GitStep(
                index: "01",
                title: "从 main 拉出",
                command: "git switch -c hotfix/1.4.1 main",
                detail: "不要从 develop 拉；线上问题优先止血。",
                color: LabUI.cyan
            ),
            GitStep(
                index: "02",
                title: "修复 + 复现测试",
                command: "git commit -m \"fix(order): guard stale state\"",
                detail: "必须补回归测试与线上复现证据。",
                color: LabUI.mint
            ),
            GitStep(
                index: "03",
                title: "合并 main + patch tag",
                command: "git switch main\ngit merge --no-ff hotfix/1.4.1\ngit tag -a v1.4.1 -m \"XClientLab 1.4.1\"\ngit push origin v1.4.1",
                detail: "patch tag 只打在 main；推送 tag 触发发布流程。",
                color: LabUI.amber
            ),
            GitStep(
                index: "04",
                title: "回合 develop",
                command: "git switch develop\ngit merge --no-ff main",
                detail: "漏掉这步，下次发布会把线上 bug 重新发出去。",
                color: LabUI.coral
            )
        ]
        for step in hotfixSteps {
            card.add(makeGitStepRow(step))
        }

        card.add(makeBanner(
            text: "发布完成检查：main 已打 tag、develop 已回合、发布分支已删除。三者缺一不可。",
            color: LabUI.mint,
            symbol: "checkmark.seal.fill"
        ))
        return card
    }

    func makeReleaseSubhead(title: String, detail: String, color: UIColor) -> UIView {
        let stack = labStack(spacing: 2)
        stack.addArrangedSubview(labLabel(title, size: 12, weight: .bold, color: color, mono: true, lines: 1))
        stack.addArrangedSubview(labLabel(detail, size: 9.5, color: LabUI.textTertiary, lines: 0))
        return stack
    }

    private func makeGitStepRow(_ step: GitStep) -> UIView {
        let row = labStack(spacing: 5)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        let badge = labLabel(step.index, size: 9, weight: .bold, color: step.color, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = step.color.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 7
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(26)
            make.height.equalTo(22)
        }
        head.addArrangedSubview(badge)
        head.addArrangedSubview(labLabel(step.title, size: 11.5, weight: .semibold, color: LabUI.textPrimary, lines: 1))
        row.addArrangedSubview(head)
        row.addArrangedSubview(makeCommandLine(step.command, accent: step.color))
        row.addArrangedSubview(labLabel(step.detail, size: 10, color: LabUI.textSecondary, lines: 0))
        row.accessibilityIdentifier = "gitflow.step.\(step.index).\(step.title)"
        return row
    }

    func makeCommandLine(_ command: String, accent: UIColor) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        box.layer.cornerRadius = 8
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = accent.withAlphaComponent(0.12).cgColor
        let prompt = command
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "$ \($0)" }
            .joined(separator: "\n")
        let label = labLabel(prompt, size: 9.5, color: LabUI.textSecondary, mono: true, lines: 0)
        box.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8))
        }
        return box
    }
}
