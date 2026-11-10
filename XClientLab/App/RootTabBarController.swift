import UIKit

/// 五个实验入口的 UIKit 根容器。
///
/// 每个 tab 都是一个独立 `UINavigationController`，保证 push 层级互不污染；
/// accessibilityIdentifier 与 SwiftUI 版本保持一致，UI 测试无需重写。
final class RootTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LabUI.backgroundTop
        tabBar.tintColor = LabUI.cyan
        tabBar.unselectedItemTintColor = UIColor(white: 0.55, alpha: 1)

        viewControllers = [
            makeNavigation(
                root: PerformanceHomeViewController(),
                module: .performance,
                tag: 0
            ),
            makeNavigation(
                root: ExceptionsHomeViewController(),
                module: .exceptions,
                tag: 1
            ),
            makeNavigation(
                root: ExchangeHomeViewController(),
                module: .exchange,
                tag: 2
            ),
            makeNavigation(
                root: AINativeHomeViewController(),
                module: .aiNative,
                tag: 3
            ),
            makeNavigation(
                root: ArchitectureHomeViewController(),
                module: .architecture,
                tag: 4
            ),
        ]
        selectedIndex = 0
    }

    private func makeNavigation(
        root: UIViewController,
        module: LabModule,
        tag: Int
    ) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.prefersLargeTitles = true
        navigation.navigationBar.tintColor = LabUI.cyan
        navigation.tabBarItem = UITabBarItem(
            title: module.shortTitle,
            image: UIImage(systemName: module.icon),
            tag: tag
        )
        navigation.tabBarItem.accessibilityIdentifier = "tab.\(module.rawValue)"
        return navigation
    }
}
