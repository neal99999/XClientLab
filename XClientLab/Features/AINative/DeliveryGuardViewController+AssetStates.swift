import SnapKit
import UIKit

extension DeliveryGuardViewController {
    func rebuildAssetBody(for state: DeliveryGuardViewModel.AssetState) {
        stopSkeletonAnimations()
        assetBodyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch state {
        case .loading: buildLoadingBody()
        case .loaded: buildLoadedBody()
        case .empty: buildEmptyBody()
        case .error: buildErrorBody()
        case .extreme: buildExtremeBody()
        case .debounce: buildDebounceBody()
        }
        if state == .loading {
            startSkeletonAnimations()
        }
    }

    func buildLoadingBody() {
        assetBodyStack.addArrangedSubview(labLabel(
            "LOADING · 骨架屏呼吸",
            size: 9,
            weight: .bold,
            color: LabUI.steel,
            mono: true,
            lines: 1
        ))
        let head = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        head.addArrangedSubview(makeSkeletonBlock(width: 38, height: 38, radius: 19))
        let lines = labStack(spacing: 6)
        lines.addArrangedSubview(makeSkeletonBar(width: 120, height: 10))
        lines.addArrangedSubview(makeSkeletonBar(width: 72, height: 9))
        head.addArrangedSubview(lines)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        head.addArrangedSubview(spacer)
        assetBodyStack.addArrangedSubview(head)
        assetBodyStack.addArrangedSubview(makeSkeletonBar(width: 180, height: 26))
        assetBodyStack.addArrangedSubview(makeSkeletonBar(width: 220, height: 10))
        assetBodyStack.addArrangedSubview(makeSkeletonBar(width: 150, height: 10))
    }

    func buildLoadedBody() {
        assetBodyStack.addArrangedSubview(labLabel(
            "总资产估值",
            size: 9.5,
            weight: .medium,
            color: LabUI.textTertiary,
            mono: true,
            lines: 1
        ))

        let amountRow = labStack(axis: .horizontal, spacing: 6, alignment: .firstBaseline)
        let amount = labLabel("128,450.72", size: 30, weight: .bold, color: LabUI.textPrimary, rounded: true, lines: 1)
        amount.adjustsFontSizeToFitWidth = true
        amount.minimumScaleFactor = 0.72
        amount.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        amountRow.addArrangedSubview(amount)
        let unit = labLabel("USDT", size: 10, weight: .bold, color: LabUI.textTertiary, mono: true, lines: 1)
        unit.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountRow.addArrangedSubview(unit)
        let amountSpacer = UIView()
        amountSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        amountRow.addArrangedSubview(amountSpacer)
        amountRow.addArrangedSubview(LabTagView(text: "+2.48% 24H", color: LabUI.mint))
        assetBodyStack.addArrangedSubview(amountRow)

        assetBodyStack.addArrangedSubview(labLabel(
            "≈ $128,450.72 · 可用 96,300.20 USDT",
            size: 10.5,
            color: LabUI.textSecondary,
            mono: true,
            lines: 0
        ))
        assetBodyStack.addArrangedSubview(makeDivider())
        assetBodyStack.addArrangedSubview(makeHoldingRow(
            symbol: "BTC",
            name: "Bitcoin",
            amount: "1.2458",
            value: "≈ $81,212.30",
            color: LabUI.amber,
            trend: [42, 44, 41, 47, 49, 46, 52, 55]
        ))
        assetBodyStack.addArrangedSubview(makeHoldingRow(
            symbol: "USDT",
            name: "Tether",
            amount: "32,080.44",
            value: "≈ $32,080.44",
            color: LabUI.mint,
            trend: [30, 30, 31, 30, 31, 31, 30, 31]
        ))
    }

