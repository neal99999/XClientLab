import UIKit

/// 四个入口的 UIKit 根容器：交易所专项 → 实验室 → 交付与防线 → AI 工坊。
///
/// 第一屏不再铺“AI 对照”表格，而是直接进入面试主线：
/// 两个交易所案例的「现象 → 难点 → 动作 → 结果」。实验室只作为追问时的
/// 证据抽屉；交付与防线把 Figma 像素还原、代码审查与 Git Flow 做成证据链；
/// AI 工坊讲「五位一体」架构、Skills 与 MCP 通道纪律。
final class RootTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LabUI.backgroundTop
        tabBar.tintColor = LabUI.cyan
        tabBar.unselectedItemTintColor = UIColor(white: 0.55, alpha: 1)

        viewControllers = [
            makeNavigation(
                root: ExchangeStoryViewController(),
                title: "交易所专项",
                icon: "chart.line.uptrend.xyaxis",
                identifier: "tab.story",
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
                root: DeliveryGuardViewController(),
                title: "交付与防线",
                icon: "checkmark.shield.fill",
                identifier: "tab.delivery",
                tag: 2
            ),
            makeNavigation(
                root: SkillLibraryViewController(),
                title: "AI 工坊",
                icon: "sparkles",
                identifier: "tab.ai",
                tag: 3
            )
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
