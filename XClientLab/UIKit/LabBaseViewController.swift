import SnapKit
import UIKit

/// 所有实验页的 UIKit 基类：一块深空画布 + 一个垂直 UIStackView。
///
/// 这里不搞复杂布局框架：页面就是「纵向卡片流」，用 SnapKit 固定画布与
/// scrollView，contentStack 只负责宽度和内容高度。约束树非常浅，Debug
/// View Hierarchy 里一眼能看懂。
class LabBaseViewController: UIViewController {
    let accent: UIColor
    let scrollView = UIScrollView()
    let contentStack = labStack(spacing: LabUI.sectionSpacing)
    private lazy var canvas = LabCanvasView(accent: accent)

    init(accent: UIColor) {
        self.accent = accent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LabUI.backgroundTop
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(canvas)
        canvas.snp.makeConstraints { make in make.edges.equalToSuperview() }

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
        // iOS 26 的 floating tab bar 会覆盖内容底部，额外留出可滚动余量。
        scrollView.contentInset.bottom = 76
        scrollView.verticalScrollIndicatorInsets.bottom = 76
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(scrollView.contentLayoutGuide).offset(10)
            make.bottom.equalTo(scrollView.contentLayoutGuide).offset(-40)
            make.leading.equalTo(scrollView.frameLayoutGuide).offset(LabUI.pageInset)
            make.trailing.equalTo(scrollView.frameLayoutGuide).offset(-LabUI.pageInset)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    @discardableResult
    func add(_ view: UIView) -> UIView {
        contentStack.addArrangedSubview(view)
        return view
    }

    func addSpacer(_ height: CGFloat = 4) {
        let spacer = UIView()
        spacer.snp.makeConstraints { make in make.height.equalTo(height) }
        contentStack.addArrangedSubview(spacer)
    }

    func push(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
}
