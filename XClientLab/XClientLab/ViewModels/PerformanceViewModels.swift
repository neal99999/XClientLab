import Combine
import Foundation

import Foundation

/// Scenario 1.1 — deliberate main-thread stalls.
///
/// All of the expensive work below is intentionally synchronous and on the
/// main queue. There is no `Task`, no `await`, no background queue: the whole
/// point is to give Time Profiler a clean, repeatable "main thread is the
/// bottleneck" trace.
@MainActor
final class CPUStallViewModel: ObservableObject {
    enum Intensity: Int, CaseIterable, Identifiable {
        case light = 1
        case standard = 2
        case extreme = 3

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .light: return "轻度"
            case .standard: return "标准"
            case .extreme: return "极端"
            }
        }

        var passCount: Int { rawValue * 4 }
    }

    struct StallPass: Identifiable {
        let id = UUID()
        let index: Int
        let durationMs: Double
        let matchCount: Int
        let recordCount: Int
    }

    @Published var intensity: Intensity = .standard
    @Published private(set) var isRunning = false
    @Published private(set) var passes: [StallPass] = []
    @Published private(set) var totalBlockedMs: Double = 0
    @Published private(set) var worstPassMs: Double = 0
    @Published private(set) var payloadBytes: Int = 0
    @Published private(set) var matchCount: Int = 0
    @Published private(set) var phase: String = "IDLE"

    let console = LabLogStore()
    let hitch = HitchMonitor()

    private var preparedPayload: (data: Data, text: String)?
    // swiftlint:disable:next force_try - 正则常量写死在源码里，失败只可能是代码本身写错
    private let regex = try! NSRegularExpression(
        pattern: #"(?i)([a-z0-9._%+-]+)@([a-z0-9.-]+\.[a-z]{2,})|(BTC|ETH|SOL)[-/]?(USDT|USD)"#,
        options: []
    )

    var payloadMB: Double {
        Double(payloadBytes) / 1_048_576
    }

    func startMonitoring() {
        hitch.start()
    }

    func stopMonitoring() {
        hitch.stop()
    }

    func runStress() {
        guard !isRunning else { return }
        isRunning = true
        phase = "QUEUED"
        console.log("主线程压力已排队：250ms 后开始执行 \(intensity.passCount) 轮同步解析", level: .warning)
        console.log("从这一刻起，主线程将不再响应触摸、布局与 CADisplayLink", level: .debug)

        // The short delay gives SwiftUI one run-loop turn to render the button
        // state before the main queue disappears into the blocking section.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.executeBlockingWork()
        }
    }

    func reset() {
        passes = []
        totalBlockedMs = 0
        worstPassMs = 0
        matchCount = 0
        phase = "IDLE"
        hitch.reset()
        console.clear()
    }

    // MARK: - The intentionally bad path

    private func executeBlockingWork() {
        phase = "BLOCKING MAIN"
        let wallStart = CFAbsoluteTimeGetCurrent()
        let payload = preparePayloadIfNeeded()
        let nsPayload = payload.text as NSString
        let fullRange = NSRange(location: 0, length: nsPayload.length)

        var localPasses: [StallPass] = []
        var localMatches = 0

        for index in 0..<intensity.passCount {
            let passStart = CFAbsoluteTimeGetCurrent()

            // Deliberate anti-patterns:
            // 1. JSONSerialization of a multi-megabyte payload on the main actor.
            // 2. NSRegularExpression scanning the full string for every pass.
            // 3. No chunking, no cancellation check, no protocol boundary.
            autoreleasepool {
                _ = try? JSONSerialization.jsonObject(
                    with: payload.data,
                    options: [.fragmentsAllowed]
                )
                localMatches += regex.numberOfMatches(
                    in: payload.text,
                    options: [],
                    range: fullRange
                )
                _ = nsPayload.substring(with: NSRange(location: 0, length: min(256, nsPayload.length)))
            }

            let durationMs = (CFAbsoluteTimeGetCurrent() - passStart) * 1000
            localPasses.append(
                StallPass(
                    index: index + 1,
                    durationMs: durationMs,
                    matchCount: localMatches,
                    recordCount: 6_000
                )
            )
            // Update local state only. Touching @Published from inside this loop
            // would trigger layout on an already-frozen main thread.
        }

        let wallMs = (CFAbsoluteTimeGetCurrent() - wallStart) * 1000
        passes = localPasses
        totalBlockedMs = wallMs
        worstPassMs = localPasses.map(\.durationMs).max() ?? 0
        matchCount = localMatches
        payloadBytes = payload.data.count
        phase = "DONE"
        isRunning = false

        console.log(
            "主线程恢复：连续阻塞 \(String(format: "%.0f", wallMs))ms，\(intensity.passCount) 轮，正则命中 \(LabFormat.integer(localMatches)) 次",
            level: .error
        )
        console.log(
            "Time Profiler 应看到 JSONSerialization / NSRegularExpression 占据主线程采样",
            level: .info
        )
        console.log(
            "CADisplayLink 恢复后记录到最大帧间隔 \(String(format: "%.0f", hitch.lastGapMs))ms",
            level: .warning
        )
    }

    private func preparePayloadIfNeeded() -> (data: Data, text: String) {
        if let preparedPayload {
            return preparedPayload
        }
        phase = "BUILD PAYLOAD"
        console.log("构建 6,000 条模拟行情记录（约 3MB JSON）…", level: .debug)
        let start = CFAbsoluteTimeGetCurrent()
        let data = CPUStallPayload.makeData(records: 6_000)
        // swiftlint:disable:next optional_data_string_conversion - 演示要的是「永不失败」的解码，便于量化耗时
        let text = String(decoding: data, as: UTF8.self)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let payload = (data, text)
        preparedPayload = payload
        console.log(
            "Payload 构建完成：\(String(format: "%.1f", Double(data.count) / 1_048_576))MB / \(String(format: "%.0f", elapsed))ms（同样发生在主线程）",
            level: .debug
        )
        return payload
    }
}

