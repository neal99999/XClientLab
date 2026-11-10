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

    init() { super.init(accent: LabUI.violet) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "4.1 MCP + Skills"
        buildUI()
        bind()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 4.1  /  XCODE MCP",
            title: "通道纪律与 Skills",
            subtitle: "把 LLDB 的异步状态固化成状态机：running 时只允许 interrupt，stopped 后才批量取证，resume 只发生一次。",
            accent: LabUI.violet
        ))

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
            trailing: "03 SKILLS",
            accent: LabUI.violet
        ))
        for skill in DebugSkillLibrary.all {
            add(makeSkillCard(skill))
        }

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

    @objc private func runTapped() { viewModel.runBatch() }
    @objc private func unsafeTapped() { viewModel.sendWhileRunning() }
    @objc private func resetTapped() { viewModel.reset() }
}

/// Skill 详情：直接复用 Markdown 预览，并提供一键复制。
final class SkillDetailViewController: LabBaseViewController {
    private let skill: DebugSkill

    init(skill: DebugSkill) {
        self.skill = skill
        super.init(accent: skill.accent)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
