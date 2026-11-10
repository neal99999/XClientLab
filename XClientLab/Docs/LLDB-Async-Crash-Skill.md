# LLDB 异步崩溃取证 Skill

这份文档对应 App 内「AI-Native → 4.1 → LLDB 异步崩溃取证」，也是 2.1 系统栈 UAF 场景的现场操作手册。

## 1. 为什么异步崩溃难查

同步崩溃通常停在业务代码里，调用栈完整。异步崩溃不同：

- 闭包或 `DispatchSource` 的回调在后台队列执行，Crashed Thread 只剩 `libdispatch` / `libsystem`。
- 对象可能在回调触发前已经被释放，业务帧被优化或根本不在栈上。
- Xcode attach 时进程可能仍是 `running`，直接 `bt all` 会失败、挂起，甚至破坏现场。

所以异步崩溃的第一原则不是「敲更多命令」，而是「先确认进程状态，再一次性固定现场」。

## 2. 通道纪律

| 步骤 | 命令 | 目的 |
| --- | --- | --- |
| 1 | `process status` | 确认 running / stopped |
| 2 | `process interrupt` | 仅在 running 时执行，暂停进程 |
| 3 | `process status` | 轮询到 stopped，最多重试若干次 |
| 4 | `thread list` | 建立线程索引，找到 Crashed Thread |
| 5 | `bt all` | 一次取全线程栈，避免边跑边取 |
| 6 | `register read x0 x1 x2 x3` | 取函数参数，尤其 `memcpy` 的 dst/src/len |
| 7 | `image lookup -a $pc` | 把 PC 映射到 binary + offset |
| 8 | `process continue` | 只 resume 一次 |

### 最小批处理模板

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

如果 `process status` 已经是 `stopped`，跳过 interrupt 和轮询；如果轮询超时，不要继续发 `bt all`，先回到 `process status`，确认是否 attach 到了错误进程。

## 3. 0x1d 现场怎么读

2.1 场景的崩溃是：

```text
EXC_BAD_ACCESS (SIGSEGV)
KERN_INVALID_ADDRESS at 0x000000000000001d
```

`0x1d` 是极低地址，几乎不可能是合法对象；它通常意味着：

- 指针被截断、被写成小整数，或对象释放后内存被复用。
- `memcpy` 的目标地址来自已经失效的引用。

调用栈常见形态：

```text
_platform_memmove
_platform_memmove$VARIANT$Haswell
_dispatch_client_callout
_dispatch_source_invoke
_dispatch_source_timer_activate
```

判读顺序：

1. 先看 Crashed Thread 顶部的 `memmove` / `memcpy`，确认是内存写。
2. `register read` 看 `x0`（dst）、`x1`（src）、`x2`（len）。`x0 = 0x1d` 直接指向野指针。
3. 关掉 Hide System Libraries，找第一个业务闭包。它可能在 `_dispatch_client_callout` 的参数里，也可能已经被内联。
4. `bt all` 看是否有其他线程正在释放同一对象、持有锁或执行 `munmap`。
5. `image lookup -a $pc` 得到 offset，再用 dSYM 反查源码行。
6. 如果栈里只有系统帧，打开 Memory Graph / Malloc Stack，确认对象生命周期。

## 4. DispatchSourceTimer UAF 的典型成因

```swift
final class Ticker {
    private var source: DispatchSourceTimer?
    private let payload = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            memcpy(self.payload, self.payload, 64) // payload 可能已释放
        }
        timer.schedule(deadline: .now() + 0.5)
        timer.resume()
        source = timer
    }

    deinit {
        source?.cancel()
        payload.deallocate()
    }
}
```

问题不在 `DispatchSource` 本身，而在：

- `deinit` 里 `cancel` 之后没有等待 cancellation handler 完成。
- 回调已经在队列里排队，`payload` 先被释放。
- 捕获列表、`self` 生命周期和 source 生命周期没有对齐。

修复方向：

- 用 `setCancelHandler` 统一释放资源，确保 cancel 完成后才 deallocate。
- 回调内使用强引用快照，或把资源所有权收敛到同一个 actor / 串行队列。
- 用 `DispatchSourceTimer` 的 `cancel` 状态做 guard，不要在 deinit 里裸释放回调还会用的内存。
- 对共享可变状态用锁、串行队列或 actor，避免「释放」和「使用」并发。

## 5. 反模式

```text
(lldb) process continue
(lldb) bt all          ← 进程已 running，命令失败或挂起
(lldb) process continue ← 重复 resume，现场被破坏
```

其他常见错误：

- attach 后不看 `process status`，直接批量命令。
- 只取 Crashed Thread，不看 `bt all`。
- 看到 `libsystem` 就断定是系统 bug，不找业务闭包。
- 崩溃后继续点 UI，破坏现场后再取证。
- 把 `0x1d` 当成真实地址去 `memory read`，而不是当成野指针信号。

## 6. 与 Xcode MCP 的结合

App 内 4.1 的 `MCPChannelViewModel` 把上面的纪律固化成状态机：

```text
IDLE → RUNNING → INTERRUPTING → STOPPED → BATCHING → DONE
```

守卫规则：

- `process status` 未确认 stopped 前，拒绝 `bt all`、`register read` 等取证命令。
- 运行中只允许 `process interrupt` / `process status`，其他命令计数为 rejected。
- 一次取证只允许一次 `process continue`，防止重复 resume。
- 每条命令有 timeout，失败后回到状态查询，不盲目重试。

对应到真实 MCP 工具时，建议把能力拆成：

| 工具 | 作用 | 风险 |
| --- | --- | --- |
| `xcode.build` | 构建并返回结构化错误 | 低 |
| `xcode.test` | 跑测试并解析 xcresult | 低 |
| `lldb.status` | 查询进程状态 | 低 |
| `lldb.interrupt` | 暂停进程 | 中 |
| `lldb.batch` | 在 stopped 状态下执行白名单命令 | 中 |
| `lldb.resume` | 恢复进程，单次 | 高 |

关键不是「让模型直接操作 Xcode」，而是「让模型只能沿着有状态守卫的通道操作」。

## 7. 面试一句话

> 异步崩溃的难点不是命令本身，而是现场时序。先 status，再 interrupt，轮询到 stopped，批量固定现场，最后只 resume 一次；把这条纪律写成状态机，才是 AI MCP 的正确接入方式。
