import XCTest
@testable import XClientLab

/// 网络层的 Mock 机制：测试只关心 ViewModel 的状态迁移，不启动真实 URLSession。
actor MockMarketDataService: MarketDataProviding {
    private var results: [Result<TickerQuote, Error>] = []
    private var requested: [String] = []

    func enqueue(_ result: Result<TickerQuote, Error>) {
        results.append(result)
    }

    func quote(for symbol: String) async throws -> TickerQuote {
        requested.append(symbol)
        guard !results.isEmpty else { throw MarketDataError.transport }
        return try results.removeFirst().get()
    }

    func requestedSymbols() -> [String] {
        requested
    }
}

@MainActor
final class MarketDataViewModelTests: XCTestCase {

    private let quote = TickerQuote(
        symbol: "BTCUSDT",
        lastPrice: Decimal(string: "42000.50")!,
        changePercent: 1.25,
        timestampMillis: 1_700_000_000_000
    )

    func testLoadMovesFromIdleToLoaded() async {
        let service = MockMarketDataService()
        await service.enqueue(.success(quote))
        let viewModel = MarketDataViewModel(service: service)

        XCTAssertEqual(viewModel.state, .idle)
        await viewModel.load(symbol: "BTCUSDT")

        XCTAssertEqual(viewModel.state, .loaded(quote))
        XCTAssertEqual(viewModel.lastLoadedSymbol, "BTCUSDT")
        let requested = await service.requestedSymbols()
        XCTAssertEqual(requested, ["BTCUSDT"])
    }

    func testLoadMapsMalformedResponseToFailedState() async {
        let service = MockMarketDataService()
        await service.enqueue(.failure(MarketDataError.malformedResponse))
        let viewModel = MarketDataViewModel(service: service)

        await viewModel.load(symbol: "ETHUSDT")

        XCTAssertEqual(viewModel.state, .failed(message: "行情响应格式异常"))
    }

    func testRetryAfterFailureReachesLoadedState() async {
        let service = MockMarketDataService()
        await service.enqueue(.failure(MarketDataError.transport))
        await service.enqueue(.success(quote))
        let viewModel = MarketDataViewModel(service: service)

        await viewModel.load(symbol: "BTCUSDT")
        guard case .failed = viewModel.state else {
            return XCTFail("First attempt should fail")
        }

        await viewModel.load(symbol: "BTCUSDT")
        XCTAssertEqual(viewModel.state, .loaded(quote))
        let requested = await service.requestedSymbols()
        XCTAssertEqual(requested, ["BTCUSDT", "BTCUSDT"])
    }

    func testLoadNormalizesWhitespaceAndCaseBeforeRequest() async {
        let service = MockMarketDataService()
        await service.enqueue(.success(quote))
        let viewModel = MarketDataViewModel(service: service)

        await viewModel.load(symbol: "  btcusdt  ")

        let requested = await service.requestedSymbols()
        XCTAssertEqual(requested, ["BTCUSDT"])
    }

    func testEmptySymbolFailsWithoutCallingNetwork() async {
        let service = MockMarketDataService()
        let viewModel = MarketDataViewModel(service: service)

        await viewModel.load(symbol: "   ")

        XCTAssertEqual(viewModel.state, .failed(message: "交易对格式不合法"))
        let requested = await service.requestedSymbols()
        XCTAssertEqual(requested, [])
    }

    func testResetReturnsToIdle() async {
        let service = MockMarketDataService()
        await service.enqueue(.success(quote))
        let viewModel = MarketDataViewModel(service: service)
        await viewModel.load(symbol: "BTCUSDT")

        viewModel.reset()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.lastLoadedSymbol)
    }
}
