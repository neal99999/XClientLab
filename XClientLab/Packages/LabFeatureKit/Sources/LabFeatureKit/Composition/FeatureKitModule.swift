import LabContracts

/// 一个 feature 包的「组装说明书」：
/// 它只依赖 LabContracts，App 通过 FeatureModule 协议驱动它，不需要知道内部类型。
public struct FeatureKitModule: FeatureModule {
    public static let identifier = "dev.xclientlab.featurekit"
    public init() {}

    public func registerServices(in container: ServiceContainer) {
        container.register((any UserProviding).self, as: "UserProviding · Bundled") {
            BundledUserProvider()
        }
        container.register((any AnalyticsTracking).self, as: "AnalyticsTracking · OSLog") {
            ConsoleAnalytics()
        }
        container.register(UserDirectoryService.self, as: "UserDirectoryService") {
            let provider = container.resolve((any UserProviding).self)
            let analytics = container.resolve((any AnalyticsTracking).self)
            return UserDirectoryService(provider: provider, analytics: analytics)
        }
    }

    /// Demo 用的 Mock 切换：注册即覆盖，业务代码不用改。
    public func useMockProvider(in container: ServiceContainer) {
        container.register((any UserProviding).self, as: "UserProviding · Mock") {
            MockUserProvider()
        }
    }
}
