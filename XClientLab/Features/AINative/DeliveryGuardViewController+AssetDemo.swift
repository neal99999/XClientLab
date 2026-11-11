import SnapKit
import UIKit

extension DeliveryGuardViewController {
    func makeAssetDemoCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "INTERACTIVE DEMO",
            title: "六态切换与快照差分",
            trailing: "PIXEL DIFF",
            accent: LabUI.mint
        ))

        let chipColumn = labStack(spacing: 6)
        let states = DeliveryGuardViewModel.AssetState.allCases
        for start in stride(from: 0, to: states.count, by: 3) {
            let rowStates = Array(states[start ..< min(start + 3, states.count)])
            let chipRow = labStack(axis: .horizontal, spacing: 6, distribution: .fillEqually)
            for state in rowStates {
                let button = makeAssetChip(state)
                assetStateButtons[state] = button
                chipRow.addArrangedSubview(button)
            }
            chipColumn.addArrangedSubview(chipRow)
        }
        card.add(chipColumn)

        card.add(makeAssetCanvas())
        card.add(makeSnapshotStrip())

        refreshButton.accessibilityIdentifier = "asset.refresh"
        refreshButton.accessibilityLabel = "模拟刷新账户"
        refreshButton.addAction(UIAction { [weak self] _ in
            self?.viewModel.requestRefresh()
        }, for: .touchUpInside)
        return card
    }

    func makeAssetChip(_ state: DeliveryGuardViewModel.AssetState) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "asset.state.\(state.rawValue)"
        button.accessibilityLabel = state.title
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        config.background.cornerRadius = 7
        button.configuration = config
        applyAssetChipStyle(button, state: state, selected: false)
        button.addAction(UIAction { [weak self] _ in
            self?.viewModel.selectAssetState(state)
        }, for: .touchUpInside)
        return button
    }

    func applyAssetChipStyle(
        _ button: UIButton,
        state: DeliveryGuardViewModel.AssetState,
        selected: Bool
    ) {
        var config = button.configuration ?? .plain()
        var title = AttributeContainer()
        title.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        title.foregroundColor = selected ? state.accent : LabUI.textTertiary
        config.attributedTitle = AttributedString(state.chipTitle, attributes: title)
        config.background.backgroundColor = selected ? state.accent.withAlphaComponent(0.16) : LabUI.surfaceRaised
        config.background.strokeColor = selected ? state.accent.withAlphaComponent(0.55) : .clear
        config.background.strokeWidth = selected ? 1 : 0
        button.configuration = config
    }

    func makeAssetCanvas() -> UIView {
        let canvas = UIView()
        canvas.backgroundColor = LabUI.surfaceRaised.withAlphaComponent(0.72)
        canvas.layer.cornerRadius = 16
        canvas.layer.cornerCurve = .continuous
        canvas.layer.borderWidth = 1
        canvas.layer.borderColor = LabUI.hairline.cgColor
        canvas.accessibilityIdentifier = "asset.card"

        let header = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        let iconBox = UIView()
        iconBox.backgroundColor = LabUI.mint.withAlphaComponent(0.10)
        iconBox.layer.cornerRadius = 12
        iconBox.layer.cornerCurve = .continuous
        iconBox.snp.makeConstraints { make in
            make.width.height.equalTo(38)
        }
        assetIconView.tintColor = LabUI.mint
        assetIconView.contentMode = .scaleAspectFit
        iconBox.addSubview(assetIconView)
        assetIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }
        header.addArrangedSubview(iconBox)

        let titles = labStack(spacing: 1)
        titles.addArrangedSubview(labLabel("现货账户", size: 13, weight: .semibold, color: LabUI.textPrimary, lines: 1))
        titles.addArrangedSubview(labLabel("SPOT BALANCE · USDT", size: 8.5, weight: .medium, color: LabUI.textTertiary, mono: true, lines: 1))
        header.addArrangedSubview(titles)
        let headerSpacer = UIView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(headerSpacer)

        assetStateBadge.isAccessibilityElement = true
        assetStateBadge.accessibilityIdentifier = "asset.state.badge"
        header.addArrangedSubview(assetStateBadge)

        assetBodyStack.accessibilityIdentifier = "asset.body"
        let stack = labStack(spacing: 12)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(assetBodyStack)
        canvas.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
        }
        return canvas
    }

    func makeSnapshotStrip() -> UIView {
        let stack = labStack(spacing: 6)
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.addArrangedSubview(labLabel(
            "SNAPSHOT DIFF · BASELINE vs CURRENT",
            size: 8.5,
            weight: .bold,
            color: LabUI.textTertiary,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        snapshotBadge.isAccessibilityElement = true
        snapshotBadge.accessibilityIdentifier = "asset.snapshot.badge"
        row.addArrangedSubview(snapshotBadge)
        stack.addArrangedSubview(row)

        snapshotBar.accessibilityIdentifier = "asset.snapshot.bar"
        stack.addArrangedSubview(snapshotBar)

        let foot = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        foot.addArrangedSubview(labLabel(
            "容差 ≤0.5% · 超阈值 CI 阻断并输出差分热区",
            size: 9,
            color: LabUI.textTertiary,
            lines: 0
        ))
        let footSpacer = UIView()
        footSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        foot.addArrangedSubview(footSpacer)
        foot.addArrangedSubview(snapshotPercentLabel)
        stack.addArrangedSubview(foot)
        return stack
    }
}
