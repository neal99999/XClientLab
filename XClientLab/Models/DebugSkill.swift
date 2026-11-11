import Foundation
import UIKit

/// Skill 的一级分类，对应 4.1 页面顶部的筛选标签。
///
/// 分类只描述「排查域」，不参与 Skill 的检索与渲染；`category` 仍然是卡片
/// 上的英文 kicker（如 `SKILL · DEBUGGER`）。
enum DebugSkillGroup: String, CaseIterable {
    case crash = "异常崩溃"
    case performance = "性能卡顿"
    case concurrency = "并发与网络"
    case engineering = "工程质量"

    var accent: UIColor {
        switch self {
        case .crash: return LabUI.coral
        case .performance: return LabUI.amber
        case .concurrency: return LabUI.cyan
        case .engineering: return LabUI.mint
        }
    }
}

struct DebugSkill: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let group: DebugSkillGroup
    let tags: [String]
    let markdown: String
    let accent: UIColor
}

enum DebugSkillLibrary {
    static let all: [DebugSkill] = legacySkills + extendedSkills
}

// MARK: - 既有 Skill（场景 2.x / 4.1）

private extension DebugSkillLibrary {
    static var legacySkills: [DebugSkill] {
        [
            DebugSkill(
                id: "lldb-async-crash",
                title: "LLDB 异步崩溃取证",
                subtitle: "process status 轮询、interrupt 时机、批量命令串联。",
                category: "SKILL · DEBUGGER",
                group: .crash,
                tags: ["LLDB", "Async", "Crash"],
                markdown: """
                # LLDB 异步崩溃取证

                ## 什么时候用

                当 Crash 发生在 `DispatchSource`、`Timer` 或网络回调里，Xcode 刚 attach 时线程状态可能仍是 `running`。不要连续 `continue`，按下面的通道纪律执行。

                ## 通道纪律（最重要）

                - **先问状态**：每次 attach 或异常暂停后，第一件事是 `process status`。
                - **running 不等于 stopped**：如果 status 显示 running，先 `process interrupt`，再轮询，直到 state = stopped。
                - **批量前先固定现场**：`thread list`、`bt all`、寄存器读取一次完成，避免边跑边取。
                - **resume 只一次**：取证结束后统一 `process continue`，不要在每条命令后重复 resume。

                ## 批处理模板

                ```lldb
                process status
                process interrupt
                process status
                thread list
                bt all
                register read x0 x1 x2 x3
                image lookup -a $pc
                process continue
                ```

                ## 判读技巧

                - 顶部是 `libsystem` / `libdispatch` 时，先关闭 Hide System Libraries，再找第一个业务闭包。
                - `x0` 常是 `memcpy` 的目标地址；`0x1d` 这类低位地址基本可以直接判定为野指针。
                - `image lookup -a $pc` 输出 `binary + offset`，配合 dSYM 反查源码行。
                - 异步队列崩溃不要只看 Crashed Thread，`bt all` 里其他线程可能持有锁或正在释放对象。

                ## 反模式

                ```text
                (lldb) process continue
                (lldb) bt all          ← 此时进程已 running，命令会失败或挂起
                (lldb) process continue ← 重复 resume，现场被破坏
                ```
                """,
                accent: LabUI.cyan
            ),

            DebugSkill(
                id: "build-test-trace",
                title: "Build / Test / Trace 闭环",
                subtitle: "xcodebuild、simctl、xcresult 的最小可用自动化。",
                category: "SKILL · AUTOMATION",
                group: .engineering,
                tags: ["xcodebuild", "simctl", "xcresult"],
                markdown: """
                # Build / Test / Trace 闭环

                ## 目标

                让「改代码 → 构建 → 跑测试 → 抓 trace」成为可重复的一条命令链，而不是在 Xcode GUI 里点五次。

                ## 环境探测

                ```bash
                xcodebuild -version
                xcrun simctl list devices available
                xcodebuild -project XClientLab.xcodeproj -list
                ```

                ## 构建

                ```bash
                xcodebuild -project XClientLab.xcodeproj \\
                  -scheme XClientLab \\
                  -sdk iphonesimulator \\
                  -destination 'generic/platform=iOS Simulator' \\
                  -derivedDataPath ./DerivedData \\
                  CODE_SIGNING_ALLOWED=NO build
                ```

                ## 安装与启动

                ```bash
                xcrun simctl boot "iPhone 16 Pro" || true
                xcrun simctl install booted ./DerivedData/Build/Products/Debug-iphonesimulator/XClientLab.app
                xcrun simctl launch --console booted e88ebfa25316fd8c.XClientLab
                ```

                ## 通道纪律

                - 每条命令设置 timeout，构建失败时先看第一处 `error:`，不要 dump 全量日志。
                - `.xcresult` 用 `xcrun xcresulttool get --format json` 按需取字段。
                - MCP 只负责执行与整理，是否重跑由人根据产物哈希/时间戳决定。

                ## 面试一句话

                「自动化不是把 GUI 命令抄一遍，而是把每一步的输入、产物、失败原因变成可审计的结构化数据。」
                """,
                accent: LabUI.mint
            ),

            DebugSkill(
                id: "memory-graph",
                title: "Memory Graph 追泄漏",
                subtitle: "从 footprint 到 retain path 的取证路径。",
                category: "SKILL · MEMORY",
                group: .performance,
                tags: ["Memory Graph", "Leaks", "Retain Cycle"],
                markdown: """
                # Memory Graph 追泄漏

                ## 先区分三件事

                1. **常驻缓存**：应该存在，只是比预期大。
                2. **瞬时峰值**：短命对象叠加，Allocations 的 Transient 会很高。
                3. **真泄漏**：对象已经不该活，却仍能从某个 root 走到它。

                ## 取证顺序

                ```text
                1. Xcode → Debug Memory Graph
                2. 选中可疑对象，查看 Malloc Stack / Backtrace
                3. 顺着 retain path 找到持有者（VC、单例、闭包、Timer、Notification）
                4. 用 Allocations 的 Generation 对比修复前后
                ```

                ## 常见根因

                - `Timer.scheduledTimer` 的 target 强持有 VC，VC 又持有 Timer。
                - `NotificationCenter.addObserver(forName:object:queue:using:)` 忘记移除 token。
                - `DispatchSource` 的 event handler 捕获 self，source 又被 self 持有。
                - 闭包属性没有 `[weak self]`，形成 self → closure → self。

                ## 验收

                修复后不只看 footprint 下降，还要确认：对象 deinit 被调用、Generation 不再增长、关键路径无新增 hitch。
                """,
                accent: LabUI.violet
            )
        ]
    }
}

