import Combine
import SnapKit
import UIKit

/// Scenario 4.1 — AI-Native 五位一体架构。
///
/// 这一页不再从「MCP 通道」讲起，而是先给出整套工程操作系统：
/// Rules 定边界、Skills 给剧本、Agents 分角色、Hooks 卡门禁、MCP 接真实
/// 工具；Workflows 把五者串成一条可解释、可审计的交付流水线。
///
/// 页面下半部分保留可交互的 MCP 通道状态机与 7 个调试剧本：架构不是海报，
/// 每一步都能在运行时被看到、被复制、被验证。
final class SkillLibraryViewController: LabBaseViewController {
    private let viewModel = MCPChannelViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let stateLabel = labLabel("IDLE", size: 12, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
    private let statusLabel = labLabel(
        "尚未 attach。先执行 process status，再决定是否 interrupt。",
        size: 11.5,
        color: LabUI.textSecondary,
        lines: 0
    )
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
        title = "AI 工坊"
        buildUI()
        bind()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "AI-NATIVE  /  ENGINEERING SYSTEM",
            title: "五位一体架构",
            subtitle: "把散落在个人经验里的调试纪律，沉淀成规则、技能、角色、门禁与工具通道。",
            accent: LabUI.violet
        ))

        add(makeHeroCard())
        add(labMetricRow([
            LabMetricTileView(label: "PILLARS", value: "5", detail: "五条支柱", color: LabUI.violet),
            LabMetricTileView(
                label: "SKILLS",
                value: String(format: "%02d", DebugSkillLibrary.all.count),
                detail: "四类归档",
                color: LabUI.amber
            ),
            LabMetricTileView(label: "HUMAN GATE", value: "1", detail: "push 前确认", color: LabUI.mint)
        ]))

        add(LabSectionHeaderView(
            kicker: "ARCHITECTURE",
            title: "五个支柱，一条流水线",
            trailing: "RULES → MCP",
            accent: LabUI.violet
        ))
        add(makePillarsCard())

        add(LabSectionHeaderView(
            kicker: "SKILL LIBRARY",
            title: "可复用调试剧本",
            trailing: String(format: "%02d SKILLS", DebugSkillLibrary.all.count),
            accent: LabUI.amber
        ))
        add(makeFilterCard())
        add(skillsStack)
        renderSkills()

        add(LabSectionHeaderView(
            kicker: "LIVE DEMO",
            title: "MCP 通道纪律",
            trailing: "STATE MACHINE",
            accent: LabUI.cyan
        ))
        add(makeChannelCard())
        add(makeChecklistCard())

        add(LabCalloutView(
            kind: .insight,
            message: "四类归档：异常崩溃 / 性能卡顿 / 并发与网络 / 工程质量；点 OPEN SKILL 查看完整 Markdown 剧本并一键复制进 Agent。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "人只做两件事：给边界、做确认。其余交给 Skills 与 MCP 按同一套纪律执行，过程可回放、可审计。"
        ))
        add(LabConsoleView(store: viewModel.console, title: "MCP LOG", height: 190, accent: LabUI.violet))

        runButton.accessibilityIdentifier = "mcp.channel.run"
        unsafeButton.accessibilityIdentifier = "mcp.channel.unsafe"
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        unsafeButton.addTarget(self, action: #selector(unsafeTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
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
            row.addArrangedSubview(labLabel(
                done ? "✓" : "○",
                size: 12,
                weight: .bold,
                color: done ? LabUI.mint : LabUI.textTertiary,
                mono: true,
                lines: 1
            ))
            row.addArrangedSubview(labLabel(
                command,
                size: 10.5,
                color: done ? LabUI.textPrimary : LabUI.textTertiary,
                mono: true,
                lines: 1
            ))
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
        add(makeTagFlowView(
            skill.tags,
            color: skill.accent,
            availableWidth: UIScreen.main.bounds.width - LabUI.pageInset * 2
        ))
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

// MARK: - 架构 / Skills / 通道卡片

private extension SkillLibraryViewController {
    func makeHeroCard() -> UIView {
        let card = LabCardView(accent: LabUI.violet, padding: 18)
        let meta = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        meta.addArrangedSubview(labLabel(
            "AI-NATIVE OPERATING MODEL",
            size: 9,
            weight: .bold,
            color: LabUI.violet,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        meta.addArrangedSubview(spacer)
        meta.addArrangedSubview(LabTagView(text: "HUMAN IN THE LOOP", color: LabUI.mint))
        card.add(meta)

        card.add(labLabel(
            "人来掌舵，AI 来执行。",
            size: 24,
            weight: .bold,
            color: LabUI.textPrimary,
            rounded: true,
            lines: 0
        ))
        card.add(labLabel(
            "约束先于生成，证据先于结论；五个支柱不是清单，而是一套能跑起来的工程操作系统。",
            size: 12.5,
            color: LabUI.textSecondary,
            lines: 0
        ))
        card.add(makePipelineStrip())
        card.add(makeWorkflowStrip())
        return card
    }

    func makePipelineStrip() -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.surfaceRaised.withAlphaComponent(0.65)
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.hairline.cgColor

        let steps: [(String, UIColor)] = [
            ("RULES", LabUI.coral),
            ("SKILLS", LabUI.amber),
            ("AGENTS", LabUI.cyan),
            ("HOOKS", LabUI.violet),
            ("MCP", LabUI.mint)
        ]
        let text = NSMutableAttributedString()
        for (index, step) in steps.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(
                    string: "  →  ",
                    attributes: [
                        .font: LabUI.font(10, weight: .semibold, mono: true),
                        .foregroundColor: LabUI.steel
                    ]
                ))
            }
            text.append(NSAttributedString(
                string: step.0,
                attributes: [
                    .font: LabUI.font(10, weight: .bold, mono: true),
                    .foregroundColor: step.1
                ]
            ))
        }
        let label = labLabel("", size: 10, weight: .bold, mono: true, lines: 1)
        label.attributedText = text
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        box.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 9, left: 10, bottom: 9, right: 10))
        }
        return box
    }

    func makeWorkflowStrip() -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.violet.withAlphaComponent(0.10)
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.violet.withAlphaComponent(0.22).cgColor

        let stack = labStack(spacing: 3)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        head.addArrangedSubview(labLabel("WORKFLOWS", size: 9, weight: .bold, color: LabUI.violet, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        head.addArrangedSubview(labLabel("ORCHESTRATION", size: 8.5, weight: .semibold, color: LabUI.steel, mono: true, lines: 1))
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(labLabel(
            "基线 → 自测门禁 → 独立预审 → 人类确认 → 推送 PR",
            size: 10.5,
            color: LabUI.textSecondary,
            mono: true,
            lines: 0
        ))
        box.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
        return box
    }

    func makePillarsCard() -> UIView {
        let card = LabCardView(accent: LabUI.violet, padding: 14)
        for (index, pillar) in ArchitecturePillar.defaults.enumerated() {
            if index > 0 {
                let line = UIView()
                line.backgroundColor = LabUI.hairline
                line.snp.makeConstraints { make in make.height.equalTo(0.8) }
                card.add(line)
            }
            card.add(makePillarRow(index: index + 1, pillar: pillar))
        }
        card.add(makePipelineFootnote())
        return card
    }

    func makePillarRow(index: Int, pillar: ArchitecturePillar) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        let badge = labLabel(String(format: "%02d", index), size: 9, weight: .bold, color: pillar.accent, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = pillar.accent.withAlphaComponent(0.14)
        badge.layer.cornerRadius = 7
        badge.layer.cornerCurve = .continuous
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(26)
            make.height.equalTo(24)
        }
        row.addArrangedSubview(badge)

        let text = labStack(spacing: 2)
        text.addArrangedSubview(labLabel(pillar.code, size: 10.5, weight: .bold, color: pillar.accent, mono: true, lines: 1))
        text.addArrangedSubview(labLabel(pillar.detail, size: 11, color: LabUI.textSecondary, lines: 1))
        row.addArrangedSubview(text)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(labLabel(pillar.role, size: 9, weight: .semibold, color: LabUI.textTertiary, mono: true, lines: 1))
        return row
    }

    func makePipelineFootnote() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.addArrangedSubview(labLabel("↳", size: 10, weight: .bold, color: LabUI.violet, mono: true, lines: 1))
        row.addArrangedSubview(labLabel(
            "五个支柱互相约束：没有 Hooks，Rules 只是文档；没有 MCP，Skills 只是散文。",
            size: 10.5,
            color: LabUI.textTertiary,
            lines: 0
        ))
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
        let all = DebugSkillLibrary.all
        let visible = all.filter { skill in
            guard let group = activeFilter.group else { return true }
            return skill.group == group
        }
        for skill in visible {
            let index = (all.firstIndex { $0.id == skill.id } ?? 0) + 1
            skillsStack.addArrangedSubview(makeSkillCard(skill, index: index))
        }
        skillCountLabel.text = String(format: "%02d / %02d", visible.count, all.count)
    }

    func makeSkillCard(_ skill: DebugSkill, index: Int) -> UIView {
        let card = LabCardView(accent: skill.accent, padding: 14)

        let meta = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        meta.addArrangedSubview(labLabel(String(format: "%02d", index), size: 9.5, weight: .bold, color: skill.accent, mono: true, lines: 1))
        let divider = UIView()
        divider.backgroundColor = skill.accent.withAlphaComponent(0.35)
        divider.snp.makeConstraints { make in
            make.width.equalTo(1)
            make.height.equalTo(9)
        }
        meta.addArrangedSubview(divider)
        meta.addArrangedSubview(labLabel(skill.category, size: 9, weight: .bold, color: skill.accent, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        meta.addArrangedSubview(spacer)
        meta.addArrangedSubview(LabTagView(text: skill.group.rawValue, color: skill.group.accent))
        card.add(meta)

        card.add(labLabel(skill.title, size: 16, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 0))
        card.add(labLabel(skill.subtitle, size: 11.5, color: LabUI.textSecondary, lines: 0))
        card.add(makeTagFlowView(
            skill.tags,
            color: skill.accent,
            availableWidth: UIScreen.main.bounds.width - LabUI.pageInset * 2 - 28
        ))
        card.add(makeOpenButton(skill))
        return card
    }

    func makeOpenButton(_ skill: DebugSkill) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "skill.\(skill.id)"
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
        var title = AttributeContainer()
        title.font = LabUI.font(10, weight: .bold, mono: true)
        title.foregroundColor = skill.accent
        config.attributedTitle = AttributedString("OPEN SKILL  →", attributes: title)
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { [weak self] _ in
            self?.push(SkillDetailViewController(skill: skill))
        }, for: .touchUpInside)
        return button
    }

    func makeChannelCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        head.addArrangedSubview(labLabel("MCP CHANNEL", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        head.addArrangedSubview(LabStatusDotView(color: LabUI.cyan))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        head.addArrangedSubview(stateLabel)
        card.add(head)
        card.add(makeChipStrip())
        card.add(statusLabel)
        card.add(LabUIKit.actionRow([runButton, resetButton]))
        card.add(unsafeButton)
        return card
    }

    func makeChecklistCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint)
        card.add(labLabel("BATCH COMMANDS · STOPPED ONLY", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        card.add(checklist)
        let counters = labStack(axis: .horizontal, spacing: 12, alignment: .center)
        counters.addArrangedSubview(executedLabel)
        counters.addArrangedSubview(rejectedLabel)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        counters.addArrangedSubview(spacer)
        card.add(counters)
        return card
    }

    func makeChipStrip() -> UIView {
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
}

// MARK: - 分类筛选

private struct ArchitecturePillar {
    let code: String
    let detail: String
    let role: String
    let accent: UIColor

    static let defaults: [ArchitecturePillar] = [
        ArchitecturePillar(code: "RULES", detail: "CLAUDE.md 写清纪律与红线", role: "边界", accent: LabUI.coral),
        ArchitecturePillar(code: "SKILLS", detail: "把排查步骤沉淀成剧本", role: "剧本", accent: LabUI.amber),
        ArchitecturePillar(code: "AGENTS", detail: "只读预审与执行代理分工", role: "分工", accent: LabUI.cyan),
        ArchitecturePillar(code: "HOOKS", detail: "提交前自动跑门禁", role: "门禁", accent: LabUI.violet),
        ArchitecturePillar(code: "MCP", detail: "LLDB / xcodebuild 真实通道", role: "通道", accent: LabUI.mint)
    ]
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

/// 标签超过一行时按可用宽度自动折行，避免 4 个标签把最后一个裁成 "CHUNI"。
private func makeTagFlowView(_ tags: [String], color: UIColor, availableWidth: CGFloat) -> UIView {
    let font = LabUI.font(9.5, weight: .bold, mono: true)
    var rows: [[String]] = []
    var current: [String] = []
    var currentWidth: CGFloat = 0

    for tag in tags {
        let tagWidth = (tag.uppercased() as NSString).size(withAttributes: [.font: font]).width + 16
        if !current.isEmpty, currentWidth + 6 + tagWidth > availableWidth {
            rows.append(current)
            current = []
            currentWidth = 0
        }
        currentWidth = current.isEmpty ? tagWidth : currentWidth + 6 + tagWidth
        current.append(tag)
    }
    if !current.isEmpty { rows.append(current) }

    let column = labStack(spacing: 6)
    for row in rows { column.addArrangedSubview(labTagRow(row, color: color)) }
    return column
}
