import Foundation
import Darwin

/// Reads the process' physical memory footprint without pulling in a
/// third-party metrics SDK. Useful for making "memory churn" visible in the UI
/// while Allocations shows the same story with more detail.
enum MemoryProbe {
    static func footprintBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    rebound,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    static func footprintMB() -> Double {
        Double(footprintBytes()) / 1_048_576
    }
}

enum LabFormat {
    static func milliseconds(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2f", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    static func durationUnit(_ value: Double) -> String {
        value >= 1000 ? "s" : "ms"
    }

    static func memory(_ value: Double) -> String {
        if value >= 1024 {
            return String(format: "%.2f", value / 1024)
        }
        return String(format: "%.0f", value)
    }

    static func memoryUnit(_ value: Double) -> String {
        value >= 1024 ? "GB" : "MB"
    }

    static func integer(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
