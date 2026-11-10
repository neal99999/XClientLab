import Foundation
import LabContracts

/// 从模块自带资源读用户档案：不联网，演示资源加载 + JSON 解码。
public struct BundledUserProvider: UserProviding {
    private let fileName: String
    private let fileExtension: String

    public init(fileName: String = "demo-profiles", fileExtension: String = "json") {
        self.fileName = fileName
        self.fileExtension = fileExtension
    }

    public func user(withID id: String) async throws -> UserProfile {
        guard let match = try Self.allProfiles(fileName: fileName, fileExtension: fileExtension)
            .first(where: { $0.id == id }) else {
            throw UserProvidingError.notFound(id)
        }
        return match
    }

    public static func allProfiles(
        fileName: String = "demo-profiles",
        fileExtension: String = "json"
    ) throws -> [UserProfile] {
        guard let url = FeatureResources.fileURL(named: fileName, withExtension: fileExtension) else {
            throw UserProvidingError.unreadableResource("\(fileName).\(fileExtension)")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([UserProfile].self, from: data)
    }
}
