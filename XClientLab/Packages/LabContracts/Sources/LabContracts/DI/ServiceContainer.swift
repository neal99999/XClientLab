import Foundation

/// 一个刻意做小的依赖注入容器：
/// - 注册的是「工厂」，不是实例，所以依赖关系可以延迟到解析时再拼；
/// - 支持 transient / singleton 两种作用域；
/// - 用递归锁保护，允许工厂里继续 resolve 其他服务（组装链）。
///
/// 面试点：容器本身没有魔法，它只是把 `AppComposition` 里的手工装配集中到一处，
/// 让业务类型继续只依赖协议。
public final class ServiceContainer: @unchecked Sendable {
    public enum Scope: Sendable, Equatable {
        case transient
        case singleton
    }

    private struct Entry {
        let name: String
        let scope: Scope
        let factory: @Sendable () -> Any
        var cached: Any?
    }

    private var entries: [ObjectIdentifier: Entry] = [:]
    private let lock = NSRecursiveLock()

    public init() {}

    @discardableResult
    public func register<T>(
        _ type: T.Type = T.self,
        as name: String? = nil,
        scope: Scope = .singleton,
        factory: @escaping @Sendable () -> T
    ) -> Self {
        lock.lock()
        defer { lock.unlock() }
        entries[ObjectIdentifier(type)] = Entry(
            name: name ?? String(describing: type),
            scope: scope,
            factory: factory,
            cached: nil
        )
        return self
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T {
        lock.lock()
        defer { lock.unlock() }

        guard var entry = entries[ObjectIdentifier(type)] else {
            fatalError("ServiceContainer: \(type) 还没有注册")
        }

        switch entry.scope {
        case .transient:
            return make(entry)
        case .singleton:
            if let cached = entry.cached as? T {
                return cached
            }
            let instance: T = make(entry)
            entry.cached = instance
            entries[ObjectIdentifier(type)] = entry
            return instance
        }
    }

    public func resolveOptional<T>(_ type: T.Type = T.self) -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = entries[ObjectIdentifier(type)] else { return nil }
        if entry.scope == .singleton, let cached = entry.cached as? T {
            return cached
        }
        let instance: T? = make(entry)
        return instance
    }

    public func contains<T>(_ type: T.Type = T.self) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries[ObjectIdentifier(type)] != nil
    }

    /// 供演示页展示「容器里现在有什么」，也是排查装配遗漏的最快入口。
    public var registeredServices: [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries.values.map(\.name).sorted()
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    private func make<T>(_ entry: Entry) -> T {
        guard let instance = entry.factory() as? T else {
            fatalError("ServiceContainer: \(entry.name) 的工厂返回了不匹配的类型")
        }
        return instance
    }
}
