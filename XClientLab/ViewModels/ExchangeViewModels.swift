import Combine
import Foundation
import UIKit

import Foundation

/// Scenario 3.1 — weak-network WebSocket reconnect strategy.
///
/// The transport is simulated on purpose: the interview point is the state
/// machine and the retry policy, not a live exchange endpoint. In production
/// `performHandshake()` would wrap `URLSessionWebSocketTask` and the same
/// `scheduleRetry` path would be driven by `didCloseWith` / receive errors.
@MainActor
final class ReconnectViewModel: NSObject, ObservableObject {
    enum LinkState: String {
        case offline = "OFFLINE"
        case connecting = "CONNECTING"
        case connected = "CONNECTED"
        case backoff = "BACKOFF"
        case exhausted = "EXHAUSTED"

        var color: UIColor {
            switch self {
            case .offline: return LabUI.textTertiary
            case .connecting: return LabUI.amber
            case .connected: return LabUI.mint
            case .backoff: return LabUI.cyan
            case .exhausted: return LabUI.coral
            }
        }

        var title: String {
            switch self {
            case .offline: return "离线"
            case .connecting: return "连接中"
            case .connected: return "已连接"
            case .backoff: return "退避等待"
            case .exhausted: return "重试耗尽"
            }
        }
    }

    struct RetryRecord: Identifiable {
        let id = UUID()
        let index: Int
        let reason: String
        let baseDelay: Double
        let jitter: Double
        let finalDelay: Double

        var jitterLabel: String {
            String(format: "×%.2f", jitter)
        }
    }

    let maxRetries = 6
    let baseDelay: Double = 0.5
    let maxDelay: Double = 8.0

    @Published private(set) var state: LinkState = .offline
    @Published private(set) var retryCount = 0
    @Published private(set) var retryRemaining: Double = 0
    @Published private(set) var history: [RetryRecord] = []
    @Published private(set) var connectedSince: Date?
    @Published var chaosEnabled = false {
        didSet {
            guard chaosEnabled != oldValue else { return }
            if chaosEnabled {
                console.log("弱网自动抖动开启：连接稳定 1.5–3.5s 后强制 1006 断线", level: .warning)
                scheduleChaosDropIfNeeded()
            } else {
                chaosTimer?.invalidate()
                chaosTimer = nil
                console.log("弱网自动抖动关闭", level: .info)
            }
        }
    }

    let console = LabLogStore()

    private var countdownTimer: Timer?
    private var chaosTimer: Timer?
    private var handshakeWorkItem: DispatchWorkItem?
    private var attemptSerial = 0

    deinit {
        countdownTimer?.invalidate()
        chaosTimer?.invalidate()
        handshakeWorkItem?.cancel()
    }

    var nextDelay: Double {
        history.first?.finalDelay ?? 0
    }

    var retryBudgetLabel: String {
        "\(retryCount) / \(maxRetries)"
    }

    // MARK: - User intents

    func connect() {
        if state == .connected {
            disconnect(reason: "用户主动断开")
            return
        }
        guard state != .connecting else { return }

        resetTimers()
        retryCount = 0
        history = []
        state = .offline
        console.log("用户发起连接；重试预算重置为 0/\(maxRetries)", level: .info)
        attemptConnect()
    }

    func simulateWeakNetworkDrop() {
        guard state == .connected else { return }
        disconnect(reason: "模拟弱网丢包 · close code 1006")
    }

    func reset() {
        resetTimers()
        state = .offline
        retryCount = 0
        retryRemaining = 0
        history = []
        connectedSince = nil
        chaosEnabled = false
        console.clear()
    }

    // MARK: - State machine

    private func attemptConnect() {
        guard state != .exhausted else { return }
        resetTimers()
        state = .connecting
        attemptSerial += 1
        let serial = attemptSerial
        console.log("CONNECTING · attempt #\(serial)（模拟 TLS + WS upgrade）", level: .debug)

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.attemptSerial == serial else { return }
            // 72% handshake success: enough failures to exercise backoff, enough
            // successes to show recovery.
            if Double.random(in: 0...1) < 0.72 {
                self.handleConnected()
            } else {
                self.scheduleRetry(reason: "handshake timeout / 弱网丢包")
            }
        }
        handshakeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    private func handleConnected() {
        state = .connected
        connectedSince = Date()
        retryRemaining = 0
        console.log("CONNECTED · 握手成功，开始接收盘口快照", level: .success)
        if retryCount > 0 {
            console.log("本次恢复共消耗 \(retryCount) 次重试；预算仍保留，便于观察连续抖动", level: .info)
        }
        scheduleChaosDropIfNeeded()
    }

