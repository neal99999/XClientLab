import Foundation
import LabContracts

/// 组合两个协议的服务：说明 DI 不只是「把东西塞进去」，而是让服务之间也通过协议协作。
public struct UserDirectoryService: Sendable {
    private let provider: any UserProviding
    private let analytics: any AnalyticsTracking

    public init(provider: any UserProviding, analytics: any AnalyticsTracking) {
        self.provider = provider
        self.analytics = analytics
    }

    public func openProfile(userID: String) async throws -> UserProfile {
        analytics.track("profile.open", properties: ["userID": userID])
        do {
            let profile = try await provider.user(withID: userID)
            analytics.track("profile.loaded", properties: ["userID": userID])
            return profile
        } catch {
            analytics.track("profile.failed", properties: [
                "userID": userID,
                "reason": String(describing: error),
            ])
            throw error
        }
    }
}
