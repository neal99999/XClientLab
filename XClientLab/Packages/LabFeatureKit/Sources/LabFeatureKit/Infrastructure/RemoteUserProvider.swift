import Alamofire
import Foundation
import LabContracts

/// 同一个协议的网络实现：证明「协议不变、实现可替换」。
/// Demo 默认走 BundledUserProvider，这里是给面试官看真实网络层如何落到模块里的。
public struct RemoteUserProvider: UserProviding {
    private let baseURL: URL
    private let session: Session

    public init(baseURL: URL, session: Session = .default) {
        self.baseURL = baseURL
        self.session = session
    }

    public func user(withID id: String) async throws -> UserProfile {
        let response = await session
            .request(baseURL.appendingPathComponent("users/\(id)"))
            .serializingDecodable(UserProfile.self)
            .response

        switch response.result {
        case .success(let profile):
            return profile
        case .failure(let error):
            throw error
        }
    }
}