    private func disconnect(reason: String) {
        resetTimers()
        state = .offline
        connectedSince = nil
        console.log("DISCONNECTED · \(reason)", level: .warning)
    }

    private func scheduleRetry(reason: String) {
        resetTimers()
        retryCount += 1

        guard retryCount <= maxRetries else {
            state = .exhausted
            retryRemaining = 0
            console.log("EXHAUSTED · 已达到 \(maxRetries) 次上限，停止自动重连，等待人工介入", level: .error)
            return
        }

        let exponent = Double(retryCount - 1)
        let base = min(maxDelay, baseDelay * pow(2, exponent))
        let jitter = Double.random(in: 0.8...1.2)
        let delay = min(maxDelay, base * jitter)
        let record = RetryRecord(
            index: retryCount,
            reason: reason,
            baseDelay: base,
            jitter: jitter,
            finalDelay: delay
        )
        history.insert(record, at: 0)
        if history.count > 10 {
            history.removeLast(history.count - 10)
        }

        state = .backoff
        retryRemaining = delay
        console.log(
            "BACKOFF · \(reason)；base \(String(format: "%.2f", base))s × jitter \(record.jitterLabel) = \(String(format: "%.2f", delay))s",
            level: .warning
        )
        startCountdown()
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(tickCountdown),
            userInfo: nil,
            repeats: true
        )
        if let countdownTimer {
            RunLoop.main.add(countdownTimer, forMode: .common)
        }
    }

    @objc private func tickCountdown() {
        guard state == .backoff else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }
        retryRemaining = max(0, retryRemaining - 0.1)
        if retryRemaining <= 0.001 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            console.log("Backoff 结束，发起第 \(retryCount + 1) 次连接尝试", level: .debug)
            attemptConnect()
        }
    }

    private func resetTimers() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        chaosTimer?.invalidate()
        chaosTimer = nil
        handshakeWorkItem?.cancel()
        handshakeWorkItem = nil
    }

    private func scheduleChaosDropIfNeeded() {
        guard chaosEnabled, state == .connected else { return }
        chaosTimer?.invalidate()
        let interval = Double.random(in: 1.5...3.5)
        chaosTimer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(handleChaosDrop),
            userInfo: nil,
            repeats: false
        )
        if let chaosTimer {
            RunLoop.main.add(chaosTimer, forMode: .common)
        }
        console.log("弱网窗口：\(String(format: "%.1f", interval))s 后注入断线", level: .debug)
    }

    @objc private func handleChaosDrop() {
        guard chaosEnabled, state == .connected else { return }
        disconnect(reason: "弱网抖动 · 1006 abnormal closure")
        scheduleRetry(reason: "弱网抖动 · 1006")
    }
}


struct BookLevel: Identifiable, Equatable {
    let price: Double
    let size: Double

    var id: Double { price }
}

struct OrderBookSnapshot {
    let sequence: Int
    let bids: [BookLevel]
    let asks: [BookLevel]

    var bestBid: Double { bids.first?.price ?? 0 }
    var bestAsk: Double { asks.first?.price ?? 0 }
    var spread: Double { max(0, bestAsk - bestBid) }

    static func initial() -> OrderBookSnapshot {
        BookFactory.make(sequence: 0, mid: 42_000)
    }
}

enum BookFactory {
    static func make(sequence: Int, mid: Double) -> OrderBookSnapshot {
        let tick = 0.5
        let depth = 12
        var bids: [BookLevel] = []
        var asks: [BookLevel] = []
        bids.reserveCapacity(depth)
        asks.reserveCapacity(depth)

        for index in 1...depth {
            let bidPrice = ((mid - tick * Double(index)) * 10).rounded() / 10
            let askPrice = ((mid + tick * Double(index)) * 10).rounded() / 10
            let bidSize = (0.08 + Double((sequence * 13 + index * 7) % 100) / 30)
            let askSize = (0.08 + Double((sequence * 19 + index * 11) % 100) / 28)
            bids.append(BookLevel(price: bidPrice, size: bidSize))
            asks.append(BookLevel(price: askPrice, size: askSize))
        }
        return OrderBookSnapshot(sequence: sequence, bids: bids, asks: asks)
    }
}

