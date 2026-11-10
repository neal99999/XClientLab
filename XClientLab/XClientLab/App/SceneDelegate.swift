import UIKit

/// UIKit 的 scene 生命周期入口。
///
/// iOS 26/27 SDK 构建的 App 必须采用 UIScene 生命周期；窗口在这里创建，
/// AppDelegate 只负责全局配置与组装根启动。
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.backgroundColor = LabUI.backgroundTop
        // 先展示启动页；RootTabBarController 同时建好，切换时零白屏。
        let root = RootTabBarController()
        let launch = LaunchViewController { [weak window] in
            guard let window else { return }
            UIView.transition(with: window, duration: 0.42, options: [.transitionCrossDissolve]) {
                window.rootViewController = root
            }
        }
        window.rootViewController = launch
        window.makeKeyAndVisible()
        self.window = window
    }
}
