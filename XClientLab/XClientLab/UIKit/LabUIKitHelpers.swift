import UIKit

enum LabUIKit {
    static func segmented(
        items: [String],
        accent: UIColor = LabUI.cyan,
        selected: Int = 0
    ) -> UISegmentedControl {
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = selected
        control.selectedSegmentTintColor = accent.withAlphaComponent(0.20)
        control.backgroundColor = LabUI.surfaceRaised
        control.setTitleTextAttributes([
            .foregroundColor: LabUI.textSecondary,
            .font: LabUI.font(11, weight: .medium),
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: accent,
            .font: LabUI.font(11, weight: .semibold),
        ], for: .selected)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return control
    }

    static func actionRow(_ buttons: [UIView], spacing: CGFloat = 8) -> UIStackView {
        let row = labStack(axis: .horizontal, spacing: spacing)
        row.distribution = .fillEqually
        buttons.forEach { row.addArrangedSubview($0) }
        return row
    }

    static func cardTitle(_ kicker: String, _ title: String, accent: UIColor, trailing: String? = nil) -> UIView {
        LabSectionHeaderView(kicker: kicker, title: title, trailing: trailing, accent: accent)
    }

    static func alert(
        on viewController: UIViewController,
        title: String,
        message: String,
        confirmTitle: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(
            title: confirmTitle,
            style: destructive ? .destructive : .default
        ) { _ in action() })
        viewController.present(alert, animated: true)
    }
}