/// Produces full snapshots on a background serial queue. In a real client this
/// is the `URLSessionWebSocketTask.receive` loop; swapping the source does not
/// change the throttle or the rendering code below.
final class OrderBookFeed {
    private let queue = DispatchQueue(label: "xclientlab.orderbook.feed", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var sequence = 0
    private var mid: Double = 42_000

    var onSnapshot: ((OrderBookSnapshot) -> Void)?

    func start(interval: TimeInterval = 0.012) {
        stop()
        sequence = 0
        mid = 42_000
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.emit()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func emit() {
        sequence += 1
        // Slow random walk plus a sine wobble, so the book visibly moves.
        mid += Double.random(in: -0.35...0.35) + sin(Double(sequence) / 14) * 0.12
        mid = min(max(mid, 41_000), 43_000)
        onSnapshot?(BookFactory.make(sequence: sequence, mid: mid))
    }
}

/// One-slot coalescing queue. Every producer write replaces the pending full
/// snapshot; the consumer sees at most one snapshot per display frame. Full
/// snapshots are safe to replace because each one already contains the whole
/// book. Incremental deltas would additionally need sequence-gap detection.
final class OrderBookPipeline {
    private let lock = NSLock()
    private var pending: OrderBookSnapshot?
    private var submittedCount = 0
    private var coalescedCount = 0

    func submit(_ snapshot: OrderBookSnapshot) {
        lock.lock()
        if pending != nil {
            coalescedCount += 1
        }
        pending = snapshot
        submittedCount += 1
        lock.unlock()
    }

    func take() -> OrderBookSnapshot? {
        lock.lock()
        let snapshot = pending
        pending = nil
        lock.unlock()
        return snapshot
    }

    func stats() -> (submitted: Int, coalesced: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (submittedCount, coalescedCount)
    }

    func reset() {
        lock.lock()
        pending = nil
        submittedCount = 0
        coalescedCount = 0
        lock.unlock()
    }
}

final class RawModeBox {
    private let lock = NSLock()
    private var raw = false

    var isRaw: Bool {
        lock.lock()
        defer { lock.unlock() }
        return raw
    }

    func setRaw(_ value: Bool) {
        lock.lock()
        raw = value
        lock.unlock()
    }
}

@MainActor
final class OrderBookViewModel: NSObject, ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case raw
        case throttled
        case diff

        var id: String { rawValue }

        var title: String {
            switch self {
            case .raw: return "全量直更"
            case .throttled: return "节流队列"
            case .diff: return "节流 + Diff"
            }
        }

        var detail: String {
            switch self {
            case .raw: return "每条推送都进主线程，SwiftUI 更新次数 = 推送次数"
            case .throttled: return "每帧最多消费一条最新全量，丢弃中间态"
            case .diff: return "每帧消费一条，并且只重建变化的价位"
            }
        }
    }

    @Published var mode: Mode = .diff {
        didSet {
            modeBox.setRaw(mode == .raw)
            if oldValue != mode {
                console.log("渲染策略切换 → \(mode.title)", level: .info)
            }
        }
    }

    @Published private(set) var isStreaming = false
    @Published private(set) var bids: [BookLevel] = []
    @Published private(set) var asks: [BookLevel] = []
    @Published private(set) var updatesReceived = 0
    @Published private(set) var updatesApplied = 0
    @Published private(set) var coalesced = 0
    @Published private(set) var lastDiffCount = 0
    @Published private(set) var lastApplyMs: Double = 0
    @Published private(set) var applySamples: [Double] = []
    @Published private(set) var refreshRate: Int = 60

    let console = LabLogStore()
    let hitch = HitchMonitor()

    private let feed = OrderBookFeed()
    private let pipeline = OrderBookPipeline()
    private let modeBox = RawModeBox()
    private var displayLink: CADisplayLink?
    private var startedAt: Date?
    private var lastStatsRefresh = Date.distantPast

    override init() {
        super.init()
        let initial = OrderBookSnapshot.initial()
        bids = initial.bids
        asks = initial.asks
        refreshRate = UIScreen.main.maximumFramesPerSecond
        console.log("就绪：12 档盘口，feed 约 83 条/s，渲染预算 \(refreshRate)Hz", level: .debug)
    }

    var spread: Double {
        let bestAsk = asks.first?.price ?? 0
        let bestBid = bids.first?.price ?? 0
        return max(0, bestAsk - bestBid)
    }

    var coalescedRatio: Double {
        guard updatesReceived > 0 else { return 0 }
        return Double(coalesced) / Double(updatesReceived)
    }

