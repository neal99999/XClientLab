import LabContracts
import LabFeatureKit
import SnapKit
import UIKit

/// Scenario 5.2 — Bundle.module / 资源隔离 / Provider 替换。
///
/// 古法排查痛点：资源塞进主 App，模块之间靠文件名约定；想验证「换一个数据源
/// 业务是否无感」只能改代码重启。
///
/// AI MCP 新实践切入点：把 Provider 切换做成运行时可操作项；Agent 只需看
/// 加载结果和资源来源，就能验证协议边界是否真的成立。
final class ProfileFeatureLabViewController: LabBaseViewController {
    private enum Mode: Int {
        case bundled
        case mock
    }

    private let container = AppComposition.container
    private let modeControl = LabUIKit.segmented(items: ["BUNDLED", "MOCK"], accent: LabUI.amber)
    private let loadButton = LabButton(title: "LOAD PROFILE", style: .primary, accent: LabUI.amber, systemImage: "person.crop.circle")
    private let chainButton = LabButton(title: "TRACE CHAIN", style: .secondary, accent: LabUI.cyan)
    private let profileCard = LabCardView(accent: LabUI.amber)
    private let chainCard = LabCardView(accent: LabUI.cyan)
    private let chainStack = labStack(spacing: 5)
    private let statusLabel = labLabel("Bundled provider · 资源来自 LabFeatureKit 的 Bundle.module", size: 10.5, color: LabUI.textSecondary, mono: true, lines: 0)
    private let resourceLabel = labLabel("—", size: 10, color: LabUI.textTertiary, mono: true, lines: 0)

    private var mode: Mode {
        Mode(rawValue: modeControl.selectedSegmentIndex) ?? .bundled
    }

