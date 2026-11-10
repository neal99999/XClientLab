import Foundation

/// 模块装配契约：每个 feature 包只暴露「我是谁」和「我往容器里注册什么」。
/// App 层不认识具体实现，只认识 FeatureModule，因此新增模块不需要改组装代码的结构。
public protocol FeatureModule: Sendable {
    static var identifier: String { get }
    func registerServices(in container: ServiceContainer)
}
