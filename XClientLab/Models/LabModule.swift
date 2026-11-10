import UIKit

enum LabModule: String, CaseIterable, Identifiable {
    case performance
    case exceptions
    case exchange
    case aiNative
    case architecture

    var id: String {
        rawValue
    }

    var index: String {
        switch self {
        case .performance: return "01"
        case .exceptions: return "02"
        case .exchange: return "03"
        case .aiNative: return "04"
        case .architecture: return "05"
        }
    }

    var title: String {
        switch self {
        case .performance: return "性能优化专项"
        case .exceptions: return "异常处理攻坚"
        case .exchange: return "交易所专项"
        case .aiNative: return "AI-Native 效能"
        case .architecture: return "模块化架构"
        }
    }

    var shortTitle: String {
        switch self {
        case .performance: return "性能"
        case .exceptions: return "异常"
        case .exchange: return "交易所"
        case .aiNative: return "AI Native"
        case .architecture: return "架构"
        }
    }

    var englishTitle: String {
        switch self {
        case .performance: return "PERFORMANCE / INSTRUMENTS"
        case .exceptions: return "CRASH & CONCURRENCY"
        case .exchange: return "MARKET INFRASTRUCTURE"
        case .aiNative: return "AI-NATIVE WORKFLOW"
        case .architecture: return "MODULAR ARCHITECTURE"
        }
    }

    var tagline: String {
        switch self {
        case .performance:
            return "把「卡了一下」变成可复现、可归因、可验证的帧级证据。"
        case .exceptions:
            return "从系统栈黑盒到生命周期真相：UAF、数据竞争与崩溃取证。"
        case .exchange:
            return "弱网重连状态机与高频盘口节流：稳定性不是重试，而是纪律。"
        case .aiNative:
            return "Xcode MCP 通道纪律 × LLDB Skill × Terminal-first 自动化。"
        case .architecture:
            return "两个本地 SPM 包演示单向依赖、资源隔离与 POP + DI：契约 0 依赖，实现可替换。"
        }
    }

    var icon: String {
        switch self {
        case .performance: return "gauge.with.dots.needle.67percent"
        case .exceptions: return "exclamationmark.triangle.fill"
        case .exchange: return "chart.xyaxis.line"
        case .aiNative: return "sparkles"
        case .architecture: return "square.3.layers.3d"
        }
    }

    var accent: UIColor {
        switch self {
        case .performance: return LabUI.cyan
        case .exceptions: return LabUI.coral
        case .exchange: return LabUI.mint
        case .aiNative: return LabUI.violet
        case .architecture: return LabUI.amber
        }
    }

    var tags: [String] {
        switch self {
        case .performance: return ["Time Profiler", "Allocations", "Hitches"]
        case .exceptions: return ["LLDB", "MCP", "UAF", "TSan"]
        case .exchange: return ["WebSocket", "Backoff", "Diff", "Throttle"]
        case .aiNative: return ["Xcode MCP", "Skills", "Terminal"]
        case .architecture: return ["SPM", "POP", "DI", "资源"]
        }
    }
}
