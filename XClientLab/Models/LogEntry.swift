import Combine
import Foundation
import UIKit

struct LogEntry: Identifiable, Equatable {
    enum Level: String {
        case info = "INFO"
        case success = " OK "
        case warning = "WARN"
        case error = "FAIL"
        case debug = "DBG "

        var uiColor: UIColor {
            switch self {
            case .info: return LabUI.cyan
            case .success: return LabUI.mint
            case .warning: return LabUI.amber
            case .error: return LabUI.coral
            case .debug: return LabUI.textTertiary
            }
        }
    }

    let id = UUID()
    let timestamp: Date
    let level: Level
    let message: String

    init(_ message: String, level: Level = .info, timestamp: Date = Date()) {
        self.message = message
        self.level = level
        self.timestamp = timestamp
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

@MainActor
final class LabLogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    private let capacity = 160

    func log(_ message: String, level: LogEntry.Level = .info) {
        entries.append(LogEntry(message, level: level))
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
