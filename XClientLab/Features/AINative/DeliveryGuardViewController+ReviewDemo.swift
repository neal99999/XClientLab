import SnapKit
import UIKit

extension DeliveryGuardViewController {
    func makeMetricRow() -> UIView {
        let stages = LabMetricTileView(label: "STAGES", value: "04", detail: "前 / 中 / 合 / 后", color: LabUI.cyan)
        let noise = LabMetricTileView(label: "NOISE FILTER", value: "92", unit: "%", detail: "噪音拦截率", color: LabUI.mint)
        let snapshot = LabMetricTileView(label: "SNAPSHOT TOL", value: "≤0.5", unit: "%", detail: "像素容差", color: LabUI.amber)
        let convergence = LabMetricTileView(label: "CONVERGENCE", value: "≤3", unit: "RNDS", detail: "审查熔断", color: LabUI.coral)

        stages.isAccessibilityElement = true
        stages.accessibilityIdentifier = "metric.stages"
        stages.accessibilityLabel = "STAGES 04，PR 前 / 中 / 合 / 后"
        noise.isAccessibilityElement = true
        noise.accessibilityIdentifier = "metric.noise"
        noise.accessibilityLabel = "NOISE FILTER 92%，噪音拦截率"
        snapshot.isAccessibilityElement = true
        snapshot.accessibilityIdentifier = "metric.snapshot"
        snapshot.accessibilityLabel = "SNAPSHOT TOL 小于等于 0.5%，像素容差"
        convergence.isAccessibilityElement = true
        convergence.accessibilityIdentifier = "metric.convergence"
        convergence.accessibilityLabel = "CONVERGENCE 不超过 3 轮，审查熔断"

        return labMetricRow([stages, noise, snapshot, convergence])
    }

