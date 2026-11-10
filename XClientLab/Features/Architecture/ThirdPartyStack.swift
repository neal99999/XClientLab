import Alamofire
import Foundation
import Kingfisher
import Moya
import SnapKit
import Starscream
import UIKit

/// 对已接入的五个三方库各做一次真实调用，证明依赖不是「挂在工程里好看」。
/// 全部离线可跑：Moya 走立即 stub，Starscream 只建立 WebSocket 对象不连接。
enum ThirdPartyStack {
    struct Check: Identifiable {
        let id = UUID()
        let library: String
        let detail: String
        let ok: Bool
    }

    @MainActor
    static func runSelfCheck() -> [Check] {
        var checks: [Check] = []

        let session = Session(configuration: .ephemeral)
        checks.append(Check(
            library: "Alamofire",
            detail: "Session(ephemeral) timeout=\(Int(session.sessionConfiguration.timeoutIntervalForRequest))s",
            ok: true
        ))

        let cache = ImageCache(name: "xclientlab.selfcheck")
        checks.append(Check(
            library: "Kingfisher",
            detail: "ImageCache memory costLimit=\(cache.memoryStorage.config.totalCostLimit)",
            ok: true
        ))

        let provider = MoyaProvider<SelfCheckTarget>(stubClosure: MoyaProvider.immediatelyStub)
        let endpoint = provider.endpoint(SelfCheckTarget.ping)
        checks.append(Check(
            library: "Moya",
            detail: "stub provider endpoint=\(endpoint.url)",
            ok: endpoint.url.contains("example.invalid")
        ))

        let host = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        let child = UIView()
        host.addSubview(child)
        child.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        host.layoutIfNeeded()
        checks.append(Check(
            library: "SnapKit",
            detail: "constraint → \(Int(child.frame.width))×\(Int(child.frame.height))",
            ok: child.frame.width > 0
        ))

        var request = URLRequest(url: URL(string: "wss://example.invalid/socket")!)
        request.timeoutInterval = 2
        let socket = WebSocket(request: request)
        socket.onEvent = { _ in }
        let socketHost = socket.request.url?.host ?? "nil"
        checks.append(Check(
            library: "Starscream",
            detail: "WebSocket(request:) ready · host=\(socketHost)",
            ok: socketHost == "example.invalid"
        ))

        return checks
    }
}

private enum SelfCheckTarget: TargetType {
    case ping

    var baseURL: URL { URL(string: "https://example.invalid")! }
    var path: String { "/ping" }
    var method: Moya.Method { .get }
    var task: Moya.Task { .requestPlain }
    var headers: [String: String]? { ["Accept": "application/json"] }
}
