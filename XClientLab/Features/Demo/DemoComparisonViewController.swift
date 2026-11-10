import Combine
import SnapKit
import UIKit

/// 演示第一屏：先讲“同一件事，古法和 AI 的差距”，再一键进入真实实验。
/// 这样面试官先看到价值，再看到实现细节，而不是一上来就面对 5 个模块。
final class DemoComparisonViewController: LabBaseViewController {
    private let viewModel = DemoComparisonViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let scenarioPicker = LabUIKit.segmented(
        items: DemoLibrary.all.map { $0.shortTitle },
        accent: LabUI.violet
    )
    private let summaryCard = LabCardView(accent: LabUI.violet, padding: 16)
    private let summaryTitle = labLabel(size: 18, weight: .semibold, color: LabUI.textPrimary, rounded: true)
    private let summarySubtitle = labLabel(size: 12, color: LabUI.textSecondary, lines: 0)
    private let summaryTags = labStack(axis: .horizontal, spacing: 6, alignment: .center)
    private let columns = labStack(axis: .horizontal, spacing: 10, alignment: .top, distribution: .fillEqually)

    private let traditionalTile = LabMetricTileView(
        label: "TRADITIONAL",
        value: "35",
        unit: "min",
        detail: "手工排查",
        color: LabUI.coral
    )
    private let aiTile = LabMetricTileView(
        label: "AI + MCP",
        value: "6",
        unit: "min",
        detail: "固定证据链",
        color: LabUI.mint
    )
    private let savedTile = LabMetricTileView(
        label: "SAVED",
        value: "83",
        unit: "%",
        detail: "演示估算",
        color: LabUI.amber
    )

    private let savingsBar = LabMiniBarView(color: LabUI.mint)
    private let savingsPercent = labLabel("0%", size: 30, weight: .semibold, color: LabUI.mint, rounded: true)
    private let savingsCaption = labLabel("播放对比，看看时间花在哪一步。", size: 11, color: LabUI.textTertiary)
    private let playButton = LabButton(title: "PLAY COMPARISON", style: .secondary, accent: LabUI.violet)
    private let openButton = LabButton(title: "进入真实场景", style: .primary, accent: LabUI.cyan)
    private let aiButton = LabButton(title: "打开 AI 工坊", style: .secondary, accent: LabUI.violet)

    init() {
        super.init(accent: LabUI.violet)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AI 对照"
        buildUI()
        bind()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.reset()
    }

    // MARK: - UI

    private func buildUI() {
        add(LabScreenTitleView(
            index: "DEMO 00 / AI EFFICIENCY",
            title: "同一个问题，两种排查",
            subtitle: "先用 30 秒讲清楚「古法 vs AI + MCP」的差距，再进入真实场景验证。所有数字都是本 Demo 的演示估算。",
            accent: LabUI.violet
        ))

        let pickerHeader = LabSectionHeaderView(
            kicker: "SCENARIO",
            title: "选择对照场景",
            trailing: "04 TRACKS",
            accent: LabUI.violet
        )
        add(pickerHeader)
        scenarioPicker.accessibilityIdentifier = "demo.scenario"
        scenarioPicker.selectedSegmentIndex = 0
        scenarioPicker.addTarget(self, action: #selector(scenarioChanged), for: .valueChanged)
        add(scenarioPicker)

        summaryCard.add(summaryTitle)
        summaryCard.add(summarySubtitle)
        summaryCard.add(summaryTags)
        add(summaryCard)

        add(columns)

        let metricsRow = labMetricRow([traditionalTile, aiTile, savedTile])
        add(metricsRow)

        add(makePlayCard())

        openButton.accessibilityIdentifier = "demo.open"
        aiButton.accessibilityIdentifier = "demo.ai"
        openButton.addTarget(self, action: #selector(openScenario), for: .touchUpInside)
        aiButton.addTarget(self, action: #selector(openAIWorkshop), for: .touchUpInside)
        add(LabUIKit.actionRow([openButton, aiButton]))

        add(LabCalloutView(
            kind: .insight,
            message: "演示口径：传统耗时按手工操作路径估算；AI 耗时按 Skill + MCP + 命令桩的理想路径估算。真实项目仍以 trace 和线上指标为准。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "AI 提效的关键不是「让模型猜原因」，而是把复现、取证、回归固化成可重复的 Skill / MCP 状态机 / 命令桩——人只做判断。"
        ))

        render()
    }

    private func makePlayCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 15)
        card.add(LabSectionHeaderView(
            kicker: "COMPARE",
            title: "时间差",
            trailing: "DEMO ESTIMATE",
            accent: LabUI.mint
        ))

        let percentRow = labStack(axis: .horizontal, spacing: 8, alignment: .firstBaseline)
        percentRow.addArrangedSubview(savingsPercent)
        percentRow.addArrangedSubview(labLabel("TIME SAVED", size: 9, weight: .bold, color: LabUI.textTertiary, mono: true))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        percentRow.addArrangedSubview(spacer)
        card.add(percentRow)
        card.add(savingsBar)
        card.add(savingsCaption)

        playButton.accessibilityIdentifier = "demo.play"
        playButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        card.add(playButton)
        return card
    }

    // MARK: - Binding

    private func bind() {
        viewModel.$selectedIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.render() }
            .store(in: &cancellables)

        viewModel.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                self?.playButton.setTitle(isPlaying ? "PLAYING..." : "PLAY COMPARISON", for: .normal)
                self?.playButton.isEnabled = !isPlaying
            }
            .store(in: &cancellables)

