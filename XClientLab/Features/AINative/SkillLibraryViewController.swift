import Combine
import SnapKit
import UIKit

/// Scenario 4.1 — Xcode MCP 通道纪律 + 可复用 LLDB Skills。
///
/// 古法排查痛点：在异步崩溃现场直接 `bt all`，进程其实还在 running；再点
/// Continue 又把现场放跑。调试经验留在个人肌肉记忆里，换个人就要重学。
///
/// AI MCP 新实践切入点：把「status → interrupt → 轮询 stopped → 批量取证 →
/// 只 resume 一次」固化成状态机与 Skill 文档，让 Agent 按同一套纪律执行。
final class SkillLibraryViewController: LabBaseViewController {
    private let viewModel = MCPChannelViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let stateLabel = labLabel("IDLE", size: 12, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
    private let statusLabel = labLabel("尚未 attach。先执行 process status，再决定是否 interrupt。", size: 11.5, color: LabUI.textSecondary, lines: 0)
    private let executedLabel = labLabel("EXECUTED 0 / 5", size: 9, weight: .bold, color: LabUI.mint, mono: true, lines: 1)
    private let rejectedLabel = labLabel("REJECTED 0", size: 9, weight: .bold, color: LabUI.coral, mono: true, lines: 1)
    private var chips: [UILabel] = []
    private let runButton = LabButton(title: "RUN DISCIPLINED BATCH", style: .primary, accent: LabUI.violet)
    private let unsafeButton = LabButton(title: "BT ALL WHILE RUNNING", style: .destructive, accent: LabUI.coral)
    private let resetButton = LabButton(title: "RESET", style: .ghost)
    private let checklist = labStack(spacing: 6)
    private let skillsStack = labStack(spacing: 12)
    private let skillCountLabel = labLabel("07 / 07", size: 9, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
    private var filterButtons: [UIButton] = []
    private var activeFilter: SkillFilter = .all

    init() {
        super.init(accent: LabUI.violet)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "4.1 MCP + Skills"
        buildUI()
        bind()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 4.1  /  XCODE MCP",
            title: "五位一体架构与 Skills",
            subtitle: "规则定边界、技能给剧本、代理分角色、钩子卡门禁、MCP 接真实工具；7 个调试剧本按四类归档，随时复制进 Agent。",
            accent: LabUI.violet
        ))

        add(makeArchitectureCard())
        add(labMetricRow([
            LabMetricTileView(
                label: "PILLARS",
                value: "5",
                detail: "Rules / Skills / Agents / Hooks / MCP",
                color: LabUI.violet
            ),
            LabMetricTileView(
                label: "SKILLS",
                value: "\(DebugSkillLibrary.all.count)",
                detail: "四类可筛选剧本",
                color: LabUI.amber
            ),
            LabMetricTileView(
                label: "HUMAN GATE",
                value: "1",
                detail: "push 前必须人工确认",
                color: LabUI.mint
            )
        ]))

        let flowCard = LabCardView(accent: LabUI.violet)
        flowCard.add(labLabel("CHANNEL STATE", size: 9.5, weight: .bold, color: LabUI.violet, mono: true, lines: 1))
        flowCard.add(makeChipStrip())
        let stateRow = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        stateRow.addArrangedSubview(LabStatusDotView(color: LabUI.violet))
        stateRow.addArrangedSubview(labLabel("CURRENT", size: 9, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stateRow.addArrangedSubview(spacer)
        stateRow.addArrangedSubview(stateLabel)
        flowCard.add(stateRow)
        flowCard.add(statusLabel)
        flowCard.add(LabUIKit.actionRow([runButton, resetButton]))
        flowCard.add(unsafeButton)
        add(flowCard)

        let checklistCard = LabCardView(accent: LabUI.cyan)
        checklistCard.add(labLabel("BATCH COMMANDS", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        checklistCard.add(checklist)
        let counters = labStack(axis: .horizontal, spacing: 12, alignment: .center)
        counters.addArrangedSubview(executedLabel)
        counters.addArrangedSubview(rejectedLabel)
        let counterSpacer = UIView()
        counterSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        counters.addArrangedSubview(counterSpacer)
        checklistCard.add(counters)
        add(checklistCard)

        add(LabSectionHeaderView(
            kicker: "SKILL LIBRARY",
            title: "可复制进 MCP 的调试剧本",
            trailing: String(format: "%02d SKILLS", DebugSkillLibrary.all.count),
            accent: LabUI.violet
        ))
        add(makeFilterCard())
        add(skillsStack)
        renderSkills()

        add(LabCalloutView(
            kind: .insight,
            message: "7 个 Skill 覆盖异常崩溃、性能卡顿、并发与网络、工程质量四类；每个剧本都带「何时用 → 取证 → 治理 → 验收」的闭环。"
        ))
        add(LabCalloutView(
            kind: .problem,
            message: "「点 Pause 再 bt all」在异步崩溃里经常失效：进程可能还在 running，LLDB 报错或卡住；再点 Continue 又把现场放跑。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "把通道纪律做成状态机与 Skill：Agent 先 process status、必要时 interrupt 并轮询 stopped，再批量取证，最后只 resume 一次。"
        ))

        add(LabConsoleView(store: viewModel.console, title: "MCP LOG", height: 190, accent: LabUI.violet))
        runButton.accessibilityIdentifier = "mcp.channel.run"
        unsafeButton.accessibilityIdentifier = "mcp.channel.unsafe"
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        unsafeButton.addTarget(self, action: #selector(unsafeTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
    }

    private func makeChipStrip() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 4, alignment: .center)
        row.distribution = .fillEqually
        chips = MCPChannelViewModel.flow.map { state in
            let chip = labLabel(state.rawValue, size: 7.5, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
            chip.textAlignment = .center
            chip.backgroundColor = LabUI.surfaceRaised
            chip.layer.cornerRadius = 6
            chip.layer.masksToBounds = true
            chip.snp.makeConstraints { make in make.height.equalTo(24) }
            row.addArrangedSubview(chip)
            return chip
        }
        return row
    }

    private func makeSkillCard(_ skill: DebugSkill) -> UIView {
        let card = LabCardView(accent: skill.accent)
        card.add(labLabel(skill.category, size: 9, weight: .bold, color: skill.accent, mono: true, lines: 1))
        card.add(labLabel(skill.title, size: 16, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 0))
        card.add(labLabel(skill.subtitle, size: 11.5, color: LabUI.textSecondary, lines: 0))
        card.add(labTagRow(skill.tags, color: skill.accent))
        let open = LabButton(
            title: "OPEN SKILL",
            style: .secondary,
            accent: skill.accent,
            systemImage: "doc.text.magnifyingglass"
        )
        open.accessibilityIdentifier = "skill.\(skill.id)"
        open.addAction(UIAction { [weak self] _ in
            self?.push(SkillDetailViewController(skill: skill))
        }, for: .touchUpInside)
        card.add(open)
        return card
    }

    private func bind() {
        viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                stateLabel.text = state.rawValue
                stateLabel.textColor = state.color
                for (index, chip) in chips.enumerated() {
                    let flowState = MCPChannelViewModel.flow[index]
                    chip.textColor = flowState == state ? state.color : LabUI.textTertiary
                    chip.backgroundColor = flowState == state ? state.color.withAlphaComponent(0.15) : LabUI.surfaceRaised
                }
                runButton.isEnabled = !viewModel.isBusy
            }
            .store(in: &cancellables)

        viewModel.$statusNote
            .receive(on: RunLoop.main)
            .sink { [weak self] note in self?.statusLabel.text = note }
            .store(in: &cancellables)

        viewModel.$executedCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.executedLabel.text = "EXECUTED \(count) / \(MCPChannelViewModel.batchCommands.count)"
                self?.renderChecklist(executed: count)
            }
            .store(in: &cancellables)

        viewModel.$rejectedCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in self?.rejectedLabel.text = "REJECTED \(count)" }
            .store(in: &cancellables)
    }

    private func renderChecklist(executed: Int) {
        checklist.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, command) in MCPChannelViewModel.batchCommands.enumerated() {
            let done = index < executed
            let row = labStack(axis: .horizontal, spacing: 7, alignment: .center)
            row.addArrangedSubview(labLabel(done ? "✓" : "○", size: 12, weight: .bold, color: done ? LabUI.mint : LabUI.textTertiary, mono: true, lines: 1))
            row.addArrangedSubview(labLabel(command, size: 10.5, color: done ? LabUI.textPrimary : LabUI.textTertiary, mono: true, lines: 1))
            checklist.addArrangedSubview(row)
        }
    }

