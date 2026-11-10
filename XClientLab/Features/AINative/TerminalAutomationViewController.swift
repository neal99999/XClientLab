import Combine
import SnapKit
import UIKit

/// Scenario 4.2 — Terminal-first 自动化命令桩。
///
/// 古法排查痛点：手写 xcodebuild / simctl / LLDB 命令，路径靠复制粘贴；
/// 断点脚本散落在聊天记录里，换一台机器就失效。
///
/// AI MCP 新实践切入点：把「测试桩 / LLDB 断点 / MCP 指令」做成同源的
/// 可生成产物，写入 App Documents，再用一条 terminal 命令取回并执行。
/// 生成器是确定性的，Agent 可以校验产物而不是猜命令。
final class TerminalAutomationViewController: LabBaseViewController {
    private let viewModel = TerminalAutomationViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let kindControl = LabUIKit.segmented(
        items: AutomationArtifactKind.allCases.map(\.rawValue),
        accent: LabUI.violet
    )
    private let scenarioButton = LabButton(title: "1.1 主线程卡顿", style: .secondary, accent: LabUI.violet)
    private let generateButton = LabButton(title: "GENERATE ARTIFACT", style: .primary, accent: LabUI.violet, systemImage: "terminal")
    private let resetButton = LabButton(title: "CLEAR LIST", style: .ghost)
    private let previewCard = LabCardView(accent: LabUI.violet)
    private let commandCard = LabCardView(accent: LabUI.cyan)
    private let historyStack = labStack(spacing: 8)
    private let emptyLabel = labLabel("还没有产物。选择场景与类型，点击 GENERATE。", size: 11.5, color: LabUI.textTertiary, lines: 0)
    private let statusLabel = labLabel("READY · 产物写入 Documents/XClientLabAutomation", size: 10, color: LabUI.textSecondary, mono: true, lines: 1)

