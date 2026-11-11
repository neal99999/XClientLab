import SnapKit
import UIKit

extension DeliveryGuardViewController {
    func makePipelineCard() -> UIView {
        let card = LabCardView(accent: LabUI.cyan, padding: 16)
        card.add(LabSectionHeaderView(
            kicker: "LIFECYCLE",
            title: "四阶段全景",
            trailing: "PR → MAIN",
            accent: LabUI.cyan
        ))
        card.add(makePipelineStrip())
        card.add(makeStageRow(
            index: "01",
            title: "PR 前 · 本地闭环",
            english: "PRE-PR · LOCAL LOOP",
            accent: LabUI.cyan,
            bullets: [
                ("执行权限", "CLI 自动化测试、Playwright 浏览器截图、Instruments 采样，AI 必须拿到真实证据。"),
                ("红队对抗", "唤起全新上下文的挑错 Agent 冷启动审查，避免「自己写、自己夸」。"),
                ("无证据不提交", "自测日志与截图缺失时，本地 Hook 直接阻断 push。")
            ]
        ))
        card.add(makeDivider())
        card.add(makeStageRow(
            index: "02",
            title: "PR 中 · 信噪比治理",
            english: "IN-REVIEW · SIGNAL OVER NOISE",
            accent: LabUI.mint,
            bullets: [
                ("确定性门禁先行", "Lint / TypeCheck / SAST 机械拦截，不把 Token 浪费在格式错误上。"),
                ("AI 审查三核心", "意图契合度、领域架构相容性、隐式副作用（调用方与 DB 索引）。"),
                ("信噪比拦截 Hook", "过滤格式规范、无意义重命名与冗余空行，告警疲劳下降 92%。"),
                ("三轮收敛法则", "R1 看全局依赖并一次性指出同类问题；R2~R3 只查增量 Diff；超过 3 轮强制人工仲裁。")
            ]
        ))
        card.add(makeRiskMatrix())
        card.add(makeDivider())
        card.add(makeStageRow(
            index: "03",
            title: "合并时 · 消除语义冲突",
            english: "MERGE QUEUE · SEMANTIC SAFETY",
            accent: LabUI.amber,
            bullets: [
                ("临时预合并", "针对最新 main 预合并并跑全量 E2E，杜绝 A/B 各自绿、合并后崩。"),
                ("顺序化入队", "合并队列串行验证，避免两个 PR 同时争抢同一块代码。")
            ]
        ))
        card.add(makeDivider())
        card.add(makeStageRow(
            index: "04",
            title: "合并后 · 纵深防御",
            english: "POST-MERGE · DEFENSE IN DEPTH",
            accent: LabUI.coral,
            bullets: [
                ("Feature Flags", "功能开关默认关闭，按租户 / 地区灰度放量。"),
                ("金丝雀", "1% → 10% → 100%，每档观察错误率、P95 与业务指标。"),
                ("自动回滚", "APM 异常指标联动，毫秒级摘流并回滚到上一稳定版本。")
            ]
        ))
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
            ("PR 前", LabUI.cyan),
            ("PR 中", LabUI.mint),
            ("合并时", LabUI.amber),
            ("合并后", LabUI.coral)
        ]
        let text = NSMutableAttributedString()
        for (index, step) in steps.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(
                    string: "  →  ",
                    attributes: [
                        .font: LabUI.font(9.5, weight: .semibold, mono: true),
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

    func makeStageRow(
        index: String,
        title: String,
        english: String,
        accent: UIColor,
        bullets: [(String, String)]
    ) -> UIView {
        let container = labStack(spacing: 8)
        let head = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        let badge = labLabel(index, size: 10, weight: .bold, color: accent, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = accent.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(30)
            make.height.equalTo(26)
        }
        head.addArrangedSubview(badge)

        let titles = labStack(spacing: 1)
        titles.addArrangedSubview(labLabel(title, size: 15, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 0))
        titles.addArrangedSubview(labLabel(english, size: 9, weight: .medium, color: LabUI.textTertiary, mono: true, lines: 1))
        head.addArrangedSubview(titles)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        container.addArrangedSubview(head)

        let body = labStack(spacing: 7)
        body.isLayoutMarginsRelativeArrangement = true
        body.layoutMargins = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0)
        for bullet in bullets {
            body.addArrangedSubview(makeBullet(lead: bullet.0, detail: bullet.1, accent: accent))
        }
        container.addArrangedSubview(body)
        container.accessibilityIdentifier = "pipeline.stage.\(index)"
        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(title)。" + bullets.map { "\($0.0)：\($0.1)" }.joined(separator: " ")
        return container
    }

    func makeBullet(lead: String, detail: String, accent: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 6, alignment: .top)
        row.addArrangedSubview(labLabel("›", size: 12, weight: .bold, color: accent, mono: true, lines: 1))
        let text = NSMutableAttributedString(
            string: "\(lead)  ",
            attributes: [
                .font: LabUI.font(11.5, weight: .semibold),
                .foregroundColor: LabUI.textPrimary
            ]
        )
        text.append(NSAttributedString(
            string: detail,
            attributes: [
                .font: LabUI.font(11.5),
                .foregroundColor: LabUI.textSecondary
            ]
        ))
        let label = labLabel("", size: 11.5, lines: 0)
        label.attributedText = text
        row.addArrangedSubview(label)
        return row
    }

    func makeRiskMatrix() -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.surfaceRaised.withAlphaComponent(0.55)
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.hairline.cgColor
        let stack = labStack(spacing: 7)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        head.addArrangedSubview(labLabel(
            "RISK-GRADED APPROVAL MATRIX",
            size: 9,
            weight: .bold,
            color: LabUI.cyan,
            mono: true,
            lines: 1
        ))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        head.addArrangedSubview(LabTagView(text: "3 TIERS", color: LabUI.cyan))
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(makeTierRow(
            code: "T1",
            level: "LOW",
            scope: "文档 / UI 微调 / 补测试",
            decision: "CI + AI 通过 → 免人工自动合入",
            color: LabUI.mint
        ))
        stack.addArrangedSubview(makeTierRow(
            code: "T2",
            level: "MID",
            scope: "常规业务逻辑",
            decision: "1 位工程师确认意图",
            color: LabUI.amber
        ))
        stack.addArrangedSubview(makeTierRow(
            code: "T3",
            level: "HIGH",
            scope: "支付 / 认证 / DB Migration",
            decision: "2 位资深 + 安全专员",
            color: LabUI.coral
        ))
        box.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        return box
    }

    func makeTierRow(code: String, level: String, scope: String, decision: String, color: UIColor) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .top)
        let badge = labLabel(code, size: 9, weight: .bold, color: color, mono: true, lines: 1)
        badge.textAlignment = .center
        badge.backgroundColor = color.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 6
        badge.layer.masksToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(28)
            make.height.equalTo(20)
        }
        row.addArrangedSubview(badge)

        let text = labStack(spacing: 1)
        text.addArrangedSubview(labLabel("\(level) · \(scope)", size: 10.5, weight: .semibold, color: LabUI.textPrimary, lines: 1))
        text.addArrangedSubview(labLabel(decision, size: 10, color: color, lines: 0))
        row.addArrangedSubview(text)
        return row
    }

    func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = LabUI.hairline
        line.snp.makeConstraints { make in
            make.height.equalTo(0.8)
        }
        return line
    }
}
