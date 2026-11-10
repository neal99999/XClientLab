import Foundation

/// 跨模块共享的纯数据模型：没有 UIKit / 没有网络 / 没有持久化。
/// 面试点：模型放在「契约层」，任何 feature 都不能把 UI 类型泄漏到这里。
public struct UserProfile: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let displayName: String
    public let role: String
    public let email: String

    public init(id: String, displayName: String, role: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.email = email
    }

    public var initials: String {
        let letters = displayName.prefix(1)
        return letters.isEmpty ? "?" : String(letters)
    }
}