    init() {
        super.init(accent: LabUI.violet)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "4.2 Terminal-first"
        buildUI()
        bind()
        refreshScenarioButton()
        renderPreview()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 4.2  /  TERMINAL-FIRST",
            title: "自动化命令桩",
            subtitle: "同一个场景，一键产出 XCTest 桩、LLDB 断点脚本或 MCP JSON；写入 Documents，终端一条命令取回。",
            accent: LabUI.violet
        ))

        add(labMetricRow([
            LabMetricTileView(label: "Artifact kinds", value: "3", detail: "XCTest / LLDB / MCP", color: LabUI.cyan),
            LabMetricTileView(label: "Scenarios", value: "6", detail: "覆盖四个模块", color: LabUI.mint),
            LabMetricTileView(label: "History", value: "8", detail: "内存中最近 8 条", color: LabUI.amber),
        ]))

        let generator = LabCardView(accent: LabUI.violet)
        generator.add(labLabel("GENERATOR", size: 9.5, weight: .bold, color: LabUI.violet, mono: true, lines: 1))
        generator.add(kindControl)
        generator.add(scenarioButton)
        generator.add(LabUIKit.actionRow([generateButton, resetButton]))
        generator.add(statusLabel)
        add(generator)

        previewCard.add(labLabel("PREVIEW", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        add(previewCard)

        commandCard.add(labLabel("TERMINAL", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        add(commandCard)

        let historyCard = LabCardView(accent: LabUI.steel)
        historyCard.add(labLabel("GENERATED ARTIFACTS", size: 9.5, weight: .bold, color: LabUI.steel, mono: true, lines: 1))
        historyCard.add(emptyLabel)
        historyCard.add(historyStack)
        add(historyCard)

        add(LabCalloutView(
            kind: .problem,
            message: "命令与断点靠手抄：xcodebuild 参数、simctl 路径、LLDB 批处理每次重拼；换机器/换人就断档，CI 也无法复用。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "把命令桩当代码生成：场景 + 产物类型 → 确定性文件 → 终端取回执行。Agent 只校验产物和退出码，不靠记忆拼命令。"
        ))

        add(LabConsoleView(store: viewModel.console, title: "GENERATOR LOG", height: 160, accent: LabUI.violet))

        kindControl.addTarget(self, action: #selector(kindChanged), for: .valueChanged)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        kindControl.accessibilityIdentifier = "terminal.kind"
        scenarioButton.accessibilityIdentifier = "terminal.scenario"
        generateButton.accessibilityIdentifier = "terminal.generate"
    }

    private func bind() {
        viewModel.$artifacts
            .receive(on: RunLoop.main)
            .sink { [weak self] artifacts in self?.renderHistory(artifacts) }
            .store(in: &cancellables)

        viewModel.$kind
            .receive(on: RunLoop.main)
            .sink { [weak self] kind in
                guard let self, let index = AutomationArtifactKind.allCases.firstIndex(of: kind) else { return }
                kindControl.selectedSegmentIndex = index
                renderPreview()
            }
            .store(in: &cancellables)

        viewModel.$scenario
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshScenarioButton()
                self?.renderPreview()
            }
            .store(in: &cancellables)

        viewModel.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self else { return }
                statusLabel.text = error.map { "FAILED · \($0)" } ?? "READY · 产物写入 Documents/XClientLabAutomation"
                statusLabel.textColor = error == nil ? LabUI.textSecondary : LabUI.coral
            }
            .store(in: &cancellables)
    }

    private func refreshScenarioButton() {
        scenarioButton.setTitle("SCENARIO · \(viewModel.scenario.title)", for: .normal)
        scenarioButton.showsMenuAsPrimaryAction = true
        scenarioButton.menu = UIMenu(children: AutomationScenario.allCases.map { scenario in
            UIAction(
                title: scenario.title,
                subtitle: scenario.subtitle,
                state: scenario == viewModel.scenario ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.scenario = scenario
            }
        })
    }

    private func renderPreview() {
        previewCard.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        previewCard.add(labLabel("PREVIEW", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))

        let artifact = viewModel.artifacts.first(where: { $0.kind == viewModel.kind && $0.scenario == viewModel.scenario })
            ?? viewModel.artifacts.first
        guard let artifact else {
            previewCard.add(labLabel(
                "生成后会在这里显示文件内容；当前选择：\(viewModel.kind.rawValue) / \(viewModel.scenario.title)",
                size: 11,
                color: LabUI.textTertiary,
                lines: 0
            ))
            commandCard.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            commandCard.add(labLabel("TERMINAL", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
            commandCard.add(labLabel(
                "先点击 GENERATE ARTIFACT，终端命令会带上当前产物的真实文件名。",
                size: 10.5,
                color: LabUI.textTertiary,
                lines: 0
            ))
            return
        }

        previewCard.add(labLabel(artifact.fileName, size: 10, weight: .semibold, color: LabUI.violet, mono: true, lines: 1))
        let prefix = String(artifact.content.prefix(1600))
        previewCard.add(LabCodeBlockView(
            code: prefix + (artifact.content.count > 1600 ? "\n… (\(artifact.byteCount) bytes total)" : ""),
            accent: LabUI.violet
        ))
        let copy = LabButton(title: "COPY CONTENT", style: .secondary, accent: LabUI.violet, systemImage: "doc.on.doc")
        copy.accessibilityIdentifier = "terminal.copy"
        copy.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            viewModel.copyContent(of: artifact)
        }, for: .touchUpInside)
        previewCard.add(copy)

        commandCard.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commandCard.add(labLabel("TERMINAL", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        let command = AutomationStubFactory.shellCommand(for: artifact)
        commandCard.add(LabCodeBlockView(code: command, accent: LabUI.cyan))
        let copyCommand = LabButton(title: "COPY COMMAND", style: .secondary, accent: LabUI.cyan, systemImage: "terminal")
        copyCommand.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            viewModel.copyTerminal(for: artifact)
        }, for: .touchUpInside)
        commandCard.add(copyCommand)
    }

    private func renderHistory(_ artifacts: [GeneratedArtifact]) {
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !artifacts.isEmpty
        for artifact in artifacts {
            let row = LabCardView(accent: artifact.kind == .xctest ? LabUI.mint : (artifact.kind == .lldb ? LabUI.amber : LabUI.cyan), padding: 12)
            let header = labStack(axis: .horizontal, spacing: 8, alignment: .center)
            header.addArrangedSubview(labLabel(artifact.fileName, size: 10.5, weight: .semibold, color: LabUI.textPrimary, mono: true, lines: 1))
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            header.addArrangedSubview(spacer)
            header.addArrangedSubview(labLabel("\(artifact.byteCount) B", size: 9, color: LabUI.textTertiary, mono: true, lines: 1))
            row.add(header)
            row.add(labLabel(
                "\(artifact.scenario.title) · \(artifact.formattedTime) · \(artifact.savedURL == nil ? "内存" : "Documents")",
                size: 9.5,
                color: LabUI.textTertiary,
                mono: true,
                lines: 1
            ))
            let copy = LabButton(title: "COPY", style: .ghost, accent: LabUI.violet)
            copy.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                viewModel.copyContent(of: artifact)
            }, for: .touchUpInside)
            row.add(copy)
            historyStack.addArrangedSubview(row)
        }
    }

    @objc private func kindChanged() {
        let all = AutomationArtifactKind.allCases
        guard all.indices.contains(kindControl.selectedSegmentIndex) else { return }
        viewModel.kind = all[kindControl.selectedSegmentIndex]
    }

    @objc private func generateTapped() {
        viewModel.generate()
    }

    @objc private func resetTapped() {
        viewModel.reset()
    }
}