enum CPUStallPayload {
    static func makeData(records: Int) -> Data {
        var pieces: [String] = []
        pieces.reserveCapacity(records)
        let symbols = ["BTC-USDT", "ETH-USDT", "SOL-USDT", "BNB-USDT"]
        for index in 0..<records {
            let symbol = symbols[index % symbols.count]
            let price = 20_000 + (index % 4_000)
            let email = "desk\(index % 97)@market-lab.example"
            pieces.append(
                #"{"id":\#(index),"symbol":"\#(symbol)","price":\#(price),"email":"\#(email)","note":"order-book-snapshot-\#(index)"}"#
            )
        }
        let json = "{\"records\":[" + pieces.joined(separator: ",") + "]}"
        return Data(json.utf8)
    }
}

import Foundation

/// Scenario 1.2 — allocation sawtooth.
///
/// A long feed is paired with a timer that repeatedly allocates large
/// `[UInt8]` buffers and short-lived value objects. Buffers are held for a
/// few ticks so that the footprint rises in steps, then are released in one
/// burst. In Allocations this reads as a violent sawtooth; in the memory graph
/// it is a series of short-lived generations.
@MainActor
final class AllocationStormViewModel: NSObject, ObservableObject {
    enum Intensity: Int, CaseIterable, Identifiable {
        case light = 1
        case standard = 2
        case extreme = 3

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .light: return "轻度"
            case .standard: return "标准"
            case .extreme: return "极端"
            }
        }

        var buffersPerTick: Int {
            switch self {
            case .light: return 4
            case .standard: return 10
            case .extreme: return 20
            }
        }

        var holdTicks: Int {
            switch self {
            case .light: return 4
            case .standard: return 7
            case .extreme: return 10
            }
        }
    }

    let bufferBytes = 256 * 1024

    @Published var intensity: Intensity = .standard
    @Published private(set) var isRunning = false
    @Published private(set) var footprintMB: Double = 0
    @Published private(set) var peakMB: Double = 0
    @Published private(set) var churnedMB: Double = 0
    @Published private(set) var liveBuffers: Int = 0
    @Published private(set) var tickCount: Int = 0
    @Published private(set) var samples: [Double] = []

    let console = LabLogStore()
    private(set) var feed: [MarketRow] = []

    private var timer: Timer?
    private var pool: [[UInt8]] = []
    private var churnedBytes: Double = 0

    override init() {
        super.init()
        feed = MarketRow.makeFeed(count: 5_000)
        footprintMB = MemoryProbe.footprintMB()
    }

    deinit {
        timer?.invalidate()
    }

    var liveMB: Double {
        Double(liveBuffers * bufferBytes) / 1_048_576
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        tickCount = 0
        samples = []
        peakMB = footprintMB
        console.log("Allocation storm 启动：每 tick 分配 \(intensity.buffersPerTick) × 256KB，持有 \(intensity.holdTicks) tick", level: .warning)
        console.log("滚动长列表的同时观察 Allocations 的锯齿与 Generation 标记", level: .info)

        let timer = Timer(
            timeInterval: 0.08,
            target: self,
            selector: #selector(handleTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        isRunning = false
        console.log("Allocation storm 停止，释放持有中的 \(liveBuffers) 个 buffer", level: .debug)
        releasePool(log: false)
        sample()
    }

    func reset() {
        stop()
        pool.removeAll(keepingCapacity: false)
        liveBuffers = 0
        tickCount = 0
        churnedBytes = 0
        churnedMB = 0
        samples = []
        footprintMB = MemoryProbe.footprintMB()
        peakMB = footprintMB
        console.clear()
    }

    func sampleNow() {
        sample()
    }

    @objc private func handleTick() {
        tickCount += 1

        // 1. Large, short-lived byte buffers. Held for several ticks so that the
        //    footprint climbs in a staircase instead of staying flat.
        var allocatedThisTick = 0
        for _ in 0..<intensity.buffersPerTick {
            pool.append([UInt8](repeating: 0xAB, count: bufferBytes))
            allocatedThisTick += bufferBytes
        }
        liveBuffers = pool.count
        churnedBytes += Double(allocatedThisTick)
        churnedMB = churnedBytes / 1_048_576

        // 2. Thousands of short-lived value objects per tick. Each `QuoteTick`
        //    owns two Strings, so Allocations sees a dense spray of tiny
        //    objects in addition to the big buffers.
        var transient: [QuoteTick] = []
        transient.reserveCapacity(600)
        for index in 0..<600 {
            transient.append(
                QuoteTick(
                    symbol: Self.symbols[index % Self.symbols.count],
                    price: Double(20_000 + (tickCount * 13 + index) % 5_000),
                    venue: "venue-\(index % 12)"
                )
            )
        }
        _ = transient.count
        transient.removeAll(keepingCapacity: false)

        if pool.count >= intensity.buffersPerTick * intensity.holdTicks {
            releasePool(log: true)
        }

        sample()

        if tickCount % 5 == 0 {
            console.log(
                // swiftlint:disable:next line_length - 演示文案需要整句可读
                "tick #\(tickCount)：live \(liveBuffers) buffers / \(String(format: "%.1f", liveMB))MB，footprint \(String(format: "%.1f", footprintMB))MB，累计 churn \(String(format: "%.0f", churnedMB))MB",
                level: .debug
            )
        }
    }

    private func releasePool(log: Bool) {
        let released = liveBuffers
        pool.removeAll(keepingCapacity: false)
        liveBuffers = 0
        if log {
            console.log("锯齿回落：一次性释放 \(released) 个 buffer（约 \(released * bufferBytes / 1_048_576)MB）", level: .info)
        }
    }

    private func sample() {
        footprintMB = MemoryProbe.footprintMB()
        peakMB = max(peakMB, footprintMB)
        samples.append(footprintMB)
        if samples.count > 90 {
            samples.removeFirst(samples.count - 90)
        }
    }

    private static let symbols = ["BTC-USDT", "ETH-USDT", "SOL-USDT", "BNB-USDT", "XRP-USDT", "DOGE-USDT"]
}

struct QuoteTick {
    let symbol: String
    let price: Double
    let venue: String
}

struct MarketRow: Identifiable {
    let id: Int
    let symbol: String
    let price: Double
    let change: Double
    let size: Int

    static func makeFeed(count: Int) -> [MarketRow] {
        let symbols = ["BTC-USDT", "ETH-USDT", "SOL-USDT", "BNB-USDT", "XRP-USDT", "DOGE-USDT", "ADA-USDT", "AVAX-USDT"]
        return (0..<count).map { index in
            MarketRow(
                id: index,
                symbol: symbols[index % symbols.count],
                price: 20_000 + Double((index * 37) % 45_000),
                change: Double((index * 17) % 900) / 100 - 4.5,
                size: (index * 91) % 100_000
            )
        }
    }
}

enum AllocationStormEngine {
    /// Allocates a small `Data` value for every row body evaluation. Scrolling
    /// the long list therefore produces a steady stream of short-lived
    /// allocations even before the timer storm is started.
    static func rowChecksum(_ index: Int) -> Int {
        let payload = Data(repeating: UInt8(index & 0xFF), count: 2_048)
        return payload.reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFF }
    }
}
