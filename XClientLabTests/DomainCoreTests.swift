import XCTest
@testable import XClientLab

/// 纯逻辑层基线用例：金额/时间换算、行情解析、委托校验。
/// 这些用例不启动 App、不碰网络，目标是给交易域提供快速回归网。
final class DomainCoreTests: XCTestCase {

    // MARK: - Money

    func testMoneyParsesGroupedDecimalString() {
        XCTAssertEqual(Money.parse("$1,234.56"), Money(minorUnits: 123_456, currency: .usd))
    }

    func testMoneyFormatsMinorUnitsWithSymbolAndGrouping() {
        let money = Money(minorUnits: 123_456, currency: .usd)!
        XCTAssertEqual(money.formatted(), "$1,234.56")
    }

    func testMoneyRejectsNegativeAmount() {
        XCTAssertNil(Money.parse("-1.00"))
    }

    func testMoneyRejectsMoreThanTwoFractionDigits() {
        XCTAssertNil(Money.parse("12.345"), "金额输入不能静默截断到两位小数")
    }

    func testMoneyRejectsNonNumericInput() {
        XCTAssertNil(Money.parse("not-a-price"))
    }

    func testMoneyUsesCurrencySymbolWhenParsingCNY() {
        XCTAssertEqual(Money.parse("¥88.80", currency: .cny), Money(minorUnits: 8_880, currency: .cny))
    }

    // MARK: - Time

    func testTradingTimeConvertsMillisToDate() {
        let date = TradingTime.date(fromMillis: 1_700_000_000_000)
        XCTAssertEqual(date.timeIntervalSince1970, 1_700_000_000, accuracy: 0.0001)
    }

    func testTradingTimeRoundTripsDateAndMillis() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.123)
        XCTAssertEqual(TradingTime.millis(from: date), 1_700_000_000_123)
    }

    func testTradingTimeFormatsUTCWithMilliseconds() {
        XCTAssertEqual(TradingTime.formatted(fromMillis: 1_700_000_000_000), "22:13:20.000")
    }

    // MARK: - Order validation

    private func order(
        symbol: String = "BTCUSDT",
        priceMinorUnits: Int64 = 42_000_00,
        quantity: Int = 1,
        limit: Int64? = nil
    ) -> OrderRequest {
        OrderRequest(
            symbol: symbol,
            side: .buy,
            price: Money(minorUnits: priceMinorUnits, currency: .usd)!,
            quantity: quantity,
            notionalLimit: limit
        )
    }

    func testValidatorAcceptsWellFormedLimitOrder() {
        assertSuccess(OrderValidator.validate(order()))
    }

    func testValidatorRejectsEmptySymbol() {
        assertFailure(OrderValidator.validate(order(symbol: "  ")), .emptySymbol)
    }

    func testValidatorRejectsIllegalSymbolCharacters() {
        assertFailure(OrderValidator.validate(order(symbol: "BTC USDT")), .invalidSymbol)
    }

    func testValidatorRejectsZeroPrice() {
        assertFailure(OrderValidator.validate(order(priceMinorUnits: 0)), .nonPositivePrice)
    }

    func testValidatorRejectsZeroQuantity() {
        assertFailure(OrderValidator.validate(order(quantity: 0)), .nonPositiveQuantity)
    }

    func testValidatorRejectsNotionalAboveLimit() {
        assertFailure(
            OrderValidator.validate(order(priceMinorUnits: 100_00, quantity: 10, limit: 99_999)),
            .notionalExceeded
        )
    }

    func testValidatorAcceptsNotionalExactlyAtLimit() {
        assertSuccess(
            OrderValidator.validate(order(priceMinorUnits: 100_00, quantity: 10, limit: 100_000))
        )
    }

    private func assertSuccess(
        _ result: Result<Void, OrderValidationError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case .failure(let error) = result {
            XCTFail("Expected success, got \(error)", file: file, line: line)
        }
    }

    private func assertFailure(
        _ result: Result<Void, OrderValidationError>,
        _ expected: OrderValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            XCTFail("Expected \(expected), got success", file: file, line: line)
        case .failure(let error):
            XCTAssertEqual(error, expected, file: file, line: line)
        }
    }

    // MARK: - Market data parser

    private func payload(_ ticks: String) -> Data {
        Data("{\"ticks\":[\(ticks)]}".utf8)
    }

    func testMarketDataParserDecodesValidTicks() throws {
        let data = payload("""
        {"symbol":"BTCUSDT","price":"42000.50","size":"0.25","timestamp":1700000000000},
        {"symbol":"ETHUSDT","price":"2200.00","size":"1.5","timestamp":1700000000100}
        """)
        let ticks = try MarketDataParser.parseTicks(from: data)
        XCTAssertEqual(ticks.count, 2)
        XCTAssertEqual(ticks[0].symbol, "BTCUSDT")
        XCTAssertEqual(ticks[1].timestamp, 1_700_000_000_100)
    }

    func testMarketDataParserRejectsEmptyTickArray() {
        XCTAssertThrowsError(try MarketDataParser.parseTicks(from: payload(""))) { error in
            XCTAssertEqual(error as? MarketDataParser.ParseError, .empty)
        }
    }

    func testMarketDataParserRejectsMalformedJSON() {
        XCTAssertThrowsError(try MarketDataParser.parseTicks(from: Data("{}".utf8))) { error in
            XCTAssertEqual(error as? MarketDataParser.ParseError, .invalidPayload)
        }
    }

    func testMarketDataParserRejectsInvalidPriceInSecondTick() {
        let data = payload("""
        {"symbol":"BTCUSDT","price":"42000.50","size":"0.25","timestamp":1700000000000},
        {"symbol":"ETHUSDT","price":"-1","size":"1.5","timestamp":1700000000100}
        """)
        XCTAssertThrowsError(try MarketDataParser.parseTicks(from: data)) { error in
            XCTAssertEqual(error as? MarketDataParser.ParseError, .malformedTick(index: 1))
        }
    }
}
