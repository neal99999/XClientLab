import Foundation
import UIKit

/// 资源处理统一入口：一个模块的资源（JSON / 本地化 / 颜色）都在自己的 bundle 里，
/// 不依赖主 App 的 Assets，也不会和别的模块资源重名。
///
/// `Bundle.module` 是 SwiftPM 为每个含资源的 target 自动生成的访问器。
public enum FeatureResources {
    public static var bundle: Bundle { .module }

    public static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
    }

    public static func fileURL(named name: String, withExtension ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
    }

    /// 资源里的品牌色；读不到时回退到系统色，保证 demo 永远不会因为资源缺失而白屏。
    public static var brandAccent: UIColor {
        UIColor(named: "FeatureAccent", in: .module, compatibleWith: nil) ?? .systemTeal
    }

    public static var bundleName: String {
        Bundle.module.bundleURL.lastPathComponent
    }
}