    @objc private func runTapped() {
        viewModel.runBatch()
    }

    @objc private func unsafeTapped() {
        viewModel.sendWhileRunning()
    }

    @objc private func resetTapped() {
        viewModel.reset()
    }
}

/// Skill 详情：直接复用 Markdown 预览，并提供一键复制。
final class SkillDetailViewController: LabBaseViewController {
    private let skill: DebugSkill

    init(skill: DebugSkill) {
        self.skill = skill
        super.init(accent: skill.accent)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = skill.title
        add(LabScreenTitleView(
            index: skill.category,
            title: skill.title,
            subtitle: skill.subtitle,
            accent: skill.accent
        ))
        add(labTagRow(skill.tags, color: skill.accent))
        let copy = LabButton(title: "COPY MARKDOWN", style: .secondary, accent: skill.accent, systemImage: "doc.on.doc")
        copy.accessibilityIdentifier = "skill.copy"
        copy.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UIPasteboard.general.string = skill.markdown
        }, for: .touchUpInside)
        add(copy)

        let card = LabCardView(accent: skill.accent, padding: 16)
        card.add(MarkdownPreviewView(markdown: skill.markdown, accent: skill.accent))
        add(card)
    }
}

// MARK: - 4.1 五位一体架构与分类筛选

private extension SkillLibraryViewController {
    func makeArchitectureCard() -> UIView {
        let card = LabCardView(accent: LabUI.violet)
        card.add(labLabel("AI-NATIVE 五位一体", size: 9.5, weight: .bold, color: LabUI.violet, mono: true, lines: 1))
        card.add(labLabel(
            "Rules 定边界，Skills 给剧本，Agents 分角色，Hooks 卡门禁，MCP 接真实工具。",
            size: 15.5,
            weight: .semibold,
            color: LabUI.textPrimary,
            rounded: true,
            lines: 0
        ))
        card.add(labLabel(
            "Workflows 把五者编排成一条可解释、可审计的交付流水线 —— 人来掌舵，AI 来执行。",
            size: 11.5,
            color: LabUI.textSecondary,
            lines: 0
        ))
        let pillars: [ArchitecturePillar] = [
            ArchitecturePillar(code: "RULES", detail: "CLAUDE.md：纪律与红线", accent: LabUI.coral),
            ArchitecturePillar(code: "SKILLS", detail: "可复用的调试剧本", accent: LabUI.amber),
            ArchitecturePillar(code: "AGENTS", detail: "只读预审 vs 执行代理", accent: LabUI.cyan),
            ArchitecturePillar(code: "HOOKS", detail: "提交前的自动门禁", accent: LabUI.violet),
            ArchitecturePillar(code: "MCP", detail: "LLDB / xcodebuild 真实通道", accent: LabUI.mint)
        ]
        for (index, pillar) in pillars.enumerated() {
            card.add(makePillarRow(
                symbol: "0\(index + 1)",
                code: pillar.code,
                detail: pillar.detail,
                accent: pillar.accent
            ))
        }
        card.add(makeWorkflowRow())
        return card
    }

