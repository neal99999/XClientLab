import UIKit

/// 传统 UIKit 生命周期入口。
///
/// 刻意不使用 SwiftUI `App` / `Scene`，也不使用 `UIHostingController`：
/// 面试演示时可以直接在 Xcode Debug View Hierarchy 里看到真实的 UIView 树。
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PerformanceDiagnostics.captureProcessStart()
        LabUI.applyAppearance()
        AppComposition.bootstrap()
        return true
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // MARK: - SwiftLint Hook 测试用例

    // 💡 测试方法：
    // 1. 解开下面函数的注释
    // 2. 终端执行: git add XClientLab/App/AppDelegate.swift
    // 3. 终端执行: git commit -m "test swiftlint hook"
    // 4. 结果: pre-commit 钩子将检测到该函数参数超过 10 个（触碰 .swiftlint.yml 中的 error 阈值），提交被成功拦截！

//     func testSwiftLintViolation(p1: Int, p2: Int, p3: Int, p4: Int, p5: Int, p6: Int, p7: Int, p8: Int, p9: Int, p10: Int, p11: Int) {
//         print("Trigger SwiftLint function_parameter_count error")
//     }
}
