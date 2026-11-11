import Combine
import SnapKit
import UIKit

/// 交付与防线：把 Figma 像素还原、AI 代码审查与 Git Flow 做成可交互的证据链。
///
/// 页面遵循单向数据流：`DeliveryGuardViewModel.ViewState` 是唯一状态源，
/// 交互只调用 ViewModel 的 intent，界面统一由 `render(_:)` 推导。
final class DeliveryGuardViewController: LabBaseViewController {
    let viewModel = DeliveryGuardViewModel()
    var cancellables = Set<AnyCancellable>()

    // MARK: - Review demo views

    let reviewStateLabel = labLabel(
        "RAW · 10 COMMENTS",
        size: 11.5,
        weight: .bold,
        color: LabUI.coral,
        mono: true,
        lines: 1
    )
    let reviewSummaryLabel = labLabel("", size: 11.5, color: LabUI.textSecondary, lines: 0)
    let reviewFootnoteLabel = labLabel("", size: 9.5, color: LabUI.textTertiary, mono: true, lines: 0)
    let reviewSignalLabel = labLabel("SIGNAL 20%", size: 9, weight: .bold, color: LabUI.coral, mono: true, lines: 1)
    let reviewSignalBar = LabMiniBarView(color: LabUI.cyan)
    let reviewListStack = labStack(spacing: 8)
    let reviewStepButton = LabButton(title: "STEP", style: .primary, accent: LabUI.cyan)
    var reviewModeButtons: [DeliveryGuardViewModel.ReviewMode: LabButton] = [:]

    // MARK: - Asset demo views

    let assetStateLabel = labLabel("LOADED", size: 9, weight: .bold, color: LabUI.mint, mono: true, lines: 1)
    lazy var assetStateBadge = makeBadge(label: assetStateLabel)
    let assetIconView = UIImageView(image: UIImage(systemName: "wallet.pass.fill"))
    let assetBodyStack = labStack(spacing: 10)
    let snapshotBadgeLabel = labLabel("DIFF: 0.00% PASS", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1)
    lazy var snapshotBadge = makeBadge(label: snapshotBadgeLabel)
    let snapshotPercentLabel = labLabel("0.00%", size: 9.5, weight: .semibold, color: LabUI.mint, mono: true, lines: 1)
    let snapshotBar = LabMiniBarView(color: LabUI.mint)
    let debounceAcceptedLabel = labLabel("0", size: 22, weight: .semibold, color: LabUI.mint, mono: true, lines: 1)
    let debounceShieldedLabel = labLabel("0", size: 22, weight: .semibold, color: LabUI.coral, mono: true, lines: 1)
    let refreshButton = LabButton(title: "REFRESH", style: .primary, accent: LabUI.mint, systemImage: "arrow.clockwise")
    var assetStateButtons: [DeliveryGuardViewModel.AssetState: UIButton] = [:]
    var skeletonViews: [UIView] = []

    var lastReviewMode: DeliveryGuardViewModel.ReviewMode?
    var lastConvergenceStage: DeliveryGuardViewModel.ConvergenceStage?
    var lastAssetState: DeliveryGuardViewModel.AssetState?

    init() {
        super.init(accent: LabUI.cyan)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "交付与防线"
        view.accessibilityIdentifier = "screen.delivery"
        buildUI()
        bind()
        render(viewModel.state)
    }

    // MARK: - Composition

    func buildUI() {
        debounceAcceptedLabel.accessibilityIdentifier = "asset.debounce.accepted"
        debounceShieldedLabel.accessibilityIdentifier = "asset.debounce.shielded"
        add(LabScreenTitleView(
            index: "AI-NATIVE / DELIVERY & QUALITY ASSURANCE",
            title: "全流程交付与防线",
            subtitle: "从代码审查信噪比治理，到 Figma 像素级快照比对闭环。",
            accent: LabUI.cyan
        ))
        add(makeMetricRow())

        add(LabSectionHeaderView(
            kicker: "FIGMA-TO-UIKIT",
            title: "像素级还原与快照闭环",
            trailing: "SIX-STATE MATRIX",
            accent: LabUI.mint
        ))
        add(makeFigmaCard())
        add(makeAssetDemoCard())

        add(LabSectionHeaderView(
            kicker: "AI CODE REVIEW PIPELINE",
            title: "全生命周期审查防线",
            trailing: "4 STAGES",
            accent: LabUI.cyan
        ))
        add(makePipelineCard())
        add(makeReviewDemoCard())

        add(LabSectionHeaderView(
            kicker: "HUMAN STEERING",
            title: "人类工程师的掌舵清单",
            trailing: "FINAL GATE",
            accent: LabUI.amber
        ))
        add(makeChecklistCard())

        add(LabCalloutView(
            kind: .problem,
            message: "人肉评审看不完、看不出重点；AI 评审的噪音淹没 BLOCKER；UI 还原靠目测，异常态总在线上才暴露。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "确定性工具先行：Lint / SAST、Merge Queue、Snapshot Diff、APM 回滚；AI 只处理语义与意图，人只做风险决策。"
        ))

        add(LabSectionHeaderView(
            kicker: "GIT FLOW / RELEASE DISCIPLINE",
            title: "分支、提交与发布纪律",
            trailing: "5 BRANCHES",
            accent: LabUI.violet
        ))
        add(makeGitFlowLeadCallout())
        add(makeGitFlowBranchCard())
        add(makeGitFlowWorkflowCard())
        add(makeGitFlowReleaseCard())

        add(LabSectionHeaderView(
            kicker: "CONVENTIONAL COMMITS",
            title: "让提交信息机器可解析",
            trailing: "14 TYPES",
            accent: LabUI.cyan
        ))
        add(makeCommitCoreCard())
        add(makeCommitOpsCard())
    }

