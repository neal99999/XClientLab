import Foundation
import LabContracts
import OSLog

public struct ConsoleAnalytics: AnalyticsTracking {
    private static let logger = Logger(
        subsystem: "dev.xclientlab.featurekit",
        category: "analytics"
    )

    public init() {}

    public func track(_ name: String, properties: [String: String]) {
        let payload = properties
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        Self.logger.info("event=\(name, privacy: .public) \(payload, privacy: .public)")
    }
}
