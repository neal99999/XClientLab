import Foundation
import MachO
import ObjectiveC
import UIKit

/// 启动专项的“现场仪表”。
///
/// 这里不做任何推测：冷启动时间取 `systemUptime` 的差值，类数量取
/// `objc_getClassList`，镜像数量取 dyld，可执行文件大小取 Bundle。
/// 面试时可以直接说清楚“这个数字从哪里来”。
enum PerformanceDiagnostics {
    /// didFinishLaunching 的近似时刻。必须在 AppDelegate 最前面调用，
    /// 否则主题页打开时才初始化，会得到 0ms 的假数据。
    private static var processStartUptime: TimeInterval = 0
    private static var firstFrameUptime: TimeInterval = 0

    static func captureProcessStart() {
        guard processStartUptime == 0 else { return }
        processStartUptime = ProcessInfo.processInfo.systemUptime
    }

    /// 首帧出现后调用；重复调用只记录第一次。
    static func markFirstFrame() {
        guard firstFrameUptime == 0 else { return }
        if processStartUptime == 0 {
            captureProcessStart()
        }
        firstFrameUptime = ProcessInfo.processInfo.systemUptime
    }

    static var coldStartMilliseconds: Double {
        guard processStartUptime > 0, firstFrameUptime > 0 else { return 0 }
        return max(0, (firstFrameUptime - processStartUptime) * 1000)
    }

    /// ObjC runtime 中的类数量。Swift 类也会注册到 runtime，因此这是一个
    /// 粗略但稳定可比较的 pre-main 复杂度指标。
    static var objcClassCount: Int {
        Int(objc_getClassList(nil, 0))
    }

    /// 当前进程加载的 Mach-O 镜像数，包含系统库与 App 自己的动态库。
    static var loadedImageCount: Int {
        Int(_dyld_image_count())
    }

    /// Debug 构建的可执行文件常常只是壳，真实代码在 .debug.dylib；
    /// 因此用整个主 Bundle 的占用作为“安装包”的近似值。
    static var bundleBytes: Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true
            else { continue }
            let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
            total += Int64(size)
        }
        return total
    }

    static var bundleSizeText: String {
        ByteCountFormatter.string(fromByteCount: bundleBytes, countStyle: .file)
    }

    /// 给 UI 用的四项快照，避免页面里散落探测逻辑。
    struct Snapshot {
        let coldStartText: String
        let classCountText: String
        let imageCountText: String
        let binarySizeText: String
    }

    static func snapshot() -> Snapshot {
        Snapshot(
            coldStartText: coldStartMilliseconds < 1
                ? "<1 ms"
                : String(format: "%.0f ms", coldStartMilliseconds),
            classCountText: NumberFormatter.localizedString(
                from: NSNumber(value: objcClassCount),
                number: .decimal
            ),
            imageCountText: NumberFormatter.localizedString(
                from: NSNumber(value: loadedImageCount),
                number: .decimal
            ),
            binarySizeText: bundleSizeText
        )
    }
}
