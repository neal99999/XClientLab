import LabContracts
import LabFeatureKit
import SnapKit
import UIKit

/// Scenario 5.1 — 依赖图与组装根。
///
/// 古法排查痛点：依赖散落在 AppDelegate / 单例 / 全局变量里，想回答
/// 「这个服务到底谁创建、生命周期是什么」只能靠搜代码。
///
/// AI MCP 新实践切入点：把依赖图、容器注册表、单例/瞬态作用域做成可运行页面；
/// Agent 不需要读完整工程，也能验证组装根是否把正确的实现接进来。
final class ModuleGraphViewController: LabBaseViewController {
    private let servicesStack = labStack(spacing: 5)
    private let resultLabel = labLabel("点击 RESOLVE SCOPES，验证 singleton / transient 的实例身份。", size: 11, color: LabUI.textSecondary, lines: 0)
    private let thirdPartyStack = labStack(spacing: 5)

    init() {
        super.init(accent: LabUI.amber)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "5.1 依赖图"
        buildUI()
    }

    private func buildUI() {
        add(LabScreenTitleView(
            index: "SCENARIO 5.1  /  DEPENDENCY GRAPH",
            title: "依赖图与组装根",
            subtitle: "App 只认识协议；FeatureKit 负责注册；Contracts 零依赖。容器把工厂、作用域和替换点收口到一处。",
            accent: LabUI.amber
        ))

        let graph = LabCardView(accent: LabUI.amber)
        graph.add(labLabel("DEPENDENCY DAG", size: 9.5, weight: .bold, color: LabUI.amber, mono: true, lines: 1))
        graph.add(node("XClientLab · App", "组装根 / RootTabBarController / AppComposition", color: LabUI.amber))
        graph.add(arrow())
        graph.add(node("LabFeatureKit", "UI + 资源 + Bundled/Mock/Remote Provider", color: LabUI.mint))
        graph.add(arrow())
        graph.add(node("LabContracts", "0 依赖：协议 / DTO / ServiceContainer", color: LabUI.cyan))
        add(graph)

        let services = LabCardView(accent: LabUI.mint)
        services.add(labLabel("CONTAINER REGISTRY", size: 9.5, weight: .bold, color: LabUI.mint, mono: true, lines: 1))
        services.add(labLabel(
            "AppComposition.bootstrap() 按 FeatureModule 协议逐个注册，新增模块不用改组装分支。",
            size: 11.5,
            color: LabUI.textSecondary,
            lines: 0
        ))
        servicesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for name in AppComposition.container.registeredServices {
            let row = labStack(axis: .horizontal, spacing: 7, alignment: .center)
            row.addArrangedSubview(LabStatusDotView(color: LabUI.mint))
            row.addArrangedSubview(labLabel(name, size: 10.5, color: LabUI.textPrimary, mono: true, lines: 1))
            servicesStack.addArrangedSubview(row)
        }
        services.add(servicesStack)
        let resolve = LabButton(title: "RESOLVE SCOPES", style: .secondary, accent: LabUI.mint, systemImage: "arrow.triangle.branch")
        resolve.accessibilityIdentifier = "arch.graph.scope.run"
        resolve.addAction(UIAction { [weak self] _ in self?.runScopeProbe() }, for: .touchUpInside)
        services.add(resolve)
        services.add(resultLabel)
        add(services)

        let thirdParty = LabCardView(accent: LabUI.cyan)
        thirdParty.add(labLabel("THIRD-PARTY SELF CHECK", size: 9.5, weight: .bold, color: LabUI.cyan, mono: true, lines: 1))
        thirdParty.add(labLabel(
            "Alamofire / Kingfisher / Moya / SnapKit / Starscream 各做一次真实调用；全部离线可跑。",
            size: 11.5,
            color: LabUI.textSecondary,
            lines: 0
        ))
        thirdParty.add(thirdPartyStack)
        let run = LabButton(title: "RUN 5-LIB SELF CHECK", style: .secondary, accent: LabUI.cyan, systemImage: "shippingbox")
        run.accessibilityIdentifier = "arch.thirdparty.run"
        run.addAction(UIAction { [weak self] _ in self?.runThirdPartyCheck() }, for: .touchUpInside)
        thirdParty.add(run)
        add(thirdParty)

        add(LabCalloutView(
            kind: .problem,
            message: "依赖关系只存在于开发者脑子里：单例满天飞、初始化顺序隐式、替换实现要改调用方；排查时无法快速回答「谁创建了它」。"
        ))
        add(LabCalloutView(
            kind: .ai,
            message: "把组装根、协议映射、作用域做成可运行面板；MCP Agent 可以直接验证注册表与实例身份，而不是静态猜依赖。"
        ))
        add(LabCalloutView(
            kind: .insight,
            message: "面试讲解顺序：先指 DAG 说明单向依赖，再 resolve 两次证明 singleton，最后用 Mock 替换证明协议边界。"
        ))
    }

    private func node(_ title: String, _ detail: String, color: UIColor) -> UIView {
        let box = UIView()
        box.backgroundColor = color.withAlphaComponent(0.08)
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = color.withAlphaComponent(0.30).cgColor
        let stack = labStack(spacing: 3)
        stack.addArrangedSubview(labLabel(title, size: 13, weight: .semibold, color: color, rounded: true, lines: 1))
        stack.addArrangedSubview(labLabel(detail, size: 10, color: LabUI.textTertiary, mono: true, lines: 0))
        box.addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(10) }
        return box
    }

    private func arrow() -> UIView {
        let row = labStack(axis: .horizontal, spacing: 0, alignment: .center)
        let line = labLabel("↓", size: 14, weight: .bold, color: LabUI.amber, mono: true, lines: 1)
        line.textAlignment = .center
        row.addArrangedSubview(line)
        return row
    }

    private func runScopeProbe() {
        final class ProbeToken {}
        let singletonContainer = ServiceContainer()
        singletonContainer.register(ProbeToken.self, scope: .singleton) { ProbeToken() }
        let a = singletonContainer.resolve(ProbeToken.self)
        let b = singletonContainer.resolve(ProbeToken.self)

        let transientContainer = ServiceContainer()
        transientContainer.register(ProbeToken.self, scope: .transient) { ProbeToken() }
        let c = transientContainer.resolve(ProbeToken.self)
        let d = transientContainer.resolve(ProbeToken.self)

        let singletonSame = a === b
        let transientSame = c === d
        resultLabel.text = "singleton identical=\(singletonSame) · transient identical=\(transientSame)\n" +
            "同一个工厂 + 不同作用域，决定「复用实例」还是「每次新建」。"
        resultLabel.textColor = singletonSame && !transientSame ? LabUI.mint : LabUI.coral
    }

    private func runThirdPartyCheck() {
        thirdPartyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for check in ThirdPartyStack.runSelfCheck() {
            let row = labStack(axis: .horizontal, spacing: 7, alignment: .top)
            row.addArrangedSubview(labLabel(check.ok ? "✓" : "✕", size: 11, weight: .bold, color: check.ok ? LabUI.mint : LabUI.coral, mono: true, lines: 1))
            let body = labStack(spacing: 1)
            body.addArrangedSubview(labLabel(check.library, size: 10.5, weight: .semibold, color: LabUI.textPrimary, mono: true, lines: 1))
            body.addArrangedSubview(labLabel(check.detail, size: 9.5, color: LabUI.textTertiary, mono: true, lines: 0))
            row.addArrangedSubview(body)
            thirdPartyStack.addArrangedSubview(row)
        }
    }
}
