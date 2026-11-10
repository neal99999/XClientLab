import Foundation

/// 面向协议的第一个例子：feature 依赖「能给我用户」这一能力，而不是某个具体实现。
/// 实现可以来自 Bundle 资源、HTTP、内存 Mock，调用方完全无感。
public protocol UserProviding: Sendable {
    func user(withID id: String) async throws -> UserProfile
}

public enum UserProvidingError: LocalizedError, Equatable, Sendable {
    case notFound(String)
    case unreadableResource(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "没有找到 id = \(id) 的用户档案"
        case .unreadableResource(let name):
            return "资源包里缺少或无法读取 \(name)"
        }
    }
}
