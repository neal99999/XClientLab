import Combine
import Foundation
import UIKit

@MainActor
final class UAFScenarioViewModel: NSObject, ObservableObject {
    enum Stage: String {
        case idle = "IDLE"
        case armed = "COUNTDOWN"
        case firing = "WAITING FOR TRAP"
    }

    @Published private(set) var stage: Stage = .idle
    @Published private(set) var countdown: Int = 3

    let console = LabLogStore()
    private var countdownTimer: Timer?
    private var crashSource: DispatchSourceTimer?

    deinit {
        countdownTimer?.invalidate()
        crashSource?.cancel()
    }

    func arm() {
        guard stage == .idle else { return }
        stage = .armed
        countdown = 3
        console.log("ARMED：3 秒后向 0x1d 执行 memcpy（该地址永远不可写）", level: .error)
        console.log("DispatchSource 回调已持有悬垂指针，模拟对象释放瞬间的上下文", level: .warning)

        countdownTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(tickCountdown),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    func cancel() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        crashSource?.cancel()
        crashSource = nil
        stage = .idle
        countdown = 3
        console.log("已取消。没有代码被执行，进程仍然安全。", level: .info)
    }

    func resetLog() {
        console.clear()
    }

    @objc private func tickCountdown() {
        if countdown > 1 {
            countdown -= 1
            console.log("倒计时 \(countdown)…", level: .debug)
            return
        }

        countdownTimer?.invalidate()
        countdownTimer = nil
        fire()
    }

    private func fire() {
        stage = .firing
        console.log("排入 global(userInitiated) 队列：memcpy(dst: 0x1d, src: [0x41 × 64])", level: .error)
        console.log("如果 Xcode 已 attach，下一个断点会停在 libsystem_platform 的 memmove", level: .info)
        crashSource = CrashProbe.armSystemStackUseAfterFree()
    }
}

import Foundation

@MainActor
final class RaceScenarioViewModel: NSObject, ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case unsafe
        case locked

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .unsafe: return "无锁（数据竞争）"
            case .locked: return "NSLock（正确）"
            }
        }
    }

    enum Scale: Int, CaseIterable, Identifiable {
        case small = 50000
        case medium = 150_000
        case large = 300_000

        var id: Int {
            rawValue
        }

        var title: String {
            switch self {
            case .small: return "50k / 线程"
            case .medium: return "150k / 线程"
            case .large: return "300k / 线程"
            }
        }
    }

    let threadCount = 8

    @Published var mode: Mode = .unsafe
    @Published var scale: Scale = .medium
    @Published private(set) var isRunning = false
    @Published private(set) var observed: Int64 = 0
    @Published private(set) var expected: Int64 = 0
    @Published private(set) var lostWrites: Int64 = 0
    @Published private(set) var lastDurationMs: Double = 0
    @Published private(set) var runCount = 0

    let console = LabLogStore()

    var expectedForCurrentScale: Int64 {
        Int64(threadCount * scale.rawValue)
    }

    func run() {
        guard !isRunning else { return }
        isRunning = true
        let mode = mode
        let expected = expectedForCurrentScale
        let iterations = scale.rawValue

        console.log(
            "启动 \(threadCount) 线程 × \(LabFormat.integer(iterations)) 次 \(mode == .unsafe ? "非原子" : "加锁")自增，期望 \(LabFormat.integer(Int(expected)))",
            level: mode == .unsafe ? .warning : .info
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let counter = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
            counter.initialize(to: 0)
            let lock = NSLock()
            let start = CFAbsoluteTimeGetCurrent()

            DispatchQueue.concurrentPerform(iterations: self.threadCount) { _ in
                for _ in 0 ..< iterations {
                    if mode == .locked {
                        lock.lock()
                        counter.pointee += 1
                        lock.unlock()
                    } else {
                        // Read-modify-write with no synchronization. Two cores can
                        // load the same old value and both write old + 1.
                        counter.pointee += 1
                    }
                }
            }

            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let observed = counter.pointee
            counter.deallocate()

            DispatchQueue.main.async {
                self.observed = observed
                self.expected = expected
                self.lostWrites = max(0, expected - observed)
                self.lastDurationMs = elapsedMs
                self.runCount += 1
                self.isRunning = false

                if mode == .unsafe {
                    if self.lostWrites > 0 {
                        self.console.log(
                            "竞争命中：丢失 \(LabFormat.integer(Int(self.lostWrites))) 次自增（\(String(format: "%.1f", elapsedMs))ms）",
                            level: .error
                        )
                        self.console.log(
                            "这是「偶现」的根源：结果取决于调度与缓存行，不是每次都会丢同样多",
                            level: .debug
                        )
                    } else {
                        self.console.log(
                            "本次侥幸没有丢写；重复运行或提高规模后大概率复现——这正是竞态难以排查的原因",
                            level: .warning
                        )
                    }
                } else {
                    self.console.log(
                        "加锁后 observed == expected（\(String(format: "%.1f", elapsedMs))ms），用吞吐换正确性",
                        level: .success
                    )
                }
            }
        }
    }

    func reset() {
        observed = 0
        expected = 0
        lostWrites = 0
        lastDurationMs = 0
        runCount = 0
        console.clear()
    }

    func armStomp() {
        console.log("WARNING：8 个 worker 将向已 munmap 的 16KB 区域持续写入", level: .error)
        console.log("第一个 store 就会触发 EXC_BAD_ACCESS；线程竞争只影响谁先踩中", level: .warning)
        CrashProbe.triggerConcurrentStomp()
    }
}