// MARK: - AI-Native 扩展 Skill（性能 / 并发 / 工程）

private extension DebugSkillLibrary {
    static var extendedSkills: [DebugSkill] {
        [
            DebugSkill(
                id: "hitch-stall-profiler",
                title: "主线程卡顿与掉帧取证",
                subtitle: "HitchMonitor 指标模型、Time Profiler 定性与分块让出治理。",
                category: "SKILL · PERFORMANCE",
                group: .performance,
                tags: ["CADisplayLink", "HitchMonitor", "Time Profiler", "Chunking"],
                markdown: """
                # 主线程卡顿与掉帧取证

                ## 什么时候用

                列表滑动发涩、点击后长时间无响应、CADisplayLink 回调间隔突然拉长时使用。先拿客观指标再决定是否异步化——盲目 `DispatchQueue.global().async` 只会把卡顿换成数据竞争。

                ## 指标模型（HitchMonitor）

                - **Worst Hitch**：单次最长主线程阻塞。>100ms 用户可感知，>500ms 视为冻结。
                - **Blocked Total**：采样周期内主线程累计挂起时长。
                - **Hitch Ratio**：每秒掉帧时间，工业级优秀线 <5ms/s。
                - **帧预算**：60Hz 为 16.6ms/帧，120Hz ProMotion 仅 8.3ms/帧。
                - `HitchMonitor` 基于 `CADisplayLink` 的时间戳差值计算上述指标，不依赖 Instruments。

                ## Time Profiler 取证

                ```bash
                xctrace record --template 'Time Profiler' --attach XClientLab --time-limit 5s --output ./HitchProfile.trace
                ```

                ## 先定性，再动手

                - **CPU Bound**：主线程 CPU 接近 100%，热点是全量 JSON 反序列化、正则回溯、大数组排序。
                - **Wait Bound**：CPU 不高但单次耗时极长，热点是主线程等锁、同步磁盘或网络 IO。
                - 两者治理方向相反：CPU Bound 拆任务，Wait Bound 挪 IO，不能一刀切。

                ## 治理模板：分块 + 协同让出

                ```swift
                Task.detached(priority: .userInitiated) {
                    let chunkSize = 500
                    for chunk in items.chunked(into: chunkSize) {
                        try Task.checkCancellation()
                        let parsed = chunk.map(parseItem)
                        await MainActor.run { self.append(parsed) }
                        await Task.yield()   // 协同让出，避免饿死主线程
                    }
                }
                ```

                ## 反模式

                - 看到卡顿先套 async，结果 UI 时序错乱、数据竞争爆发。
                - 在主线程反复创建 `NSRegularExpression`，每次初始化都极其昂贵。
                - 只优化一次 runloop，不验证 Worst Hitch 与 Hitch Ratio 是否真的下降。

                ## 验收

                - Worst Hitch 从 >500ms 降到 <50ms，Hitch Ratio <5ms/s。
                - 分块任务支持取消，页面退出后没有后台空转。
                - 修复前后用同一段压测数据对比，拒绝「感觉快了」。
                """,
                accent: LabUI.amber
            ),

            DebugSkill(
                id: "concurrency-race-debug",
                title: "TSan 多线程数据竞争取证",
                subtitle: "TSan 报告解码、读写对称锁原则与 AB-BA 死锁治理。",
                category: "SKILL · CONCURRENCY",
                group: .concurrency,
                tags: ["Thread Sanitizer", "Data Race", "Lock Ordering", "os_unfair_lock"],
                markdown: """
                # TSan 多线程数据竞争取证

                ## 什么时候用

                计数偶发丢失、集合随机崩溃、App 高概率卡死却无崩溃日志时，先用 Thread Sanitizer 把「偶发」变成「确定性报告」。

                ## TSan 报告特征提取

                ```text
                WARNING: ThreadSanitizer: data race (pid=1234)
                  Write of size 8 at 0x000100234 by thread T2:
                    #0 OrderBookViewModel.update() OrderBook.swift:45
                  Previous read of size 8 at 0x000100234 by thread T1:
                    #0 OrderBookViewController.render() OrderBook.swift:80
                ```

                - 先看**两个线程指向的地址是否相同**：同地址且无同步栅栏，即判定为竞争。
                - 再看**读与写是否落在同一把锁的作用域**：只锁写、裸读是最高频错误。
                - 最后看**业务帧**：`libdispatch` 只是搬运工，根因在闭包里的共享状态。

                ## 读写对称原则

                - 铁律：读和写必须共享同一把锁，任何一侧裸读都等于没锁。
                - 用 `defer` 保证异常路径也能解锁，禁止散落多条手写 `unlock()`。

                ```swift
                // 反例：写时加锁、读时裸读，扩容期间读者可能拿到半成品内存
                func append(_ item: Int) {
                    lock.lock()
                    items.append(item)
                    lock.unlock()
                }

                func value(at index: Int) -> Int {
                    return items[index]   // SIGSEGV 高发点
                }

                // 正解：读写完全对称
                func value(at index: Int) -> Int {
                    lock.lock()
                    defer { lock.unlock() }
                    return items[index]
                }
                ```

                ## 单调锁顺序杜绝 AB-BA 死锁

                - 线程 1 持有 A 等 B，线程 2 持有 B 等 A —— 高频并发下必然死锁。
                - 约定全局锁层级，所有线程只能按「小序号 → 大序号」申请，禁止逆序。
                - 跨层访问必须降级为单锁、串行队列或 actor。
                - 不可重入锁（`os_unfair_lock`）禁止同一线程重复加锁。

                ```swift
                enum LockOrder {
                    static let account = 0
                    static let order = 1   // 只允许先拿 account 再拿 order
                }
                ```

                ## 现代 Swift 的收敛路径

                - 共享状态优先塞进 `actor` 或 `@MainActor`，让编译器做 Data Race Safety 检查。
                - 高频只读场景用 `OSAllocatedUnfairLock` 保护小块临界区，别把 IO 放进锁里。
                - 并发队列的写操作要么加 `barrier`，要么直接改为串行队列。

                ## 验收

                - TSan 全量跑测试 0 warning。
                - lostWrites 为 0，同时 unsafe 对照实验必须能看到丢写，证明检测本身有效。
                - 压测 10 分钟无 AB-BA 死锁、无集合越界。
                """,
                accent: LabUI.cyan
            ),

            DebugSkill(
                id: "network-race-guard",
                title: "弱网假死与乱序状态竞态",
                subtitle: "5s 心跳判死、Jitter 重连、Sequence 版本凭证与单向状态机。",
                category: "SKILL · NETWORK",
                group: .concurrency,
                tags: ["Heartbeat", "Jitter", "Sequence", "State Machine"],
                markdown: """
                # 弱网假死与乱序状态竞态

                ## 什么时候用

                电梯、地铁、Wi-Fi 切换后连接「还在」却收不到数据；或订单状态从 filled 被迟到的旧包回滚成 pending。前者是假连接，后者是乱序竞态。

                ## 第一道防线：应用层主动心跳

                - 只依赖 Reachability 不够：物理断网时 TCP 可能数分钟才超时。
                - 每 5s 发送轻量 Ping，连续 2 次丢失 Pong 立即判死并进入重连。
                - 10s 内没有任何下行流量同样强制自愈，避免半开连接。
                - 重连用指数退避 + 抖动，防止恢复瞬间所有客户端同时打垮网关。

                ```text
                delay = min(maxDelay, base * 2^retry) ± jitter
                ```

                ```swift
                func scheduleReconnect(attempt: Int) {
                    let base = 0.5, cap = 8.0
                    let raw = min(cap, base * pow(2.0, Double(attempt)))
                    let jitter = Double.random(in: -0.15...0.15) * raw
                    reconnectWork?.cancel()
                    reconnectWork = Task {
                        let nanos = UInt64((raw + jitter) * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: nanos)
                        await connect()
                    }
                }
                ```

                ## 第二道防线：单调 Sequence 凭证

                - HTTP 与 WS 双通道合并时，迟到包会覆盖新状态。
                - 模型必须带单调递增 `sequence`，只有严格大于当前值才允许应用。
                - 相等也要丢弃：重复推送不应触发二次副作用。

                ```swift
                guard event.sequence > order.sequence else {
                    logger.warning("丢弃乱序事件 seq=\\(event.sequence)")
                    return
                }
                ```

                ## 单向不可逆状态机

                - 允许：created → pending → partiallyFilled → filled / cancelled。
                - 进入 filled 或 cancelled 终态后，任何通道的变更一律拒绝。
                - 状态迁移用 `switch` 穷举，未知迁移走 `assertionFailure`，不要静默吞掉。

                ## 写入幂等与超时

                - 查询接口可在超时后受控重试；下单、撤单、转账绝不自动重试。
                - 写入必须带客户端 `clientOrderId` 做幂等兜底，超时提示用户手动查单。

                ## 验收

                - 拔网 5s 内 UI 进入重连态，恢复后首包全量对齐。
                - 注入 seq 乱序包，界面无状态回退、无重复成交提示。
                - 写入接口超时后的自动重试次数为 0。
                """,
                accent: LabUI.cyan
            ),

            DebugSkill(
                id: "submit-pr-workflow",
                title: "PR 质量保障全流程",
                subtitle: "三轮收敛、风格降噪、致命缺陷审查、风险分级与人类掌舵门禁。",
                category: "SKILL · WORKFLOW",
                group: .engineering,
                tags: ["submit-pr", "Code Review", "Risk Control", "Human Gate"],
                markdown: """
                # PR 质量保障全流程

                ## 什么时候用

                功能写完、准备推分支之前。对应仓库 `.claude/workflows/submit-pr.md`：目标不是「跑一遍命令」，而是让交付过程可解释、可审计、人类可掌舵。

                ## 五阶段流水线

                - **阶段一 基线**：确认仓库根、分支、`git status` 与 `git diff --stat`。
                - **阶段二 自测门禁**：`make lint`、`make test`、`make format-check`，任一 Error 立即中止。
                - **阶段三 独立预审**：换一个干净上下文，只读 `git diff`，按致命缺陷维度挑错。
                - **阶段四 人类掌舵**：输出结构化 PR 报告，等待人工回复「确认」。
                - **阶段五 推送提 PR**：确认后才执行 `git push` 与 `gh pr create`。

                ## 三轮收敛法则

                - 第 1 轮看全局：需求达成度、模块兼容、接口破坏面。
                - 第 2 轮看局部：只审本轮改动文件，验证上一轮 Blocker 是否真正修掉。
                - 第 3 轮只验门禁：不再引入新意见，测试跑绿即收敛。
                - 3 轮仍未收敛就停止自动修改，交人类仲裁，禁止无限循环。

                ## 降噪：把风格问题交给机器

                - 缩进、换行、命名长度交给 SwiftFormat 与 SwiftLint，AI 不再评论。
                - 泛泛重构建议（「可以拆成三个方法」）没有明确收益一律不报。
                - 只允许两类发现：`[Blocker 阻断项]` 与 `[Risk 潜在风险]`，且必须带文件与行号。

                ## 只审这四类致命缺陷

                - **资金与精度**：Double 混算金额、舍入方向错误。
                - **线程与死锁**：非原子共享状态、锁顺序反转、主线程同步 IO。
                - **生命周期**：闭包强引用环、Timer 与通知未注销。
                - **幂等与重试**：下单无条件重试、缺少 clientOrderId 兜底。

                ## 风险分级

                - 低风险：纯 UI、Demo、文档、测试，单人自查即可。
                - 中风险：普通业务流、非核心接口封装，至少 1 位同行评审。
                - 高风险：TradingCore、并发锁、数据库迁移、鉴权加密，双人审批 + 灰度。

                ## 人类掌舵门禁

                - 报告必须包含：分支、改动统计、自测证据、风险等级、拟定标题与描述。
                - 未获得明确「确认」前，严禁 `git push` 或 `gh pr create`。
                - Agent 可以准备一切，但不能替人类按下合并按钮。

                ## 反模式

                - 带 lint error 提 PR，把门禁压力丢给 CI。
                - 让写代码的同一上下文给自己做审查，结论必然偏乐观。
                - 把风险分级当形式，高风险改动不设灰度直接合入。
                """,
                accent: LabUI.mint
            )
        ]
    }
}

enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case quote(String)
    case code(String)
    case divider
}

enum MarkdownLiteParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(code.joined(separator: "\n")))
                    code.removeAll()
                    inCode = false
                } else {
                    flushParagraph()
                    inCode = true
                }
                continue
            }

            if inCode {
                code.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if line == "---" {
                flushParagraph()
                blocks.append(.divider)
                continue
            }

            if line.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading(3, String(line.dropFirst(4))))
                continue
            }
            if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(2, String(line.dropFirst(3))))
                continue
            }
            if line.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.heading(1, String(line.dropFirst(2))))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
                continue
            }
            if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst(2))))
                continue
            }
            paragraph.append(line)
        }

        if inCode, !code.isEmpty {
            blocks.append(.code(code.joined(separator: "\n")))
        }
        flushParagraph()
        return blocks
    }
}