        viewModel.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                guard let self else { return }
                let saved = self.viewModel.selected.savedPercent
                let value = progress * Double(saved) / 100.0
                self.savingsBar.setProgress(value)
                self.savingsPercent.text = "\(Int((value * 100).rounded()))%"
                if progress >= 1 {
                    self.savingsCaption.text = "\(self.viewModel.selected.traditionalMinutes) min → \(self.viewModel.selected.aiMinutes) min，节省 \(saved)%"
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Rendering

    private func render() {
        let scenario = viewModel.selected
        let accent = scenario.module.accent

        scenarioPicker.selectedSegmentIndex = viewModel.selectedIndex
        summaryTitle.text = "\(scenario.index)  \(scenario.title)"
        summaryTitle.textColor = LabUI.textPrimary
        summarySubtitle.text = scenario.subtitle

        summaryTags.arrangedSubviews.forEach { $0.removeFromSuperview() }
        scenario.module.tags.prefix(4).forEach { tag in
            summaryTags.addArrangedSubview(LabTagView(text: tag, color: accent))
        }
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        summaryTags.addArrangedSubview(spacer)

        columns.arrangedSubviews.forEach { $0.removeFromSuperview() }
        columns.addArrangedSubview(makeColumn(
            title: "古法排查",
            badge: "MANUAL",
            steps: scenario.traditional,
            minutes: scenario.traditionalMinutes,
            accent: LabUI.coral
        ))
        columns.addArrangedSubview(makeColumn(
            title: "AI + MCP",
            badge: "ASSISTED",
            steps: scenario.ai,
            minutes: scenario.aiMinutes,
            accent: LabUI.mint
        ))

        traditionalTile.update(
            value: "\(scenario.traditionalMinutes)",
            detail: "\(scenario.traditional.count) 个手工步骤",
            color: LabUI.coral
        )
        aiTile.update(
            value: "\(scenario.aiMinutes)",
            detail: "\(scenario.ai.count) 个固定步骤",
            color: LabUI.mint
        )
        savedTile.update(
            value: "\(scenario.savedPercent)",
            detail: "\(scenario.traditionalMinutes) → \(scenario.aiMinutes) min",
            color: LabUI.amber
        )

        openButton.setTitle("进入 \(scenario.index) 真实场景", for: .normal)
        savingsBar.setProgress(0)
        savingsPercent.text = "0%"
        savingsCaption.text = "播放对比，看看时间花在哪一步。"
    }

    // MARK: - Actions

    @objc private func scenarioChanged() {
        viewModel.select(scenarioPicker.selectedSegmentIndex)
    }

    @objc private func togglePlayback() {
        viewModel.reset()
        viewModel.play()
    }

    @objc private func openScenario() {
        push(viewModel.selected.destination())
    }

    @objc private func openAIWorkshop() {
        tabBarController?.selectedIndex = 2
    }

    /// 左右两栏的步骤卡。刻意只保留步骤名与耗时，让对比在 3 秒内可读。
    /// LabCardView 是 final 组件（Lab 全家桶都是组合式 API），所以用工厂方法
    /// 拼装而不是子类化，和上面的 makePlayCard() 同一套路。
    private func makeColumn(title: String, badge: String, steps: [DemoStep], minutes: Int, accent: UIColor) -> LabCardView {
        let card = LabCardView(accent: accent, padding: 12)

        let header = labStack(axis: .horizontal, spacing: 6, alignment: .center)
        header.addArrangedSubview(LabStatusDotView(color: accent, size: 5))
        header.addArrangedSubview(labLabel(title, size: 11.5, weight: .bold, color: accent, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(LabTagView(text: badge, color: accent))
        card.add(header)

        let totalRow = labStack(axis: .horizontal, spacing: 3, alignment: .firstBaseline)
        totalRow.addArrangedSubview(labLabel("\(minutes)", size: 25, weight: .semibold, color: accent, rounded: true))
        totalRow.addArrangedSubview(labLabel("min", size: 9, weight: .medium, color: LabUI.textTertiary, mono: true))
        let totalSpacer = UIView()
        totalSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        totalRow.addArrangedSubview(totalSpacer)
        totalRow.addArrangedSubview(labLabel("\(steps.count) STEPS", size: 8.5, weight: .semibold, color: LabUI.textTertiary, mono: true))
        card.add(totalRow)

        let divider = UIView()
        divider.backgroundColor = LabUI.hairline
        divider.snp.makeConstraints { make in make.height.equalTo(1) }
        card.add(divider)

        for (index, step) in steps.enumerated() {
            let row = labStack(axis: .horizontal, spacing: 6, alignment: .top)
            let number = labLabel(String(format: "%02d", index + 1), size: 8.5, weight: .bold, color: accent, mono: true, lines: 1)
            number.snp.makeConstraints { make in make.width.equalTo(16) }
            row.addArrangedSubview(number)
            let stepTitle = labLabel(step.title, size: 9.5, color: LabUI.textSecondary, lines: 2)
            stepTitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(stepTitle)
            let mins = labLabel("\(step.minutes)m", size: 8.5, weight: .medium, color: LabUI.textTertiary, mono: true, lines: 1)
            mins.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(mins)
            card.add(row)
        }
        return card
    }
}
