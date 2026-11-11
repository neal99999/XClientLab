import Combine
import Foundation

struct TickerQuote: Equatable, Sendable {
    let symbol: String
    let lastPrice: Decimal
    let changePercent: Double
    let timestampMillis: Int64
}

enum MarketDataError: Error, Equatable {
    case invalidSymbol
    case transport
    case httpStatus(Int)
    case malformedResponse

    var userMessage: String {
        switch self {
        case .invalidSymbol: return "交易对格式不合法"
        case .transport: return "网络连接失败"
        case let .httpStatus(code): return "服务端返回 HTTP \(code)"
        case .malformedResponse: return "行情响应格式异常"
        }
    }
}

/// 网络层端口：View / ViewModel 只依赖协议，不依赖 URLSession、Moya 或任何具体实现。
protocol MarketDataProviding: Sendable {
    func quote(for symbol: String) async throws -> TickerQuote
}

/// 真实实现：URLSession + JSONDecoder，错误显式映射为 MarketDataError。
final class URLSessionMarketDataService: MarketDataProviding {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.example.invalid")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func quote(for symbol: String) async throws -> TickerQuote {
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.range(of: "^[A-Z0-9]{2,12}(-[A-Z0-9]{2,12})?$", options: .regularExpression) != nil else {
            throw MarketDataError.invalidSymbol
        }

        let url = baseURL.appendingPathComponent("quote").appendingPathComponent(normalized)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw MarketDataError.transport
        }

        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw MarketDataError.httpStatus(http.statusCode)
        }

        struct Payload: Decodable {
            let symbol: String
            let price: String
            let changePercent: Double
            let timestamp: Int64
        }

        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            guard let price = Decimal(string: payload.price), price > 0 else {
                throw MarketDataError.malformedResponse
            }
            return TickerQuote(
                symbol: payload.symbol,
                lastPrice: price,
                changePercent: payload.changePercent,
                timestampMillis: payload.timestamp
            )
        } catch let error as MarketDataError {
            throw error
        } catch {
            throw MarketDataError.malformedResponse
        }
    }
}

/// 可测试的行情 ViewModel：显式的 idle → loading → loaded/failed 状态机。
@MainActor
final class MarketDataViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading(symbol: String)
        case loaded(TickerQuote)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastLoadedSymbol: String?

    private let service: any MarketDataProviding

    init(service: any MarketDataProviding) {
        self.service = service
    }

    func load(symbol: String) async {
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else {
            state = .failed(message: MarketDataError.invalidSymbol.userMessage)
            return
        }

        state = .loading(symbol: normalized)
        do {
            let quote = try await service.quote(for: normalized)
            lastLoadedSymbol = quote.symbol
            state = .loaded(quote)
        } catch let error as MarketDataError {
            state = .failed(message: error.userMessage)
        } catch {
            state = .failed(message: MarketDataError.transport.userMessage)
        }
    }

    func reset() {
        state = .idle
        lastLoadedSymbol = nil
    }
}
