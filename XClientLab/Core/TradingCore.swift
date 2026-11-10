import Foundation

// MARK: - Money

/// 以最小货币单位（分）保存金额，避免 `Double` 在价格/金额换算中的二进制误差。
struct Money: Equatable {
    enum Currency: String {
        case usd = "USD"
        case cny = "CNY"

        var symbol: String {
            switch self {
            case .usd: return "$"
            case .cny: return "¥"
            }
        }
    }

    let minorUnits: Int64
    let currency: Currency

    init?(minorUnits: Int64, currency: Currency) {
        guard minorUnits >= 0 else { return nil }
        self.minorUnits = minorUnits
        self.currency = currency
    }

    /// 解析 `"1,234.56"` / `"$1234.56"` 之类的用户输入；超过两位小数会拒绝，避免静默截断。
    static func parse(_ raw: String, currency: Currency = .usd) -> Money? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: currency.symbol, with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty,
              var decimal = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              decimal >= 0
        else { return nil }

        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 2, .plain)
        guard rounded == decimal else { return nil }

        let minor = NSDecimalNumber(decimal: rounded)
            .multiplying(by: NSDecimalNumber(value: 100))
        guard minor != .notANumber else { return nil }

        return Money(minorUnits: minor.int64Value, currency: currency)
    }

    /// `123456` → `"$1,234.56"`；固定 en_US_POSIX 分组，便于测试和日志比对。
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.maximumFractionDigits = 0

        let whole = minorUnits / 100
        let cents = minorUnits % 100
        let wholeText = formatter.string(from: NSNumber(value: whole)) ?? "\(whole)"
        return "\(currency.symbol)\(wholeText).\(String(format: "%02lld", cents))"
    }
}

// MARK: - Time

enum TradingTime {
    static let utc = TimeZone(secondsFromGMT: 0)!

    static func date(fromMillis millis: Int64) -> Date {
        Date(timeIntervalSince1970: Double(millis) / 1_000)
    }

    static func millis(from date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    /// 盘口日志统一用 UTC `HH:mm:ss.SSS`，避免演示机时区影响断言。
    static func formatted(fromMillis millis: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date(fromMillis: millis))
    }
}

// MARK: - Market data

struct MarketTick: Decodable, Equatable {
    let symbol: String
    let price: String
    let size: String
    let timestamp: Int64
}

enum MarketDataParser {
    enum ParseError: Error, Equatable {
        case invalidPayload
        case empty
        case malformedTick(index: Int)
    }

    private struct Envelope: Decodable {
        let ticks: [MarketTick]
    }

    /// 解析 `{ "ticks": [...] }`，并校验 symbol、正价格/数量、时间戳。
    /// 解析器不信任服务端：坏一条就整体失败，避免把脏数据推进 UI。
    static func parseTicks(from data: Data) throws -> [MarketTick] {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ParseError.invalidPayload
        }

        guard !envelope.ticks.isEmpty else { throw ParseError.empty }

        for (index, tick) in envelope.ticks.enumerated() {
            let symbol = tick.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !symbol.isEmpty,
                  let price = Decimal(string: tick.price),
                  price > 0,
                  let size = Decimal(string: tick.size),
                  size > 0,
                  tick.timestamp > 0
            else {
                throw ParseError.malformedTick(index: index)
            }
        }
        return envelope.ticks
    }
}

// MARK: - Order validation

enum OrderSide: String {
    case buy = "BUY"
    case sell = "SELL"
}

struct OrderRequest: Equatable {
    let symbol: String
    let side: OrderSide
    let price: Money
    let quantity: Int
    /// 以最小货币单位表示的委托总额上限。
    let notionalLimit: Int64?
}

enum OrderValidationError: Error, Equatable {
    case emptySymbol
    case invalidSymbol
    case nonPositivePrice
    case nonPositiveQuantity
    case notionalExceeded
}

enum OrderValidator {
    private static let symbolRegex = try! NSRegularExpression(
        pattern: "^[A-Z0-9]{2,12}(-[A-Z0-9]{2,12})?$"
    )

    static func validate(_ request: OrderRequest) -> Result<Void, OrderValidationError> {
        let symbol = request.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty else { return .failure(.emptySymbol) }

        let range = NSRange(symbol.startIndex..<symbol.endIndex, in: symbol)
        guard symbolRegex.firstMatch(in: symbol, range: range) != nil else {
            return .failure(.invalidSymbol)
        }

        guard request.price.minorUnits > 0 else { return .failure(.nonPositivePrice) }
        guard request.quantity > 0 else { return .failure(.nonPositiveQuantity) }

        if let limit = request.notionalLimit {
            let (notional, overflow) = request.price.minorUnits
                .multipliedReportingOverflow(by: Int64(request.quantity))
            guard !overflow, notional <= limit else {
                return .failure(.notionalExceeded)
            }
        }

        return .success(())
    }
}
