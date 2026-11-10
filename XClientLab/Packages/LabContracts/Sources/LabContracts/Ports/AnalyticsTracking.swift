import Foundation

/// 面向协议的第二个例子：埋点是一个能力，不是一个单例。
/// 好处是测试时不会把事件真的发到网络上，preview 里也可以完全静默。
public protocol AnalyticsTracking: Sendable {
    func track(_ name: String, properties: [String: String])
}

public extension AnalyticsTracking {
    func track(_ name: String) {
        track(name, properties: [:])
    }
}
