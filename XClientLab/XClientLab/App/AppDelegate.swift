import UIKit

/// 传统 UIKit 生命周期入口。
///
/// 刻意不使用 SwiftUI `App` / `Scene`，也不使用 `UIHostingController`：
/// 面试演示时可以直接在 Xcode Debug View Hierarchy 里看到真实的 UIView 树。
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LabUI.applyAppearance()
        AppComposition.bootstrap()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