    func makePillarRow(symbol: String, code: String, detail: String, accent: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 9, alignment: .center)
        let badge = labLabel(symbol, size: 9, weight: .bold, color: accent, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = accent.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 5
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(22)
            make.height.equalTo(20)
        }
        row.addArrangedSubview(badge)
        let codeLabel = labLabel(code, size: 9.5, weight: .bold, color: accent, mono: true, lines: 1)
        codeLabel.snp.makeConstraints { make in make.width.equalTo(66) }
        row.addArrangedSubview(codeLabel)
        row.addArrangedSubview(labLabel(detail, size: 11, color: LabUI.textSecondary, lines: 1))
        return row
    }

    func makeWorkflowRow() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 9, alignment: .center)
        let badge = labLabel("↳", size: 10, weight: .bold, color: LabUI.violet, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = LabUI.violet.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 5
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(22)
            make.height.equalTo(20)
        }
        row.addArrangedSubview(badge)
        let codeLabel = labLabel("WORKFLOWS", size: 9.5, weight: .bold, color: LabUI.violet, mono: true, lines: 1)
        codeLabel.snp.makeConstraints { make in make.width.equalTo(66) }
        row.addArrangedSubview(codeLabel)
        row.addArrangedSubview(labLabel("把五者串成交付流水线", size: 11, color: LabUI.textSecondary, lines: 1))
        return row
    }

    func makeFilterCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        head.addArrangedSubview(labLabel(
            "FILTER BY CATEGORY",
            size: 9.5,
            weight: .bold,
            color: LabUI.cyan,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        head.addArrangedSubview(skillCountLabel)
        card.add(head)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        let row = labStack(axis: .horizontal, spacing: 6, alignment: .center)
        filterButtons = SkillFilter.allCases.map { filter in
            let button = makeFilterButton(filter)
            row.addArrangedSubview(button)
            return button
        }
        scroll.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalTo(scroll.contentLayoutGuide)
            make.height.equalTo(scroll.frameLayoutGuide)
        }
        card.add(scroll)
        scroll.snp.makeConstraints { make in make.height.equalTo(34) }
        return card
    }

    func makeFilterButton(_ filter: SkillFilter) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "skill.filter.\(filter.rawValue)"
        button.addAction(UIAction { [weak self] _ in
            self?.selectFilter(filter)
        }, for: .touchUpInside)
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.background.cornerRadius = 7
        button.configuration = config
        applyFilterStyle(button, filter: filter, selected: filter == activeFilter)
        return button
    }

    func applyFilterStyle(_ button: UIButton, filter: SkillFilter, selected: Bool) {
        var config = button.configuration ?? .plain()
        var title = AttributeContainer()
        title.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        title.foregroundColor = selected ? filter.accent : LabUI.textTertiary
        config.attributedTitle = AttributedString(filter.title, attributes: title)
        config.background.backgroundColor = selected ? filter.accent.withAlphaComponent(0.16) : LabUI.surfaceRaised
        config.background.strokeColor = selected ? filter.accent.withAlphaComponent(0.55) : .clear
        config.background.strokeWidth = selected ? 1 : 0
        button.configuration = config
    }

    func selectFilter(_ filter: SkillFilter) {
        activeFilter = filter
        for (index, button) in filterButtons.enumerated() {
            guard let item = SkillFilter(rawValue: index) else { continue }
            applyFilterStyle(button, filter: item, selected: item == filter)
        }
        renderSkills()
    }

    func renderSkills() {
        skillsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let skills = DebugSkillLibrary.all.filter { skill in
            guard let group = activeFilter.group else { return true }
            return skill.group == group
        }
        for skill in skills {
            skillsStack.addArrangedSubview(makeSkillCard(skill))
        }
        skillCountLabel.text = String(format: "%02d / %02d", skills.count, DebugSkillLibrary.all.count)
    }
}

// MARK: - 分类筛选

private struct ArchitecturePillar {
    let code: String
    let detail: String
    let accent: UIColor
}

private enum SkillFilter: Int, CaseIterable {
    case all
    case crash
    case performance
    case concurrency
    case engineering

    var title: String {
        switch self {
        case .all: return "全部"
        case .crash: return "异常崩溃"
        case .performance: return "性能卡顿"
        case .concurrency: return "并发与网络"
        case .engineering: return "工程质量"
        }
    }

    var group: DebugSkillGroup? {
        switch self {
        case .all: return nil
        case .crash: return .crash
        case .performance: return .performance
        case .concurrency: return .concurrency
        case .engineering: return .engineering
        }
    }

    var accent: UIColor {
        group?.accent ?? LabUI.violet
    }
}
