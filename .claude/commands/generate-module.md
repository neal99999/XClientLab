---
description: 按 Clean Architecture 分层一键生成 View / ViewModel / Coordinator / UseCase 四个 Swift 模板文件，遵循 IBIT 的 MC 前缀、MCBaseViewController、SnapKit、主题与国际化约定
argument-hint: <模块名> [FeatureArea] [业务说明]
disable-model-invocation: true
---
先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径）并遵守共用规则。

# 输入解析
`$ARGUMENTS` 格式：`<模块名> [FeatureArea] [业务说明]`

- 模块名必填，转成 PascalCase 英文；中文模块名先翻译（如「订单详情」→ `OrderDetail`）。
- `FeatureArea` 可选，默认 `Feature<模块名>`；必须位于 `MCIBIT/MCIBIT/Modules/` 下且以 `Feature` 开头。
- 业务说明可选，用于补充页面标题、首屏数据与 TODO 内容。

缺少模块名时只问一句「模块名和归属 FeatureArea？」然后停止，不要生成任何文件。

# 生成位置
`<仓库根>/MCIBIT/MCIBIT/Modules/<FeatureArea>/<ModuleName>/`，恰好 4 个文件：

| 文件 | 职责 |
| --- | --- |
| `MC<ModuleName>Controller.swift` | View 层：继承 `MCBaseViewController`，只做 UI 与绑定 |
| `MC<ModuleName>ViewModel.swift` | 状态与交互编排：Input/Output、RxSwift 流、持有 UseCase |
| `MC<ModuleName>Coordinator.swift` | 导航：创建 VM + VC 并 push，跨模块跳转留 TODO 走 `URLRouter` |
| `MC<ModuleName>UseCase.swift` | 业务用例：protocol + 默认实现，不 import UIKit |

目录已存在就复用；任一目标文件已存在则停止并报告，**绝不覆盖**。

# 硬性约定
- 类名 `MC` 前缀；Controller 用 `Controller` 后缀（项目里不用 `VC`）；无继承需求的类型加 `final`。
- View 继承 `MCBaseViewController`；标题 `viewNavi.centerTitle = "<key>".localized()`。
- UI 用 SnapKit + `MCFIT()`；颜色用 `theme_*` + `CommonFunc.themeColorPicker(light:dark:)`，不写死色值。
- 文案一律 `.localized()`；金额/数量用 String 大数扩展，禁止 `Double` 参与资金计算。
- RxSwift / SnapKit / Moya 由 `CommonConstant.swift` 的 `@_exported` 全局引入，**不要重复 import**；ViewModel 与 UseCase 只 `import Foundation`，View/Coordinator 只 `import UIKit`。
- 真实接口、埋点、错误码处理留 `// TODO:`，不要编造 API；模板必须能通过语法检查。
- 不生成 XIB / Storyboard，不使用 `as any` 式强转。

# 模板
## MC<Name>Controller.swift
```swift
import UIKit

final class MC<Name>Controller: MCBaseViewController {

    private let viewModel: MC<Name>ViewModel
    private let disposeBag = DisposeBag()

    init(viewModel: MC<Name>ViewModel = MC<Name>ViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewNavi.centerTitle = "<title_key>".localized()
        setupUI()
        bindViewModel()
        viewModel.input.viewDidLoad.accept(())
    }

    private func setupUI() {
        view.theme_backgroundColor = CommonFunc.themeColorPicker(light: .c_FFFFFF, dark: .c_0E0E0E)
        view.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(MCFIT(24))
            make.trailing.lessThanOrEqualToSuperview().offset(-MCFIT(24))
        }
    }

    private func bindViewModel() {
        viewModel.output.title
            .bind(to: contentLabel.rx.text)
            .disposed(by: disposeBag)
    }

    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: MCFIT(16))
        label.theme_textColor = CommonFunc.themeColorPicker(light: .c_000000, dark: .c_FFFFFF)
        label.numberOfLines = 0
        return label
    }()
}
```

