import UIKit

/// 三个入口的 UIKit 根容器：演示 → 实验室 → AI 工坊。
///
/// 不再把 5 个模块全部塞进 tab bar。演示页先给“古法 vs AI”的对照，
/// 实验室再按模块进入真实场景；AI 工坊单独承载 Skill / MCP / 命令桩。
final class RootTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LabUI.backgroundTop
        tabBar.tintColor = LabUI.cyan
        tabBar.unselectedItemTintColor = UIColor(white: 0.55, alpha: 1)

        viewControllers = [
            makeNavigation(
                root: DemoComparisonViewController(),
                title: "演示",
                icon: "play.rectangle.fill",
                identifier: "tab.demo",
                tag: 0
            ),
            makeNavigation(
                root: LabIndexViewController(),
                title: "实验室",
                icon: "square.grid.2x2.fill",
                identifier: "tab.lab",
                tag: 1
            ),
            makeNavigation(
                root: AINativeHomeViewController(),
                title: "AI 工坊",
                icon: "sparkles",
                identifier: "tab.ai",
                tag: 2
            ),
        ]
        selectedIndex = 0
    }

    private func makeNavigation(
        root: UIViewController,
        title: String,
        icon: String,
        identifier: String,
        tag: Int
    ) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.prefersLargeTitles = true
        navigation.navigationBar.tintColor = LabUI.cyan
        navigation.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: icon),
            tag: tag
        )
        navigation.tabBarItem.accessibilityIdentifier = identifier
        return navigation
    }
}
