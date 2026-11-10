import Foundation
import LabContracts
import LabFeatureKit

/// 组装根（Composition Root）：整个 App 唯一知道「协议 → 实现」映射的地方。
/// 模块自己只负责注册，App 只负责把模块列表跑一遍；新增模块不需要改这里的分支逻辑。
enum AppComposition {
    static let container = ServiceContainer()

    static let modules: [any FeatureModule] = [
        FeatureKitModule()
    ]

    static func bootstrap() {
        for module in modules {
            module.registerServices(in: container)
        }
        #if DEBUG
        NSLog("[AppComposition] services=%@", container.registeredServices.joined(separator: ", "))
        #endif
    }
}
