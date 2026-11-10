import UIKit

/// 启动页：承接系统 LaunchScreen（同一张 logo、同一个深色底），
/// 把「冷启动首帧」和「进入主界面」之间的空白补成一段有节奏的品牌动画。
///
/// 设计原则：
/// - 背景色与 `LaunchBackground` / `LabUI.backgroundTop` 完全一致，系统截屏不会闪白；
/// - logo 在系统启动页里是居中静态图，这里保持同一位置只做极小的缩放，避免位置跳变；
/// - 动画总时长 < 1s，测试或「减弱动态效果」时直接跳过，不阻塞 UI 测试。
final class LaunchViewController: UIViewController {
    private let onFinish: () -> Void
    private var hasFinished = false

    private let gradientLayer = CAGradientLayer()
    private let logoView = UIImageView(image: UIImage(named: "LaunchLogo"))
    private lazy var wordmark: UILabel = {
        let label = UILabel()
        label.text = "XClientLab"
        label.font = LabUI.font(32, weight: .bold, rounded: true)
        label.textColor = LabUI.textPrimary
        label.accessibilityIdentifier = "launch.wordmark"
        return label
    }()

    private lazy var tagline: UILabel = {
        let label = UILabel()
        label.text = "iOS ENGINEERING LAB · INTERVIEW SANDBOX"
        label.font = LabUI.font(9.5, weight: .semibold, mono: true)
        label.textColor = LabUI.textTertiary
        label.attributedText = NSAttributedString(
            string: label.text ?? "",
            attributes: [
                .kern: 1.9,
                .font: LabUI.font(9.5, weight: .semibold, mono: true),
                .foregroundColor: LabUI.textTertiary
            ]
        )
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = LabUI.font(9.5, weight: .medium, mono: true)
        label.textColor = LabUI.textTertiary
        label.text = "BOOTSTRAPPING CONTAINER"
        label.accessibilityIdentifier = "launch.status"
        return label
    }()

    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressWidth: NSLayoutConstraint?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LabUI.backgroundTop
        setUpBackground()
        setUpContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldSkipAnimation {
            finish()
        } else {
            runIntro()
        }
    }

    // MARK: - Layout

    private func setUpBackground() {
        gradientLayer.colors = [LabUI.backgroundTop.cgColor, LabUI.backgroundBottom.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.15)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setUpContent() {
        logoView.contentMode = .scaleAspectFit
        logoView.layer.shadowColor = LabUI.cyan.cgColor
        logoView.layer.shadowOpacity = 0.35
        logoView.layer.shadowRadius = 28
        logoView.layer.shadowOffset = .zero
        logoView.accessibilityIdentifier = "launch.logo"
        logoView.translatesAutoresizingMaskIntoConstraints = false

        wordmark.translatesAutoresizingMaskIntoConstraints = false
        tagline.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        progressTrack.layer.cornerRadius = 1
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = LabUI.cyan
        progressFill.layer.cornerRadius = 1
        progressFill.translatesAutoresizingMaskIntoConstraints = false

        [logoView, wordmark, tagline, progressTrack, progressFill, statusLabel].forEach(view.addSubview)

        let progressWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        self.progressWidth = progressWidth

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 120),
            logoView.heightAnchor.constraint(equalToConstant: 120),

            wordmark.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 24),
            wordmark.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            tagline.topAnchor.constraint(equalTo: wordmark.bottomAnchor, constant: 9),
            tagline.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -38),

            progressTrack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressTrack.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -14),
            progressTrack.widthAnchor.constraint(equalToConstant: 168),
            progressTrack.heightAnchor.constraint(equalToConstant: 2),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.centerYAnchor.constraint(equalTo: progressTrack.centerYAnchor),
            progressFill.heightAnchor.constraint(equalToConstant: 2),
            progressWidth
        ])
    }

    // MARK: - Animation

    /// 启动动画开关：UI 测试、减弱动态效果或显式传 `-skipLaunchAnimation` 时直接跳过。
    /// 跳过只影响动画时长，不影响启动页本身（首帧仍是同一张静态图）。
    static var isAnimationEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("-skipLaunchAnimation") {
            return false
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        return !UIAccessibility.isReduceMotionEnabled
    }

    private var shouldSkipAnimation: Bool {
        !Self.isAnimationEnabled
    }

    private func runIntro() {
        logoView.alpha = 0
        logoView.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        wordmark.alpha = 0
        tagline.alpha = 0
        wordmark.transform = CGAffineTransform(translationX: 0, y: 8)
        tagline.transform = CGAffineTransform(translationX: 0, y: 8)

        UIView.animate(
            withDuration: 0.62,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.6,
            options: [.curveEaseOut]
        ) {
            self.logoView.alpha = 1
            self.logoView.transform = .identity
        }

        UIView.animate(withDuration: 0.45, delay: 0.1, options: [.curveEaseOut]) {
            self.wordmark.alpha = 1
            self.wordmark.transform = .identity
            self.tagline.alpha = 1
            self.tagline.transform = .identity
        }

        progressWidth?.constant = 168
        UIView.animate(withDuration: 0.82, delay: 0.08, options: [.curveLinear]) {
            self.view.layoutIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            let count = AppComposition.container.registeredServices.count
            self.statusLabel.text = "CONTAINER READY · \(count) SERVICES"
            self.statusLabel.textColor = LabUI.mint
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}