    init() {
        super.init(accent: LabUI.amber)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "5.2 资源与替换"
        buildUI()
        loadProfile()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 5.2  /  BUNDLE.MODULE",
            title: "资源隔离与实现替换",
            subtitle: "同一个 UserProviding 协议：Bundled 从模块资源解码，Mock 全内存返回。切换实现，调用方一行不改。",
            accent: LabUI.amber
        ))

        let controlCard = LabCardView(accent: LabUI.amber)
        controlCard.add(labLabel("PROVIDER MODE", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        controlCard.add(modeControl)
        controlCard.add(LabUIKit.actionRow([loadButton, chainButton]))
        controlCard.add(statusLabel)
        add(controlCard)

        profileCard.add(labLabel("PROFILE", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        profileCard.add(labLabel("点击 LOAD PROFILE 读取用户档案", size: 11.5, color: LabUI.textTertiary, lines: 0))
        add(profileCard)

        chainCard.add(labLabel("CALL CHAIN", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        chainCard.add(chainStack)
        chainCard.add(chainButton)
        add(chainCard)

        let resourceCard = LabCardView(accent: LabUI.mint)
        resourceCard.add(labLabel("RESOURCE PROVENANCE", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        resourceCard.add(resourceLabel)
        add(resourceCard)

        add(LabCalloutView(
            kind: .problem,
            message: "资源与实现都焊在主 App：模块无法独立预览，换 Mock 要改调用方，资源重名/漏打包只能等运行时炸。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "Bundle.module + 协议 Provider：资源来源、当前实现、加载结果都能在 UI 上验证；MCP Agent 读的是可观测状态，不是源码猜测。"
        ))
        add(LabCalloutView(
            kind: .insight,
            message: "面试讲解顺序：先切 MOCK 看调用方无感，再指 resource provenance 证明资源来自模块 bundle，最后用 TRACE CHAIN 串起目录服务。"
        ))

        modeControl.accessibilityIdentifier = "arch.profile.mode"
        loadButton.accessibilityIdentifier = "arch.profile.decode"
        chainButton.accessibilityIdentifier = "arch.profile.chain"
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        loadButton.addTarget(self, action: #selector(loadTapped), for: .touchUpInside)
        chainButton.addTarget(self, action: #selector(chainTapped), for: .touchUpInside)

        resourceLabel.text = """
        bundle = \(FeatureResources.bundleName)
        file   = demo-profiles.json
        color  = FeatureAccent (asset catalog)
        source = Bundle.module
        """
    }

    private func loadProfile() {
        renderLoading()
        statusLabel.text = mode == .bundled
            ? "Bundled provider · Bundle.module/demo-profiles.json → JSONDecoder"
            : "Mock provider · 内存返回，带 250ms 模拟延迟"
        statusLabel.textColor = LabUI.textSecondary

        Task { @MainActor [weak self] in
            guard let self else { return }
            configureProvider(for: mode)
            let service = container.resolve(UserDirectoryService.self)
            do {
                let profile = try await service.openProfile(userID: mode == .bundled ? "u-001" : "u-mock")
                render(profile: profile)
            } catch {
                render(error: error.localizedDescription)
            }
        }
    }

    private func configureProvider(for mode: Mode) {
        switch mode {
        case .bundled:
            FeatureKitModule().registerServices(in: container)
        case .mock:
            container.register((any UserProviding).self, as: "UserProviding · Mock") {
                MockUserProvider(latencyNanoseconds: 250_000_000)
            }
            container.register(UserDirectoryService.self, as: "UserDirectoryService · Mock") { [container] in
                let provider = container.resolve((any UserProviding).self)
                let analytics = container.resolve((any AnalyticsTracking).self)
                return UserDirectoryService(provider: provider, analytics: analytics)
            }
        }
    }

    private func renderLoading() {
        profileCard.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        profileCard.add(labLabel("PROFILE", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        profileCard.add(labLabel("LOADING · 等待 provider 返回…", size: 11.5, color: LabUI.textSecondary, mono: true, lines: 0))
    }

    private func render(profile: UserProfile) {
        profileCard.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        profileCard.accessibilityIdentifier = "featurekit.profile.card"

        let header = labStack(axis: .horizontal, spacing: 11, alignment: .center)
        let avatar = labLabel(profile.initials, size: 17, weight: .bold, color: LabUI.amber, rounded: true, lines: 1)
        avatar.textAlignment = .center
        avatar.backgroundColor = LabUI.amber.withAlphaComponent(0.14)
        avatar.layer.cornerRadius = 22
        avatar.layer.borderWidth = 1
        avatar.layer.borderColor = LabUI.amber.withAlphaComponent(0.35).cgColor
        avatar.snp.makeConstraints { make in make.size.equalTo(44) }
        header.addArrangedSubview(avatar)

        let titles = labStack(spacing: 2)
        titles.addArrangedSubview(labLabel(profile.displayName, size: 17, weight: .semibold, color: LabUI.textPrimary, rounded: true, lines: 1))
        titles.addArrangedSubview(labLabel(profile.role, size: 10.5, color: LabUI.textSecondary, lines: 0))
        header.addArrangedSubview(titles)
        profileCard.add(header)
        profileCard.add(labLabel(profile.email, size: 10.5, color: LabUI.amber, mono: true, lines: 1))
        let badge = labLabel(
            mode == .bundled ? "RESOURCE · Bundle.module" : "RESOURCE · In-Memory Mock",
            size: 9,
            weight: .bold,
            color: mode == .bundled ? LabUI.mint : LabUI.violet,
            mono: true,
            lines: 1
        )
        profileCard.add(badge)
        profileCard.add(labLabel("id = \(profile.id)", size: 9.5, color: LabUI.textTertiary, mono: true, lines: 1))
    }

    private func render(error: String) {
        profileCard.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        profileCard.add(labLabel("PROFILE / ERROR", size: 9.5, weight: .bold, color: LabUI.coral, mono: true, lines: 1))
        profileCard.add(labLabel(error, size: 11.5, color: LabUI.coral, lines: 0))
        statusLabel.text = "FAILED · \(error)"
        statusLabel.textColor = LabUI.coral
    }

    private func renderChain() {
        chainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let steps = [
            ("RootTabBarController", "用户操作入口", LabUI.amber),
            ("ProfileFeatureLabViewController", "只依赖 UserDirectoryService", LabUI.cyan),
            ("UserDirectoryService", "组合 UserProviding + AnalyticsTracking", LabUI.mint),
            (mode == .bundled ? "BundledUserProvider" : "MockUserProvider", mode == .bundled ? "Bundle.module JSON" : "内存返回", LabUI.violet),
            ("UserProfile", "零 UIKit 的 Codable DTO", LabUI.steel),
        ]
        for (index, step) in steps.enumerated() {
            let row = labStack(axis: .horizontal, spacing: 8, alignment: .center)
            row.addArrangedSubview(labLabel("0\(index + 1)", size: 9, weight: .bold, color: step.2, mono: true, lines: 1))
            let body = labStack(spacing: 1)
            body.addArrangedSubview(labLabel(step.0, size: 10.5, weight: .semibold, color: LabUI.textPrimary, mono: true, lines: 1))
            body.addArrangedSubview(labLabel(step.1, size: 9.5, color: LabUI.textTertiary, lines: 1))
            row.addArrangedSubview(body)
            chainStack.addArrangedSubview(row)
            if index < steps.count - 1 {
                chainStack.addArrangedSubview(labLabel("↓", size: 11, color: LabUI.textTertiary, mono: true, lines: 1))
            }
        }
    }

    @objc private func modeChanged() {
        loadProfile()
    }

    @objc private func loadTapped() {
        loadProfile()
    }

    @objc private func chainTapped() {
        renderChain()
    }
}