    // MARK: - Binding

    func bind() {
        viewModel.$state
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    func render(_ state: DeliveryGuardViewModel.ViewState) {
        reviewStateLabel.text = state.reviewStatusText
        reviewStateLabel.textColor = state.reviewStatusColor
        reviewSummaryLabel.text = state.reviewSummary
        reviewFootnoteLabel.text = state.reviewFootnote
        reviewSignalLabel.text = String(format: "SIGNAL %.0f%%", state.signalRatio * 100)
        reviewSignalLabel.textColor = state.reviewStatusColor
        reviewSignalBar.setProgress(state.signalRatio)
        updateReviewModeButtons(selected: state.reviewMode)

        reviewStepButton.isHidden = state.reviewMode != .converged
        reviewStepButton.setTitle(state.convergenceActionTitle, for: .normal)
        reviewStepButton.accessibilityLabel = state.convergenceActionTitle
        reviewStepButton.backgroundColor = state.convergenceStage.accent

        if state.reviewMode != lastReviewMode || state.convergenceStage != lastConvergenceStage {
            lastReviewMode = state.reviewMode
            lastConvergenceStage = state.convergenceStage
            rebuildReviewList(for: state)
        }

        if state.assetState != lastAssetState {
            lastAssetState = state.assetState
            rebuildAssetBody(for: state.assetState)
        }
        updateAssetChrome(for: state.assetState)
        updateDebounceLabels(state)
        updateSnapshot(state)
    }

    func updateReviewModeButtons(selected mode: DeliveryGuardViewModel.ReviewMode) {
        for (item, button) in reviewModeButtons {
            let isSelected = item == mode
            button.backgroundColor = isSelected ? item.accent.withAlphaComponent(0.16) : LabUI.surfaceRaised.withAlphaComponent(0.55)
            button.setTitleColor(isSelected ? item.accent : LabUI.textSecondary, for: .normal)
            button.layer.borderWidth = isSelected ? 1 : 0
            button.layer.borderColor = item.accent.withAlphaComponent(0.45).cgColor
            button.titleLabel?.font = LabUI.font(11.5, weight: isSelected ? .bold : .medium, mono: true)
            button.accessibilityValue = isSelected ? "已选中" : nil
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    func updateAssetChrome(for state: DeliveryGuardViewModel.AssetState) {
        assetStateLabel.text = state.chipTitle
        assetStateLabel.textColor = state.accent
        assetStateBadge.backgroundColor = state.accent.withAlphaComponent(0.12)
        assetStateBadge.layer.borderColor = state.accent.withAlphaComponent(0.30).cgColor
        assetStateBadge.accessibilityLabel = state.title
        assetIconView.image = UIImage(systemName: state.icon)
        assetIconView.tintColor = state.accent
        for (item, button) in assetStateButtons {
            applyAssetChipStyle(button, state: item, selected: item == state)
        }
    }

    func updateDebounceLabels(_ state: DeliveryGuardViewModel.ViewState) {
        debounceAcceptedLabel.text = "\(state.acceptedRefreshCount)"
        debounceShieldedLabel.text = "\(state.shieldedRefreshCount)"
    }

    func updateSnapshot(_ state: DeliveryGuardViewModel.ViewState) {
        let diff = state.snapshotDiff
        let tolerance = DeliveryGuardViewModel.snapshotTolerance
        snapshotBadgeLabel.text = String(format: "DIFF: %.2f%% %@", diff, state.snapshotPass ? "PASS" : "FAIL")
        snapshotPercentLabel.text = String(format: "%.2f%% / %.1f%%", diff, tolerance)
        snapshotBar.setProgress(min(diff / tolerance, 1))
        snapshotBadge.accessibilityLabel = snapshotBadgeLabel.text
    }

    // MARK: - Review list

    func rebuildReviewList(for state: DeliveryGuardViewModel.ViewState) {
        reviewListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        reviewListStack.alpha = 0

        switch state.reviewMode {
        case .rawNoise:
            let comments = DeliveryGuardViewModel.comments(for: .rawNoise)
            reviewListStack.addArrangedSubview(makeNoiseBanner())
            for comment in comments where comment.severity == .nit {
                reviewListStack.addArrangedSubview(makeCommentRow(comment, compact: true))
            }
            reviewListStack.addArrangedSubview(makeSignalDivider())
            for comment in comments where comment.severity != .nit {
                reviewListStack.addArrangedSubview(makeCommentRow(comment, compact: false))
            }
        case .filtered:
            reviewListStack.addArrangedSubview(makeFilterSummary())
            for comment in DeliveryGuardViewModel.comments(for: .filtered) {
                reviewListStack.addArrangedSubview(makeCommentRow(comment, compact: false))
            }
            reviewListStack.addArrangedSubview(makeTriageSummary())
        case .converged:
            for row in DeliveryGuardViewModel.convergenceRows(for: state.convergenceStage) {
                reviewListStack.addArrangedSubview(makeConvergenceRow(row))
            }
            reviewListStack.addArrangedSubview(makeConvergenceBanner(for: state.convergenceStage))
        }

        UIView.animate(withDuration: 0.18) {
            self.reviewListStack.alpha = 1
        }
    }
}
