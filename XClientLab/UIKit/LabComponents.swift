import Combine
import SnapKit
import UIKit

// MARK: - Small factories

func labLabel(
    _ text: String = "",
    size: CGFloat = 13,
    weight: UIFont.Weight = .regular,
    color: UIColor = LabUI.textSecondary,
    mono: Bool = false,
    rounded: Bool = false,
    lines: Int = 0
) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = LabUI.font(size, weight: weight, mono: mono, rounded: rounded)
    label.textColor = color
    label.numberOfLines = lines
    label.lineBreakMode = .byWordWrapping
    return label
}

func labStack(
    axis: NSLayoutConstraint.Axis = .vertical,
    spacing: CGFloat = 10,
    alignment: UIStackView.Alignment = .fill,
    distribution: UIStackView.Distribution = .fill
) -> UIStackView {
    let stack = UIStackView()
    stack.axis = axis
    stack.spacing = spacing
    stack.alignment = alignment
    stack.distribution = distribution
    return stack
}

// MARK: - Card

/// 所有实验卡片的统一容器：圆角、细边框、阴影、16pt 内边距。
final class LabCardView: UIView {
    let contentStack = labStack(spacing: 10)
    private let accent: UIColor?

    init(accent: UIColor? = nil, padding: CGFloat = 16) {
        self.accent = accent
        super.init(frame: .zero)
        backgroundColor = LabUI.surface.withAlphaComponent(0.92)
        layer.cornerRadius = LabUI.cardRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = (accent ?? .white).withAlphaComponent(accent == nil ? 0.06 : 0.28).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 12)

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(padding)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    func add(_ view: UIView) -> LabCardView {
        contentStack.addArrangedSubview(view)
        return self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: LabUI.cardRadius
        ).cgPath
    }
}

// MARK: - Tags

final class LabTagView: UIView {
    private let label = labLabel(size: 9.5, weight: .bold, mono: true, lines: 1)

