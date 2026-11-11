import SnapKit
import UIKit

private struct DeliveryStateCell {
    let name: String
    let detail: String
    let color: UIColor
}

extension DeliveryGuardViewController {
    func makeFigmaCard() -> UIView {
        let card = LabCardView(accent: LabUI.mint, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "FIGMA → UIKIT",
            title: "工业级落地四步法",
            trailing: "4 STEPS",
            accent: LabUI.mint
        ))
        card.add(makeFigmaStep(
            index: "01",
            title: "Auto Layout → SnapKit 声明式映射",
            detail: "Fill / Hug / Fixed 严禁写死宽高，转换为约束与抗拉伸 / 抗压缩优先级，并强制对齐 4pt / 8pt 栅格。",
            accent: LabUI.cyan
        ))
        card.add(LabCodeBlockView(
            code: """
            // Fill / Hug / Fixed → 约束，而不是写死 frame
            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview()
                make.trailing.lessThanOrEqualTo(badge.snp.leading).offset(-8)
            }
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            """,
            accent: LabUI.cyan,
            title: "SNAPKIT · PRIORITY-AWARE CONSTRAINTS"
        ))
        card.add(makeDivider())
        card.add(makeFigmaStep(
            index: "02",
            title: "Design Tokens 查表语义化",
            detail: "禁止 Hex 色值魔数，强制替换为 LabUI.backgroundTop、LabUI.font(...) 等工程语义资产，主题切换自动跟随。",
            accent: LabUI.violet
        ))
        card.add(makeDivider())
        card.add(makeFigmaStep(
            index: "03",
            title: "UI 六态防御矩阵",
            detail: "写代码前先输出《状态确认表》，由单向 render(_ state:) 统一驱动，消灭散落的布尔值泥潭。",
            accent: LabUI.amber
        ))
        card.add(makeStateMatrixBox())
        card.add(makeDivider())
        card.add(makeFigmaStep(
            index: "04",
            title: "SnapshotTesting 像素闭环",
            detail: "弃用人工眼测：机器级像素 Diff（容差 ≤0.5%），差分图反向修正 SnapKit 约束，CI 直接阻断回归。",
            accent: LabUI.mint
        ))
        card.add(makeSnapshotEvidence())
        return card
    }

    func makeFigmaStep(index: String, title: String, detail: String, accent: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
        let badge = labLabel(index, size: 9.5, weight: .bold, color: accent, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = accent.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 7
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(28)
            make.height.equalTo(24)
        }
        row.addArrangedSubview(badge)

        let text = labStack(spacing: 3)
        text.addArrangedSubview(labLabel(title, size: 13, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 0))
        text.addArrangedSubview(labLabel(detail, size: 11, color: LabUI.textSecondary, lines: 0))
        row.addArrangedSubview(text)
        row.accessibilityIdentifier = "figma.step.\(index)"
        return row
    }

    func makeStateMatrixBox() -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.surfaceRaised.withAlphaComponent(0.55)
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.hairline.cgColor
        let stack = labStack(spacing: 8)
        let rows: [[DeliveryStateCell]] = [
            [
                DeliveryStateCell(name: "LOADING", detail: "骨架屏", color: LabUI.steel),
                DeliveryStateCell(name: "LOADED", detail: "理想态", color: LabUI.mint)
            ],
            [
                DeliveryStateCell(name: "EMPTY", detail: "缺省态", color: LabUI.amber),
                DeliveryStateCell(name: "ERROR & RETRY", detail: "失败重试", color: LabUI.coral)
            ],
            [
                DeliveryStateCell(name: "BOUNDARY / EXTREME", detail: "长文本 / 多语言", color: LabUI.amber),
                DeliveryStateCell(name: "DEBOUNCE", detail: "暴力狂点", color: LabUI.cyan)
            ]
        ]
        for row in rows {
            let cells = labStack(axis: .horizontal, spacing: 10, distribution: .fillEqually)
            for cell in row {
                cells.addArrangedSubview(makeStateCell(name: cell.name, detail: cell.detail, color: cell.color))
            }
            stack.addArrangedSubview(cells)
        }
        box.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        box.accessibilityIdentifier = "figma.state.matrix"
        return box
    }

    func makeStateCell(name: String, detail: String, color: UIColor) -> UIView {
        let stack = labStack(spacing: 2)
        let head = labStack(axis: .horizontal, spacing: 4, alignment: .center)
        head.addArrangedSubview(LabStatusDotView(color: color, size: 5))
        head.addArrangedSubview(labLabel(name, size: 8.5, weight: .bold, color: color, mono: true, lines: 1))
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(labLabel(detail, size: 9.5, color: LabUI.textTertiary, lines: 1))
        return stack
    }

    func makeSnapshotEvidence() -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.mint.withAlphaComponent(0.07)
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.mint.withAlphaComponent(0.20).cgColor
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        row.addArrangedSubview(labLabel(
            "SNAPSHOT GATE",
            size: 8.5,
            weight: .bold,
            color: LabUI.mint,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(LabTagView(text: "DIFF ≤ 0.5%", color: LabUI.mint))
        row.addArrangedSubview(LabTagView(text: "CI BLOCK", color: LabUI.coral))
        box.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        return box
    }

    func makeChecklistCard() -> UIView {
        let card = LabCardView(accent: LabUI.amber, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "HUMAN IN THE LOOP",
            title: "人类只做 5 个决策",
            trailing: "NON-DELEGABLE",
            accent: LabUI.amber
        ))
        let items: [(String, String)] = [
            ("意图契合度", "AI 是否解决了真实问题，而不是把代码改得更优雅。"),
            ("数据与边界安全", "金额精度、Nil / 空集合、并发、越界与时区。"),
            ("前向 / 后向兼容", "API、DB、Feature Flag 与旧版本客户端能否共存。"),
            ("容灾与降级", "弱网、超时、限流与回滚路径是否真的可执行。"),
            ("单测真实性", "断言验证行为而非复制实现，失败路径被覆盖。")
        ]
        let colors = [LabUI.cyan, LabUI.mint, LabUI.amber, LabUI.coral, LabUI.violet]
        for (offset, item) in items.enumerated() {
            card.add(makeChecklistRow(
                index: String(format: "%02d", offset + 1),
                title: item.0,
                detail: item.1,
                color: colors[offset]
            ))
            if offset < items.count - 1 {
                card.add(makeDivider())
            }
        }
        card.add(labLabel(
            "AI 负责产能与证据，人负责方向与底线。",
            size: 11,
            weight: .semibold,
            color: LabUI.amber,
            lines: 0
        ))
        return card
    }

    func makeChecklistRow(index: String, title: String, detail: String, color: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .top)
        let badge = labLabel(index, size: 9, weight: .bold, color: color, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = color.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 7
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(26)
            make.height.equalTo(24)
        }
        row.addArrangedSubview(badge)

        let text = labStack(spacing: 2)
        text.addArrangedSubview(labLabel(title, size: 12.5, weight: .semibold, color: LabUI.textPrimary, lines: 0))
        text.addArrangedSubview(labLabel(detail, size: 10.5, color: LabUI.textSecondary, lines: 0))
        row.addArrangedSubview(text)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        let seal = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        seal.tintColor = color.withAlphaComponent(0.75)
        seal.contentMode = .scaleAspectFit
        seal.snp.makeConstraints { make in
            make.width.height.equalTo(15)
        }
        row.addArrangedSubview(seal)
        row.accessibilityIdentifier = "human.check.\(index)"
        return row
    }
}