    var receivedPerSecond: Double {
        guard let startedAt, Date().timeIntervalSince(startedAt) > 0.1 else { return 0 }
        return Double(updatesReceived) / Date().timeIntervalSince(startedAt)
    }

    var appliedPerSecond: Double {
        guard let startedAt, Date().timeIntervalSince(startedAt) > 0.1 else { return 0 }
        return Double(updatesApplied) / Date().timeIntervalSince(startedAt)
    }

    func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true
        startedAt = Date()
        updatesReceived = 0
        updatesApplied = 0
        coalesced = 0
        lastDiffCount = 0
        applySamples = []
        pipeline.reset()
        modeBox.setRaw(mode == .raw)
        hitch.start()
        console.log("推送开启：\(mode.title)；目标 \(refreshRate)Hz 稳定", level: .success)

        let pipeline = self.pipeline
        let modeBox = self.modeBox
        feed.onSnapshot = { [weak self] snapshot in
            pipeline.submit(snapshot)
            if modeBox.isRaw {
                Task { @MainActor in
                    self?.applyRaw(snapshot)
                }
            }
        }
        feed.start()

        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(frameTick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link

        console.log("CADisplayLink 已挂载；preferred 60–120Hz，由系统按 ProMotion 能力调度", level: .debug)
    }

    func stopStreaming() {
        guard isStreaming else { return }
        feed.stop()
        feed.onSnapshot = nil
        displayLink?.invalidate()
        displayLink = nil
        isStreaming = false
        hitch.stop()
        console.log("推送停止；共收到 \(updatesReceived) 条，实际渲染 \(updatesApplied) 帧", level: .info)
    }

    func reset() {
        stopStreaming()
        pipeline.reset()
        bids = OrderBookSnapshot.initial().bids
        asks = OrderBookSnapshot.initial().asks
        updatesReceived = 0
        updatesApplied = 0
        coalesced = 0
        lastDiffCount = 0
        lastApplyMs = 0
        applySamples = []
        startedAt = nil
        hitch.reset()
        console.clear()
    }

    @objc private func frameTick(_ link: CADisplayLink) {
        guard isStreaming else { return }

        if mode != .raw, let snapshot = pipeline.take() {
            apply(snapshot)
        }

        refreshStatsIfNeeded()
    }

    private func applyRaw(_ snapshot: OrderBookSnapshot) {
        guard isStreaming else { return }
        let start = CFAbsoluteTimeGetCurrent()
        bids = snapshot.bids
        asks = snapshot.asks
        updatesReceived = pipeline.stats().submitted
        updatesApplied += 1
        lastDiffCount = snapshot.bids.count + snapshot.asks.count
        lastApplyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        appendSample(lastApplyMs)
    }

    private func apply(_ snapshot: OrderBookSnapshot) {
        let start = CFAbsoluteTimeGetCurrent()
        let oldBids = Dictionary(uniqueKeysWithValues: bids.map { ($0.price, $0.size) })
        let oldAsks = Dictionary(uniqueKeysWithValues: asks.map { ($0.price, $0.size) })

        var changed = 0
        let newBids = snapshot.bids.map { level -> BookLevel in
            if oldBids[level.price] == level.size { return level }
            changed += 1
            return level
        }
        let newAsks = snapshot.asks.map { level -> BookLevel in
            if oldAsks[level.price] == level.size { return level }
            changed += 1
            return level
        }

        if mode == .diff {
            // Only publish when something actually changed. A real incremental
            // feed would use the same rule plus sequence-gap handling.
            if changed > 0 {
                bids = newBids
                asks = newAsks
            }
            lastDiffCount = changed
        } else {
            bids = newBids
            asks = newAsks
            lastDiffCount = snapshot.bids.count + snapshot.asks.count
        }

        updatesApplied += 1
        lastApplyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        appendSample(lastApplyMs)
        let stats = pipeline.stats()
        updatesReceived = stats.submitted
        coalesced = mode == .raw ? 0 : stats.coalesced
    }

    private func refreshStatsIfNeeded() {
        guard Date().timeIntervalSince(lastStatsRefresh) > 0.35 else { return }
        lastStatsRefresh = Date()
        let stats = pipeline.stats()
        updatesReceived = stats.submitted
        if mode != .raw {
            coalesced = stats.coalesced
        }
    }

    private func appendSample(_ value: Double) {
        applySamples.append(value)
        if applySamples.count > 60 {
            applySamples.removeFirst(applySamples.count - 60)
        }
    }
}