    func buildEmptyBody() {
        let stack = labStack(spacing: 8, alignment: .center)
        let icon = UIImageView(image: UIImage(systemName: "tray"))
        icon.tintColor = LabUI.steel
        icon.contentMode = .scaleAspectFit
        icon.snp.makeConstraints { make in
            make.width.height.equalTo(30)
        }
        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(labLabel("暂无资产", size: 14, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 1))
        let detail = labLabel(
            "充值后开始交易；或切换到模拟资金账户体验完整链路。",
            size: 11,
            color: LabUI.textSecondary,
            lines: 0
        )
        detail.textAlignment = .center
        stack.addArrangedSubview(detail)

        let cta = LabButton(title: "去充值", style: .secondary, accent: LabUI.mint, systemImage: "plus.circle.fill")
        cta.accessibilityIdentifier = "asset.empty.cta"
        cta.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            LabUIKit.alert(
                on: self,
                title: "演示环境",
                message: "该入口用于展示 Empty 态的引导闭环，不会发起真实充值。",
                confirmTitle: "知道了"
            ) {}
        }, for: .touchUpInside)
        stack.addArrangedSubview(cta)
        assetBodyStack.addArrangedSubview(stack)
    }

    func buildErrorBody() {
        let stack = labStack(spacing: 8, alignment: .center)
        let icon = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
        icon.tintColor = LabUI.coral
        icon.contentMode = .scaleAspectFit
        icon.snp.makeConstraints { make in
            make.width.height.equalTo(30)
        }
        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(labLabel("资产加载失败", size: 14, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 1))
        let detail = labLabel("网络超时（-1001）· 已保留上一次成功快照，可安全重试。", size: 11, color: LabUI.textSecondary, lines: 0)
        detail.textAlignment = .center
        stack.addArrangedSubview(detail)

        let retry = LabButton(title: "重试", style: .secondary, accent: LabUI.coral, systemImage: "arrow.clockwise")
        retry.accessibilityIdentifier = "asset.retry"
        retry.addAction(UIAction { [weak self] _ in
            self?.viewModel.retryAsset()
        }, for: .touchUpInside)
        stack.addArrangedSubview(retry)
        assetBodyStack.addArrangedSubview(stack)
    }

    func buildExtremeBody() {
        assetBodyStack.addArrangedSubview(labLabel(
            "BOUNDARY · 30 位数字 + 超长币种名",
            size: 9,
            weight: .bold,
            color: LabUI.amber,
            mono: true,
            lines: 1
        ))

        let amount = labLabel(
            "123456789012345678901234567890.12",
            size: 24,
            weight: .bold,
            color: LabUI.textPrimary,
            mono: true,
            lines: 1
        )
        amount.adjustsFontSizeToFitWidth = true
        amount.minimumScaleFactor = 0.34
        amount.lineBreakMode = .byClipping
        amount.accessibilityIdentifier = "asset.extreme.amount"
        assetBodyStack.addArrangedSubview(amount)

        let name = labLabel(
            "LIQUIDITY-STAKED-ETHEREUM-DERIVATIVE-VAULT-2026",
            size: 9.5,
            weight: .medium,
            color: LabUI.textSecondary,
            mono: true,
            lines: 1
        )
        name.lineBreakMode = .byTruncatingTail
        name.accessibilityIdentifier = "asset.extreme.symbol"
        assetBodyStack.addArrangedSubview(name)

        let badgeRow = labStack(axis: .horizontal, spacing: 6, alignment: .center)
        badgeRow.addArrangedSubview(LabTagView(text: "AUTOLAYOUT INTACT", color: LabUI.mint))
        badgeRow.addArrangedSubview(LabTagView(text: "TRUNCATION · TAIL", color: LabUI.steel))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        badgeRow.addArrangedSubview(spacer)
        assetBodyStack.addArrangedSubview(badgeRow)
        assetBodyStack.addArrangedSubview(labLabel(
            "压缩阻抗 + adjustsFontSizeToFitWidth 兜底：数字自动缩放，名称省略，约束链不撕裂。",
            size: 10,
            color: LabUI.textTertiary,
            lines: 0
        ))
    }

    func buildDebounceBody() {
        assetBodyStack.addArrangedSubview(labLabel(
            "DEBOUNCE · 600ms 窗口内只放行首个请求",
            size: 9,
            weight: .bold,
            color: LabUI.cyan,
            mono: true,
            lines: 1
        ))

        let stats = labStack(axis: .horizontal, spacing: 8, distribution: .fillEqually)
        stats.addArrangedSubview(makeDebounceStat(
            title: "ACCEPTED",
            valueLabel: debounceAcceptedLabel,
            detail: "放行",
            color: LabUI.mint
        ))
        stats.addArrangedSubview(makeDebounceStat(
            title: "SHIELDED",
            valueLabel: debounceShieldedLabel,
            detail: "被防抖拦截",
            color: LabUI.coral
        ))
        assetBodyStack.addArrangedSubview(stats)
        assetBodyStack.addArrangedSubview(refreshButton)
        assetBodyStack.addArrangedSubview(labLabel(
            "疯狂点按 REFRESH：首个请求放行，600ms 内的后续请求全部被拦截。",
            size: 10,
            color: LabUI.textTertiary,
            lines: 0
        ))
    }

    func makeDebounceStat(title: String, valueLabel: UILabel, detail: String, color: UIColor) -> UIView {
        let box = UIView()
        box.backgroundColor = color.withAlphaComponent(0.07)
        box.layer.cornerRadius = 10
        box.layer.cornerCurve = .continuous
        let stack = labStack(spacing: 1)
        stack.addArrangedSubview(labLabel(title, size: 8.5, weight: .bold, color: color, mono: true, lines: 1))
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(labLabel(detail, size: 9, color: LabUI.textTertiary, lines: 1))
        box.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
        return box
    }

    func makeHoldingRow(
        symbol: String,
        name: String,
        amount: String,
        value: String,
        color: UIColor,
        trend: [Double]
    ) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 10, alignment: .center)
        let symbolLabel = labLabel(symbol, size: 9, weight: .bold, color: color, mono: true, lines: 1)
        symbolLabel.textAlignment = .center
        symbolLabel.backgroundColor = color.withAlphaComponent(0.12)
        symbolLabel.layer.cornerRadius = 9
        symbolLabel.layer.masksToBounds = true
        symbolLabel.snp.makeConstraints { make in
            make.width.equalTo(38)
            make.height.equalTo(26)
        }
        row.addArrangedSubview(symbolLabel)

        let text = labStack(spacing: 1)
        text.addArrangedSubview(labLabel(name, size: 11, weight: .semibold, color: LabUI.textPrimary, lines: 1))
        text.addArrangedSubview(labLabel(value, size: 9.5, color: LabUI.textTertiary, mono: true, lines: 1))
        row.addArrangedSubview(text)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        let sparkline = LabSparklineView(color: color)
        sparkline.snp.makeConstraints { make in
            make.width.equalTo(54)
            make.height.equalTo(22)
        }
        sparkline.update(trend)
        row.addArrangedSubview(sparkline)
        row.addArrangedSubview(labLabel(amount, size: 12, weight: .semibold, color: LabUI.textPrimary, mono: true, lines: 1))
        return row
    }

    func makeSkeletonBar(width: CGFloat, height: CGFloat) -> UIView {
        let row = labStack(axis: .horizontal, spacing: 0)
        row.addArrangedSubview(makeSkeletonBlock(width: width, height: height, radius: height / 2))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        return row
    }

    func makeSkeletonBlock(width: CGFloat, height: CGFloat, radius: CGFloat) -> UIView {
        let bar = UIView()
        bar.backgroundColor = LabUI.surfaceRaised
        bar.layer.cornerRadius = radius
        bar.layer.cornerCurve = .continuous
        bar.snp.makeConstraints { make in
            make.width.equalTo(width)
            make.height.equalTo(height)
        }
        skeletonViews.append(bar)
        return bar
    }

    func startSkeletonAnimations() {
        for bar in skeletonViews {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1.0
            animation.toValue = 0.35
            animation.duration = 0.85
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.layer.add(animation, forKey: "breathe")
        }
    }

    func stopSkeletonAnimations() {
        skeletonViews.forEach { $0.layer.removeAnimation(forKey: "breathe") }
        skeletonViews.removeAll()
    }
}