    init(text: String, color: UIColor = LabUI.cyan, filled: Bool = false) {
        super.init(frame: .zero)
        label.text = text.uppercased()
        label.textColor = filled ? LabUI.backgroundTop : color
        label.textAlignment = .center
        backgroundColor = filled ? color : color.withAlphaComponent(0.12)
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous
        layer.borderWidth = filled ? 0 : 0.8
        layer.borderColor = color.withAlphaComponent(0.35).cgColor
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview().inset(4)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

func labTagRow(_ tags: [String], color: UIColor, spacing: CGFloat = 6) -> UIStackView {
    let row = labStack(axis: .horizontal, spacing: spacing)
    row.alignment = .leading
    for tag in tags {
        row.addArrangedSubview(LabTagView(text: tag, color: color))
    }
    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    row.addArrangedSubview(spacer)
    return row
}

// MARK: - Section header

final class LabSectionHeaderView: UIView {
    init(kicker: String, title: String, trailing: String? = nil, accent: UIColor = LabUI.cyan) {
        super.init(frame: .zero)
        let left = labStack(spacing: 4)
        left.addArrangedSubview(labLabel(
            kicker.uppercased(),
            size: 10,
            weight: .bold,
            color: accent,
            mono: true,
            lines: 1
        ))
        left.addArrangedSubview(labLabel(
            title,
            size: 19,
            weight: .semibold,
            color: LabUI.textPrimary,
            rounded: true
        ))

        let row = labStack(axis: .horizontal, spacing: 8, alignment: .firstBaseline)
        row.addArrangedSubview(left)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        if let trailing {
            let trailingLabel = labLabel(
                trailing,
                size: 10.5,
                color: LabUI.textTertiary,
                mono: true,
                lines: 1
            )
            trailingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addArrangedSubview(trailingLabel)
        }
        addSubview(row)
        row.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Screen title / module header

final class LabScreenTitleView: UIView {
    init(index: String, title: String, subtitle: String, accent: UIColor) {
        super.init(frame: .zero)
        let stack = labStack(spacing: 8)
        stack.addArrangedSubview(labLabel(index, size: 11, weight: .bold, color: accent, mono: true, lines: 1))
        stack.addArrangedSubview(labLabel(
            title,
            size: 27,
            weight: .bold,
            color: LabUI.textPrimary,
            rounded: true
        ))
        stack.addArrangedSubview(labLabel(subtitle, size: 13, color: LabUI.textSecondary, lines: 0))
        addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class LabModuleHeaderView: UIView {
    init(module: LabModule, status: String = "INTERVIEW READY") {
        super.init(frame: .zero)
        let accent = LabUI.accent(for: module)
        backgroundColor = LabUI.surface.withAlphaComponent(0.86)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = accent.withAlphaComponent(0.30).cgColor

        let top = labStack(axis: .horizontal, spacing: 12, alignment: .top)
        let left = labStack(spacing: 7)

        let meta = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        meta.addArrangedSubview(labLabel("MODULE \(module.index)", size: 10, weight: .bold, color: accent, mono: true, lines: 1))
        let rule = UIView()
        rule.backgroundColor = accent.withAlphaComponent(0.35)
        rule.snp.makeConstraints { make in
            make.width.equalTo(22)
            make.height.equalTo(0.8)
        }
        meta.addArrangedSubview(rule)
        meta.addArrangedSubview(labLabel(status, size: 9, weight: .semibold, color: LabUI.textTertiary, mono: true, lines: 1))
        left.addArrangedSubview(meta)
        left.addArrangedSubview(labLabel(module.title, size: 31, weight: .bold, color: LabUI.textPrimary, rounded: true))
        left.addArrangedSubview(labLabel(module.englishTitle, size: 10.5, weight: .medium, color: LabUI.textTertiary, mono: true))
        top.addArrangedSubview(left)

        let iconBox = UIView()
        iconBox.backgroundColor = accent.withAlphaComponent(0.10)
        iconBox.layer.cornerRadius = 20
        iconBox.layer.cornerCurve = .continuous
        iconBox.layer.borderWidth = 1
        iconBox.layer.borderColor = accent.withAlphaComponent(0.30).cgColor
        iconBox.snp.makeConstraints { make in
            make.width.height.equalTo(62)
        }
        let icon = UIImageView(image: UIImage(systemName: module.icon))
        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        iconBox.addSubview(icon)
        icon.snp.makeConstraints { make in make.center.equalToSuperview(); make.width.height.equalTo(26) }
        top.addArrangedSubview(iconBox)
        iconBox.setContentHuggingPriority(.required, for: .horizontal)

        let stack = labStack(spacing: 14)
        stack.addArrangedSubview(top)
        let tagline = labLabel(module.tagline, size: 14, color: LabUI.textSecondary)
        stack.addArrangedSubview(tagline)
        stack.addArrangedSubview(labTagRow(module.tags, color: accent))
        addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(18) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Metrics

final class LabMetricTileView: UIView {
    private let valueLabel = labLabel(size: 24, weight: .semibold, color: LabUI.cyan, rounded: true, lines: 1)
    private let unitLabel = labLabel(size: 9, weight: .medium, color: LabUI.textTertiary, mono: true, lines: 1)
    private let detailLabel = labLabel(size: 9.5, color: LabUI.textTertiary, lines: 1)

    init(label: String, value: String, unit: String? = nil, detail: String? = nil, color: UIColor = LabUI.cyan) {
        super.init(frame: .zero)
        backgroundColor = LabUI.surface.withAlphaComponent(0.86)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor

        valueLabel.text = value
        valueLabel.textColor = color
        unitLabel.text = unit
        detailLabel.text = detail

        let valueRow = labStack(axis: .horizontal, spacing: 3, alignment: .firstBaseline)
        valueRow.addArrangedSubview(valueLabel)
        valueRow.addArrangedSubview(unitLabel)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueRow.addArrangedSubview(spacer)

        let stack = labStack(spacing: 6)
        stack.addArrangedSubview(labLabel(label.uppercased(), size: 9, weight: .semibold, color: LabUI.textTertiary, mono: true, lines: 1))
        stack.addArrangedSubview(valueRow)
        if detail != nil { stack.addArrangedSubview(detailLabel) }
        addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(12) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(value: String, detail: String? = nil, color: UIColor? = nil) {
        valueLabel.text = value
        if let detail { detailLabel.text = detail }
        if let color { valueLabel.textColor = color }
    }
}

func labMetricRow(_ views: [LabMetricTileView], spacing: CGFloat = 8) -> UIStackView {
    let row = labStack(axis: .horizontal, spacing: spacing)
    row.distribution = .fillEqually
    views.forEach { row.addArrangedSubview($0) }
    return row
}

// MARK: - Callout

final class LabCalloutView: UIView {
    enum Kind {
        case problem
        case ai
        case insight

        var color: UIColor {
            switch self {
            case .problem: return LabUI.coral
            case .ai: return LabUI.cyan
            case .insight: return LabUI.amber
            }
        }

        var title: String {
            switch self {
            case .problem: return "古法排查痛点"
            case .ai: return "AI MCP 新实践切入"
            case .insight: return "面试讲解点"
            }
        }
    }

    init(kind: Kind, message: String) {
        super.init(frame: .zero)
        let color = kind.color
        backgroundColor = color.withAlphaComponent(0.07)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        let bar = UIView()
        bar.backgroundColor = color.withAlphaComponent(0.8)
        addSubview(bar)
        bar.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(2.5)
        }
        let stack = labStack(spacing: 5)
        stack.addArrangedSubview(labLabel(kind.title, size: 9.5, weight: .bold, color: color, mono: true, lines: 1))
        stack.addArrangedSubview(labLabel(message, size: 12.5, color: LabUI.textSecondary))
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalTo(bar.snp.trailing).offset(11)
            make.trailing.top.bottom.equalToSuperview().inset(11)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Code

final class LabCodeBlockView: UIView {
    init(code: String, accent: UIColor = LabUI.cyan, title: String? = nil) {
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.28)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = accent.withAlphaComponent(0.15).cgColor

        let stack = labStack(spacing: 7)
        if let title {
            stack.addArrangedSubview(labLabel(title, size: 9.5, weight: .bold, color: accent, mono: true, lines: 1))
        }
        let text = labLabel(code, size: 11, color: LabUI.textSecondary, mono: true)
        stack.addArrangedSubview(text)
        addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(12) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Buttons

final class LabButton: UIButton {
    enum Style {
        case primary
        case secondary
        case destructive
        case ghost
    }

    private let style: Style
    private let accent: UIColor

    init(title: String, style: Style = .primary, accent: UIColor = LabUI.cyan, systemImage: String? = nil) {
        self.style = style
        self.accent = accent
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = LabUI.font(11.5, weight: .bold, mono: true)
        titleLabel?.adjustsFontSizeToFitWidth = true
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        if let systemImage {
            setImage(UIImage(systemName: systemImage), for: .normal)
            tintColor = accent
            imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        }
        applyStyle()
        heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func applyStyle() {
        switch style {
        case .primary:
            backgroundColor = accent
            setTitleColor(LabUI.backgroundTop, for: .normal)
            tintColor = LabUI.backgroundTop
        case .secondary:
            backgroundColor = accent.withAlphaComponent(0.12)
            setTitleColor(accent, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = accent.withAlphaComponent(0.35).cgColor
        case .destructive:
            backgroundColor = LabUI.coral.withAlphaComponent(0.14)
            setTitleColor(LabUI.coral, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = LabUI.coral.withAlphaComponent(0.42).cgColor
        case .ghost:
            backgroundColor = .clear
            setTitleColor(LabUI.textSecondary, for: .normal)
        }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }
}

// MARK: - Sparkline / bar / status

final class LabSparklineView: UIView {
    private var values: [Double] = []
    private let color: UIColor

    init(color: UIColor = LabUI.cyan) {
        self.color = color
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ values: [Double]) {
        self.values = Array(values.suffix(64))
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard values.count > 1, let maxValue = values.max(), maxValue > 0 else { return }
        let path = UIBezierPath()
        let step = rect.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let y = rect.maxY - CGFloat(value / maxValue) * (rect.height - 4) - 2
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        color.setStroke()
        path.lineWidth = 1.8
        path.lineJoinStyle = .round
        path.stroke()

        let fill = path.copy() as! UIBezierPath
        fill.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        fill.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        fill.close()
        color.withAlphaComponent(0.10).setFill()
        fill.fill()
    }
}

final class LabMiniBarView: UIView {
    private let fill = UIView()
    private let track = UIView()
    private let fillColor: UIColor
    private var fraction: CGFloat = 0

    init(color: UIColor = LabUI.cyan) {
        self.fillColor = color
        super.init(frame: .zero)
        track.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        track.layer.cornerRadius = 3
        fill.backgroundColor = color
        fill.layer.cornerRadius = 3
        addSubview(track)
        addSubview(fill)
        track.snp.makeConstraints { make in make.edges.equalToSuperview() }
        fill.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        heightAnchor.constraint(equalToConstant: 6).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setProgress(_ value: Double) {
        fraction = CGFloat(max(0, min(1, value)))
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
    }
}

final class LabStatusDotView: UIView {
    init(color: UIColor = LabUI.mint, size: CGFloat = 6) {
        super.init(frame: .zero)
        backgroundColor = color
        layer.cornerRadius = size / 2
        snp.makeConstraints { make in make.width.height.equalTo(size) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Timeline

final class LabTimelineRowView: UIView {
    init(time: String, title: String, detail: String, color: UIColor, isLast: Bool = false) {
        super.init(frame: .zero)
        let rail = UIView()
        rail.backgroundColor = color.withAlphaComponent(0.25)
        addSubview(rail)
        rail.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(5)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(1)
        }
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 4
        addSubview(dot)
        dot.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.top.equalToSuperview().offset(6)
            make.width.height.equalTo(8)
        }
        let stack = labStack(spacing: 3)
        let head = labStack(axis: .horizontal, spacing: 8, alignment: .firstBaseline)
        head.addArrangedSubview(labLabel(time, size: 9.5, weight: .semibold, color: color, mono: true, lines: 1))
        head.addArrangedSubview(labLabel(title, size: 12.5, weight: .semibold, color: LabUI.textPrimary, lines: 1))
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(labLabel(detail, size: 11.5, color: LabUI.textSecondary))
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.trailing.top.bottom.equalToSuperview()
        }
        if isLast { rail.isHidden = true }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Console

final class LabConsoleView: UIView, UITableViewDataSource {
    private let store: LabLogStore
    private let table = UITableView(frame: .zero, style: .plain)
    private let countLabel = labLabel("0 LINES", size: 9, color: LabUI.textTertiary, mono: true, lines: 1)
    private var cancellable: AnyCancellable?

    init(store: LabLogStore, title: String = "RUN LOG", height: CGFloat = 210, accent: UIColor = LabUI.cyan) {
        self.store = store
        super.init(frame: .zero)
        let card = LabCardView(accent: accent, padding: 0)
        card.backgroundColor = UIColor.black.withAlphaComponent(0.26)

        let header = labStack(axis: .horizontal, spacing: 8, alignment: .center)
        header.addArrangedSubview(LabStatusDotView(color: accent))
        header.addArrangedSubview(labLabel(title, size: 9.5, weight: .bold, color: accent, mono: true, lines: 1))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(countLabel)
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 8, right: 12)

        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 34
        table.dataSource = self
        table.register(LabLogCell.self, forCellReuseIdentifier: LabLogCell.reuseID)
        table.showsVerticalScrollIndicator = false
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        table.snp.makeConstraints { make in make.height.equalTo(height) }

        let stack = labStack(spacing: 0)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(table)
        card.add(stack)
        addSubview(card)
        card.snp.makeConstraints { make in make.edges.equalToSuperview() }

        cancellable = store.$entries
            .receive(on: RunLoop.main)
            .sink { [weak self] entries in
                guard let self else { return }
                countLabel.text = "\(entries.count) LINES"
                table.reloadData()
                // `entries` is the value captured by this publisher callback. The
                // store can already be empty by the time the callback runs (for
                // example `reset()` clears the console immediately after a log),
                // so never derive the scroll index from the captured array.
                // Ask the table for its current row count instead.
                //
                // `reloadData()` can be deferred when the sink fires while the
                // table is mid-layout/update: `numberOfRows(inSection:)` then
                // reports the data-source count while the table's *presented*
                // state still has 0 rows, and `scrollToRow` throws NSRange.
                // `layoutIfNeeded()` flushes the deferred reload first.
                table.layoutIfNeeded()
                let rows = table.numberOfRows(inSection: 0)
                guard rows > 0, table.window != nil else { return }
                table.scrollToRow(at: IndexPath(row: rows - 1, section: 0), at: .bottom, animated: false)
            }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LabLogCell.reuseID, for: indexPath) as! LabLogCell
        cell.configure(store.entries[indexPath.row])
        return cell
    }
}

private final class LabLogCell: UITableViewCell {
    static let reuseID = "LabLogCell"
    private let time = labLabel(size: 9.5, color: LabUI.textTertiary, mono: true, lines: 1)
    private let level = labLabel(size: 9, weight: .bold, mono: true, lines: 1)
    private let message = labLabel(size: 10.5, color: LabUI.textSecondary, mono: true)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        let row = labStack(axis: .horizontal, spacing: 8, alignment: .top)
        time.setContentHuggingPriority(.required, for: .horizontal)
        level.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(time)
        row.addArrangedSubview(level)
        row.addArrangedSubview(message)
        contentView.addSubview(row)
        row.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.bottom.equalToSuperview().inset(3)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ entry: LogEntry) {
        time.text = entry.formattedTime
        level.text = entry.level.rawValue
        level.textColor = entry.level.uiColor
        message.text = entry.message
    }
}

// MARK: - Hitch readout

final class LabHitchReadoutView: UIView {
    private let worst = LabMetricTileView(label: "Worst hitch", value: "—", unit: "ms", detail: "主线程帧间隔", color: LabUI.coral)
    private let count = LabMetricTileView(label: "Hitches", value: "0", unit: "次", detail: "> 34ms", color: LabUI.amber)
    private let dropped = LabMetricTileView(label: "Dropped", value: "0", unit: "frames", detail: "估算值", color: LabUI.cyan)
    private let last = LabMetricTileView(label: "Last gap", value: "—", unit: "ms", detail: "最近一次", color: LabUI.mint)
    private var cancellable: AnyCancellable?
    private let monitor: HitchMonitor

    init(monitor: HitchMonitor) {
        self.monitor = monitor
        super.init(frame: .zero)
        let card = LabCardView(accent: LabUI.coral)
        card.contentStack.addArrangedSubview(LabSectionHeaderView(
            kicker: "CADISPLAYLINK",
            title: "实时帧间隔",
            trailing: "LIVE",
            accent: LabUI.coral
        ))
        card.contentStack.addArrangedSubview(labMetricRow([worst, count, dropped, last]))
        card.contentStack.addArrangedSubview(labLabel(
            "阈值 34ms；Dropped 为 16.67ms 帧预算的估算值，不是 Instruments 精确计数。",
            size: 9.5,
            color: LabUI.textTertiary,
            mono: true
        ))
        addSubview(card)
        card.snp.makeConstraints { make in make.edges.equalToSuperview() }

        let publisher = Publishers.CombineLatest4(
            monitor.$worstHitchMs,
            monitor.$hitchCount,
            monitor.$estimatedDroppedFrames,
            monitor.$lastGapMs
        )
        cancellable = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                let (worstMs, hitchCount, droppedFrames, lastGap) = value
                worst.update(value: String(format: "%.0f", worstMs))
                count.update(value: "\(hitchCount)")
                dropped.update(value: "\(droppedFrames)")
                last.update(value: String(format: "%.0f", lastGap))
            }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { cancellable?.cancel() }
}

// MARK: - Scenario card

final class LabScenarioCard: UIButton {
    private let chevron = UIImageView(image: UIImage(systemName: "arrow.up.right"))
    private let accent: UIColor

    init(
        index: String,
        title: String,
        subtitle: String,
        tags: [String],
        expectation: String,
        accent: UIColor,
        identifier: String
    ) {
        self.accent = accent
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityIdentifier = identifier
        accessibilityTraits = .button
        accessibilityLabel = "\(index) \(title)"
        accessibilityHint = subtitle
        backgroundColor = LabUI.surface.withAlphaComponent(0.9)
        layer.cornerRadius = LabUI.cardRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = accent.withAlphaComponent(0.22).cgColor

        let header = labStack(axis: .horizontal, spacing: 10, alignment: .top)
        let indexLabel = labLabel(index, size: 11, weight: .bold, color: accent, mono: true, lines: 1)
        indexLabel.textAlignment = .center
        indexLabel.backgroundColor = accent.withAlphaComponent(0.11)
        indexLabel.layer.cornerRadius = 7
        indexLabel.layer.masksToBounds = true
        indexLabel.snp.makeConstraints { make in make.width.equalTo(38); make.height.equalTo(26) }

        let text = labStack(spacing: 5)
        text.addArrangedSubview(labLabel(title, size: 16.5, weight: .semibold, color: LabUI.textPrimary, rounded: true))
        text.addArrangedSubview(labLabel(subtitle, size: 12, color: LabUI.textSecondary))
        header.addArrangedSubview(indexLabel)
        header.addArrangedSubview(text)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        chevron.tintColor = accent
        chevron.contentMode = .scaleAspectFit
        chevron.snp.makeConstraints { make in make.width.height.equalTo(16) }
        header.addArrangedSubview(chevron)

        let stack = labStack(spacing: 11)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(labTagRow(tags, color: accent))
        stack.addArrangedSubview(labLabel("EXPECT  \(expectation)", size: 10, color: LabUI.textTertiary, mono: true))
        addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(15) }

        // 用透明按钮承接点击/无障碍焦点，确保 UIControl 子类在 XCUITest 中稳定暴露为 Button。
        let hit = UIButton(type: .custom)
        hit.backgroundColor = .clear
        hit.isAccessibilityElement = false
        hit.addTarget(self, action: #selector(forwardTap), for: .touchUpInside)
        addSubview(hit)
        hit.snp.makeConstraints { make in make.edges.equalToSuperview() }

        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func forwardTap() { sendActions(for: .touchUpInside) }

    @objc private func touchDown() { alpha = 0.7 }
    @objc private func touchUp() { alpha = 1 }
}