    func makeReviewDemoCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "INTERACTIVE DEMO",
            title: "审查信噪比过滤与收敛",
            trailing: "SIGNAL / NOISE",
            accent: LabUI.cyan
        ))

        let statusRow = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        statusRow.addArrangedSubview(reviewStateLabel)
        let statusSpacer = UIView()
        statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusRow.addArrangedSubview(statusSpacer)
        statusRow.addArrangedSubview(reviewSignalLabel)
        card.add(statusRow)
        card.add(reviewSummaryLabel)

        reviewSignalBar.accessibilityIdentifier = "review.signal"
        card.add(reviewSignalBar)
        card.add(reviewFootnoteLabel)

        let modeStack = labStack(spacing: 6)
        for mode in DeliveryGuardViewModel.ReviewMode.allCases {
            let button = LabButton(title: mode.title, style: .secondary, accent: mode.accent)
            button.accessibilityIdentifier = "review.mode.\(mode.rawValue)"
            button.accessibilityLabel = mode.title
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel.selectReviewMode(mode)
            }, for: .touchUpInside)
            reviewModeButtons[mode] = button
            modeStack.addArrangedSubview(button)
        }
        card.add(modeStack)

        reviewListStack.accessibilityIdentifier = "review.list"
        card.add(reviewListStack)

        reviewStepButton.accessibilityIdentifier = "review.step"
        reviewStepButton.addAction(UIAction { [weak self] _ in
            self?.viewModel.advanceConvergence()
        }, for: .touchUpInside)
        card.add(reviewStepButton)
        return card
    }

    func makeNoiseBanner() -> UIView {
        makeBanner(
            text: "8 条 NIT 被排在最前 · 真正的 BLOCKER 被挤到列表末尾",
            color: LabUI.coral,
            symbol: "exclamationmark.triangle.fill"
        )
    }

    func makeFilterSummary() -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.mint.withAlphaComponent(0.08)
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.mint.withAlphaComponent(0.22).cgColor
        let stack = labStack(spacing: 4)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        head.addArrangedSubview(labLabel(
            "FILTER HOOK · 8 / 10 已拦截",
            size: 10,
            weight: .bold,
            color: LabUI.mint,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        head.addArrangedSubview(LabTagView(text: "92%", color: LabUI.mint))
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(labLabel(
            "命中规则：命名建议 / 注释补全 / 空行格式 / 风格偏好",
            size: 10.5,
            color: LabUI.textSecondary,
            lines: 0
        ))
        stack.addArrangedSubview(labLabel(
            "信噪比 20% → 100% · BLOCKER 与 MAJOR 被提到最前",
            size: 10,
            color: LabUI.textTertiary,
            lines: 0
        ))
        box.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        return box
    }

    func makeTriageSummary() -> UIView {
        let stack = labStack(spacing: 3)
        stack.addArrangedSubview(labLabel(
            "TRIAGE · 风险分级审批",
            size: 9,
            weight: .bold,
            color: LabUI.amber,
            mono: true,
            lines: 1
        ))
        stack.addArrangedSubview(labLabel(
            "P0 → Tier 3（2 位资深 + 安全专员） · P1 → Tier 2（业务负责人确认）",
            size: 10,
            color: LabUI.textSecondary,
            lines: 0
        ))
        return stack
    }

    func makeCommentRow(_ comment: DeliveryGuardViewModel.ReviewComment, compact: Bool) -> UIView {
        let container = UIView()
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .top)
        row.addArrangedSubview(LabTagView(
            text: comment.severity.rawValue,
            color: comment.severity.color,
            filled: comment.severity == .blocker
        ))

        let text = labStack(spacing: 3)
        text.addArrangedSubview(labLabel(
            comment.title,
            size: compact ? 11 : 12.5,
            weight: compact ? .regular : .semibold,
            color: compact ? LabUI.textSecondary : LabUI.textPrimary,
            lines: compact ? 1 : 0
        ))
        if let detail = comment.detail {
            text.addArrangedSubview(labLabel(detail, size: 11, color: LabUI.textSecondary, lines: 0))
        }
        if let location = comment.location {
            text.addArrangedSubview(labLabel(location, size: 9, color: LabUI.textTertiary, mono: true, lines: 0))
        }
        row.addArrangedSubview(text)

        container.addSubview(row)
        if comment.severity == .nit {
            row.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            container.backgroundColor = comment.severity.color.withAlphaComponent(0.07)
            container.layer.cornerRadius = 10
            container.layer.cornerCurve = .continuous
            row.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(10)
            }
        }
        container.accessibilityIdentifier = "review.comment.\(comment.id)"
        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(comment.severity.rawValue) \(comment.title) \(comment.detail ?? "")"
        return container
    }

    func makeSignalDivider() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.addArrangedSubview(labLabel(
            "SIGNAL (BURIED)",
            size: 8.5,
            weight: .bold,
            color: LabUI.coral,
            mono: true,
            lines: 1
        ))
        let line = UIView()
        line.backgroundColor = LabUI.coral.withAlphaComponent(0.25)
        line.snp.makeConstraints { make in
            make.height.equalTo(0.8)
        }
        row.addArrangedSubview(line)
        return row
    }

    func makeConvergenceRow(_ row: DeliveryGuardViewModel.ConvergenceRow) -> UIView {
        let container = labStack(axis: .horizontal, spacing: 9, alignment: .top)
        let status = labLabel(row.status.symbol, size: 11, weight: .bold, color: row.status.color, mono: true, lines: 1)
        status.textAlignment = .center
        status.backgroundColor = row.status.color.withAlphaComponent(0.12)
        status.layer.cornerRadius = 7
        status.layer.masksToBounds = true
        status.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
        container.addArrangedSubview(status)

        let text = labStack(spacing: 2)
        text.addArrangedSubview(labLabel(
            row.title,
            size: 12.5,
            weight: .semibold,
            color: row.status == .pending ? LabUI.textTertiary : LabUI.textPrimary,
            lines: 1
        ))
        text.addArrangedSubview(labLabel(row.detail, size: 10.5, color: LabUI.textSecondary, lines: 0))
        container.addArrangedSubview(text)
        container.accessibilityIdentifier = "review.round.\(row.index)"
        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(row.title)，\(row.status.label)"
        return container
    }

    func makeConvergenceBanner(for stage: DeliveryGuardViewModel.ConvergenceStage) -> UIView {
        switch stage {
        case .round1, .round2:
            return makeBanner(
                text: "第 \(stage.rawValue)/3 轮进行中 · 再次步进查看收敛结果",
                color: stage.accent,
                symbol: "arrow.triangle.2.circlepath"
            )
        case .round3:
            return makeBanner(
                text: "CONVERGED · 第 3 轮通过，2 条问题已进入分级审批",
                color: LabUI.mint,
                symbol: "checkmark.seal.fill"
            )
        case .circuitBreaker:
            return makeBanner(
                text: "CIRCUIT BREAKER · 第 4 轮被拦截，自动审查终止，转人工仲裁",
                color: LabUI.coral,
                symbol: "hand.raised.fill"
            )
        }
    }

    func makeBanner(text: String, color: UIColor, symbol: String) -> UIView {
        let box = UIView()
        box.backgroundColor = color.withAlphaComponent(0.08)
        box.layer.cornerRadius = 10
        box.layer.cornerCurve = .continuous
        let row = labStack(axis: .horizontal, spacing: 7, alignment: .center)
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit
        icon.snp.makeConstraints { make in
            make.width.height.equalTo(14)
        }
        row.addArrangedSubview(icon)
        row.addArrangedSubview(labLabel(text, size: 10.5, weight: .medium, color: color, lines: 0))
        box.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
        return box
    }
}
