import Foundation
import UIKit

struct DebugSkill: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let tags: [String]
    let markdown: String
    let accent: UIColor
}

enum DebugSkillLibrary {
    static let all: [DebugSkill] = [
        DebugSkill(
            id: "lldb-async-crash",
            title: "LLDB 异步崩溃取证",
            subtitle: "process status 轮询、interrupt 时机、批量命令串联。",
            category: "SKILL · DEBUGGER",
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