## MC<Name>ViewModel.swift
```swift
import Foundation

final class MC<Name>ViewModel {

    struct Input {
        let viewDidLoad = PublishRelay<Void>()
        let retry = PublishRelay<Void>()
    }

    struct Output {
        let title = BehaviorRelay<String>(value: "<title_key>".localized())
        let isLoading = BehaviorRelay<Bool>(value: false)
        let errorMessage = PublishRelay<String>()
    }

    let input = Input()
    let output = Output()

    private let useCase: MC<Name>UseCaseProtocol
    private let disposeBag = DisposeBag()

    init(useCase: MC<Name>UseCaseProtocol = MC<Name>UseCase()) {
        self.useCase = useCase
        bind()
    }

    private func bind() {
        let trigger = Observable.merge(input.viewDidLoad.asObservable(), input.retry.asObservable())

        trigger
            .do(onNext: { [weak self] _ in self?.output.isLoading.accept(true) })
            .flatMapLatest { [weak self] _ -> Observable<Result<Void, Error>> in
                guard let self else { return .empty() }
                return self.useCase.load().asObservable().catch { error in
                    Observable.just(.failure(error))
                }
            }
            .do(onNext: { [weak self] _ in self?.output.isLoading.accept(false) })
            .subscribe(onNext: { [weak self] result in
                switch result {
                case .success:
                    // TODO: 把用例结果映射到 output
                    break
                case .failure(let error):
                    self?.output.errorMessage.accept(error.localizedDescription)
                }
            })
            .disposed(by: disposeBag)
    }
}
```

## MC<Name>UseCase.swift
```swift
import Foundation

protocol MC<Name>UseCaseProtocol {
    /// TODO: 替换为真实返回模型，例如 Single<MC<Name>Model>
    func load() -> Single<Result<Void, Error>>
}

final class MC<Name>UseCase: MC<Name>UseCaseProtocol {

    // TODO: 注入仓储 / 网络 Provider，例如 private let provider: MC<Name>APIProvider
    init() {}

    func load() -> Single<Result<Void, Error>> {
        // TODO: 调用真实接口并转换为领域模型
        .just(.success(()))
    }
}
```

## MC<Name>Coordinator.swift
```swift
import UIKit

final class MC<Name>Coordinator {

    private weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController?) {
        self.navigationController = navigationController
    }

    func start() {
        let viewModel = MC<Name>ViewModel()
        let controller = MC<Name>Controller(viewModel: viewModel)
        navigationController?.pushViewController(controller, animated: true)
    }

    // TODO: 跨模块跳转优先走统一路由（URLRouter / RouteManager），不要在这里直接 new 其他模块的 VC
}
```

# 执行步骤
1. 用 `git rev-parse --show-toplevel` 定位仓库根，确认 `MCIBIT/MCIBIT/Modules/<FeatureArea>/` 存在；不存在则先问用户是否新建 FeatureArea。
2. 创建 `<FeatureArea>/<ModuleName>/` 目录，按模板替换 `<Name>` / `<title_key>` / `<ModuleName>` 后写入 4 个文件。
3. 语法自检：`xcrun swiftc -parse <4 个文件路径>`；解析失败就修正后重跑，最多 2 轮。
4. 输出交付说明：文件树、每个文件一句话职责、遗留 TODO 列表、下一步命令。

# 必须提醒用户
- 本工程没有启用文件夹同步（`project.pbxproj` 里没有 `PBXFileSystemSynchronizedRootGroup`），新文件必须手动加入 `MCIBIT` target（Xcode 里 Add Files to "MCIBIT"，或用 xcodeproj 脚本），否则不参与编译。
- 模板只保证结构与语法，业务字段/接口需要后续补全。
- 不要顺手改 `project.pbxproj` 之外的工程配置，也不要提交未经确认的改动。
