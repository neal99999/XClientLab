import SnapshotTesting
import UIKit
import XCTest
@testable import XClientLab

/// 公共 UIKit 组件快照：锁住暗色主题、字号、圆角和间距。
/// 首次录制后 `record` 必须保持 false，否则 CI 会失去回归意义。
@MainActor
final class ComponentSnapshotTests: XCTestCase {
    private let record = false
    private let size = CGSize(width: 360, height: 220)

    private var config: ViewImageConfig {
        ViewImageConfig(
            safeArea: .zero,
            size: size,
            traits: UITraitCollection(userInterfaceStyle: .dark)
        )
    }

    func testModuleHeaderSnapshot() {
        let header = LabModuleHeaderView(module: .performance)
        assertSnapshot(
            of: host(header, height: 188),
            as: .image(on: config),
            named: "module-header",
            record: record
        )
    }

    func testLabCardSnapshot() {
        let card = LabCardView(accent: LabUI.cyan)
        card.add(LabSectionHeaderView(kicker: "SNAPSHOT", title: "基础组件", trailing: "LOCKED", accent: LabUI.cyan))
        card.add(labLabel(
            "统一 Card / 字号 / 间距，组件改动必须显式更新基线。",
            size: 13,
            color: LabUI.textSecondary
        ))
        card.add(labTagRow(["SNAP", "UIKIT", "SNAPKit"], color: LabUI.cyan))

        assertSnapshot(
            of: host(card, height: 158),
            as: .image(on: config),
            named: "lab-card",
            record: record
        )
    }

    func testMetricRowSnapshot() {
        let row = labStack(axis: .horizontal, spacing: 8, distribution: .fillEqually)
        row.addArrangedSubview(LabMetricTileView(label: "TARGET", value: "500", unit: "ms", detail: "停顿阈值", color: LabUI.coral))
        row.addArrangedSubview(LabMetricTileView(label: "FRAME", value: "16.7", unit: "ms", detail: "60Hz 预算", color: LabUI.cyan))
        row.addArrangedSubview(LabMetricTileView(label: "DRILLS", value: "02", unit: "个", detail: "CPU / 内存", color: LabUI.mint))

        assertSnapshot(
            of: host(row, height: 94),
            as: .image(on: config),
            named: "metric-row",
            record: record
        )
    }

    func testCalloutSnapshot() {
        let callout = LabCalloutView(
            kind: .ai,
            message: "先 process status，再 interrupt；禁止在 running 状态下直接发 bt all。"
        )
        assertSnapshot(
            of: host(callout, height: 106),
            as: .image(on: config),
            named: "callout-ai",
            record: record
        )
    }

    private func host(_ view: UIView, height: CGFloat) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = LabUI.backgroundTop
        controller.view.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -16),
            view.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 16),
            view.heightAnchor.constraint(equalToConstant: height)
        ])
        return controller
    }
}
