import SnapKit
import UIKit

extension DeliveryGuardViewController {
    func makeBadge(label: UILabel) -> UIView {
        let box = UIView()
        box.backgroundColor = LabUI.mint.withAlphaComponent(0.12)
        box.layer.cornerRadius = 8
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = LabUI.mint.withAlphaComponent(0.30).cgColor
        box.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
        return box
    }
}
