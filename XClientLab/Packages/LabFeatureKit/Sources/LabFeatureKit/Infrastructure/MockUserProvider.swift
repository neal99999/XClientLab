import Foundation
import LabContracts

/// 依赖注入的价值：测试 / Preview 里把实现换成 Mock，调用方一行不用改。
public struct MockUserProvider: UserProviding {
    private let latency: UInt64

    public init(latencyNanoseconds: UInt64 = 120_000_000) {
        self.latency = latencyNanoseconds
    }

    public func user(withID id: String) async throws -> UserProfile {
        if latency > 0 {
            try? await Task.sleep(nanoseconds: latency)
        }
        return UserProfile(
            id: id,
            displayName: "Mock 面试官",
            role: "Staff Engineer · In-Memory 数据",
            email: "mock@xclientlab.dev"
        )
    }
}
