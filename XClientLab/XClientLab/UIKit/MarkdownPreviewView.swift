import SnapKit
import UIKit

/// 轻量 Markdown 预览：只支持 Skill 文档实际用到的六种 block。
///
/// 不引入 Markdown 库是刻意的：面试演示时可以把「解析 → block → UIView」
/// 这条链路直接讲清楚，也避免为了一个预览页增加依赖。
final class MarkdownPreviewView: UIView {
    init(markdown: String, accent: UIColor = LabUI.cyan) {
        super.init(frame: .zero)
        let stack = labStack(spacing: 11)
        addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview() }

        for block in MarkdownLiteParser.parse(markdown) {
            switch block {
            case let .heading(level, text):
                let size: CGFloat = level == 1 ? 20 : (level == 2 ? 16 : 13.5)
                stack.addArrangedSubview(labLabel(
                    text,
                    size: size,
                    weight: .bold,
                    color: LabUI.textPrimary,
                    rounded: true,
                    lines: 0
                ))
            case let .paragraph(text):
                let label = labLabel(text, size: 12, color: LabUI.textSecondary, lines: 0)
                label.attributedText = Self.attributed(text, color: LabUI.textSecondary)
                stack.addArrangedSubview(label)
            case let .bullet(text):
                let row = labStack(axis: .horizontal, spacing: 7, alignment: .top)
                row.addArrangedSubview(labLabel("•", size: 12, weight: .bold, color: accent, lines: 1))
                let label = labLabel(text, size: 12, color: LabUI.textSecondary, lines: 0)
                label.attributedText = Self.attributed(text, color: LabUI.textSecondary)
                row.addArrangedSubview(label)
                stack.addArrangedSubview(row)
            case let .quote(text):
                let quote = labLabel(text, size: 11.5, color: LabUI.textTertiary, lines: 0)
                quote.backgroundColor = accent.withAlphaComponent(0.06)
                quote.layer.cornerRadius = 8
                quote.layer.masksToBounds = true
                quote.textAlignment = .left
                stack.addArrangedSubview(quote)
            case let .code(code):
                stack.addArrangedSubview(LabCodeBlockView(code: code, accent: accent))
            case .divider:
                let line = UIView()
                line.backgroundColor = LabUI.hairline
                line.snp.makeConstraints { make in make.height.equalTo(1) }
                stack.addArrangedSubview(line)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func attributed(_ text: String, color: UIColor) -> NSAttributedString {
        guard let parsed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return NSAttributedString(string: text, attributes: [.foregroundColor: color])
        }
        var result = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
        result.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: result.length))
        return result
    }
}
