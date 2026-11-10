# XClientLab 面试演示脚本

目标：15–20 分钟内，让面试官看到「能复现 → 能观测 → 能归因 → 能改造」的完整闭环，而不是只展示几个 API。

---

## 0. 开场（1 分钟）

一句话定位：

> 这是一个 iOS 性能与稳定性 Sandbox。每个场景都先故意制造一个可重复的异常，再用 Instruments / LLDB / 指标面板拿出证据，最后说明 AI MCP 如何把取证过程工程化。

工程采用 UIKit + MVVM + Combine，页面全部代码构建、约束用 SnapKit，没有 SwiftUI / Storyboard；现场可以直接打开 Xcode Debug View Hierarchy 讲真实 UIView 树。底部五个 Tab 对应五个能力面：性能、异常、交易所、AI-Native、架构（架构为加分项，可最后用 2 分钟讲）。

---

## 1. 性能优化（4 分钟）

### 1.1 主线程卡顿（Time Profiler）

进入「性能优化 → 1.1 主线程 JSON 卡顿」。

操作：

1. 强度选「极端」。
2. 点击「制造主线程压力」。
3. 观察页面顶部的 worst hitch、blocked 总时长和逐轮 MiniBar。
4. 同时用 Xcode Instruments 的 Time Profiler attach，录制 5 秒。

代码里故意保留的反模式：

- `JSONSerialization.jsonObject` 解析 6,000 条记录的 JSON，全部在主线程。
- `NSRegularExpression` 对整段字符串做全量匹配，循环 12 轮。
- 没有分块、没有取消检查、没有后台队列。

讲解点：

> 这不是「不会用后台队列」，而是为了给 Time Profiler 一个干净、确定的 main thread 样本。真实修复是：分块 + `Task.detached`/自定义队列 + 增量解析 + 可取消。

证据：

- 极端档单轮 >500ms，页面会记录每一轮的 `durationMs`。
- Time Profiler 中主线程被 `JSONSerialization` / `NSRegularExpression` 占满。
- HitchMonitor 通过 CADisplayLink 统计帧间隔，估算 dropped frames。

### 1.2 分配锯齿（Allocations）

进入「1.2 分配风暴」。

操作：

1. 强度选「极端」。
2. 点击开始，页面每 80ms 分配 20 个 256KB buffer，并持续产生 600 个短命 `QuoteTick`。
3. 观察 footprint Sparkline 的锯齿和 Peak/Churn 指标。
4. 在 Allocations 中标记 Generation，对照峰值前后。

讲解点：

> 长列表本身不是问题，问题是滚动期间叠加的瞬时大对象。`LazyVStack` 只减少视图创建，不会阻止业务层的瞬时分配。修复方向是对象池、分页、降采样和在滚动时暂停非关键分配。

面试官追问「怎么区分缓存和泄漏」：

> 看 retain path，而不是只看 footprint。缓存有明确的上限和淘汰策略；泄漏是对象已经不该活，却仍能从 root 走到它。

---

## 2. 异常与疑难攻坚（4 分钟）

### 2.1 系统栈黑盒 Crash（UAF / 0x1d）

进入「异常 → 2.1 系统栈 UAF」。

操作：

1. 指出警告卡片：这是一个**真的会崩溃**的实验。
2. 点击「Arm UAF」，3 秒倒计时后，`DispatchSourceTimer` 在回调里对地址 `0x1d` 执行 `memcpy`。
3. App 崩溃，Xcode 停在 `_platform_memmove` / `_dispatch_client_callout` 等系统帧。
4. 崩溃后重新 Run，回到页面查看内置取证报告，点击复制。

讲解点：

> 真实线上 Crash 经常只剩系统库栈：`_platform_memmove`、`_dispatch_source_invoke`。如果只看 Crashed Thread，会误以为是系统 bug；实际上第一帧业务闭包已经被优化掉，或者对象在回调前被释放。

LLDB 批处理顺序（页面里也有）：

```lldb
process status
thread list
bt all
register read x0 x1
image lookup -a $pc
vmmap --summary
```

MCP 切入点：

> 把「先 status、running 时先 interrupt、轮询到 stopped、再批量取证、最后只 resume 一次」固化成通道纪律。人不再靠记忆，模型也不会在进程 running 时乱发 `bt all`。

### 2.2 并发读写与野指针踩踏

进入「2.2 并发竞态」。

操作 A（安全）：

1. 模式「无锁」、规模 300k、点击运行。
2. 观察 `observed < expected`、`lostWrites > 0`。
3. 切到「NSLock」再跑，观察到 observed == expected，但耗时上升。

操作 B（危险）：

1. 在 DANGER ZONE 点击「触发并发踩踏」并确认。
2. 8 个 worker 向已经 `munmap` 的 16KB 区域写入，触发 `EXC_BAD_ACCESS`。

讲解点：

> 竞态的核心不是「代码看起来有没有加锁」，而是共享可变状态有没有被同步保护。`counter.pointee += 1` 是 read-modify-write，不是原子操作；丢失写取决于调度和缓存行，所以它是偶现的。

面试官追问「TSan 和线上崩溃的关系」：

> TSan 在测试环境把数据竞争变成确定性报告；线上只能看到结果（崩溃/丢数据）。所以要用 TSan 的报告反推共享状态，再用锁、串行队列或 actor 收敛访问路径。

---

## 3. 交易所专项（4 分钟）

### 3.1 弱网重连

进入「交易所 → 3.1 弱网重连」。

操作：

1. 打开「弱网自动抖动」。
2. 点击「连接」。
3. 观察状态机：IDLE → CONNECTING → LIVE → BACKOFF。
4. 观察每次 retry 的 base / jitter / final delay，以及 6 次后进入 EXHAUSTED。

策略：

- base = 0.5s，指数增长。
- jitter = ±20%，避免重连风暴。
- 上限 8s，最多 6 次。
- 状态机保证同一时刻只有一个 handshake 在飞。

讲解点：

> 退避解决「不要立刻再打」，jitter 解决「所有客户端同时再打」，上限解决「不要无限打」，状态机解决「不要并发打」。四件事缺一不可。

### 3.2 高频盘口

进入「3.2 高频盘口」。

操作：

1. 默认「节流 + Diff」，开始推流。
2. 观察 In/s 约 80+，Applied/s 明显更低，Coalesced% 上升。
3. 切换到「全量直更」，观察 apply 次数和 hitch 上升。
4. 切换回「节流队列」，对比只节流不做 Diff 的 apply 耗时。

讲解点：

> 盘口是「状态」不是「事件日志」。渲染层只需要最新状态，所以单槽合并（只保留最后一个快照）语义上是正确的；但真实交易所还要做 sequence gap 检测，防止丢掉中间态。Diff 进一步把 24 档全量刷新变成只改变化的价位。

面试官追问「为什么不每条都渲染」：

> 屏幕只有 60/120Hz，推送 83 条/s 已经超过帧预算；每条都渲染只会把主线程排队。节流是「按帧消费」，不是「丢业务数据」。

---

## 4. AI-Native 与研发效能（4 分钟）

### 4.1 Xcode MCP 通道纪律 + Skills

进入「AI-Native → 4.1」。

操作：

1. 在 MCP 通道卡片点击「按纪律执行批处理」，观察状态机逐步走到 STOPPED，再批量执行 5 条命令。
2. 在 running 阶段点击「越权直发 bt all」，观察被守卫拦截并计数。
3. 向下滚动，打开「LLDB 异步崩溃取证」Skill，展示内置 Markdown 预览。
4. 点击「复制 Markdown」。

讲解点：

> 古法是「凭记忆敲 LLDB」；新实践是把纪律写成状态机，把经验写成 Skill。MCP 不是让模型替代工程师，而是让模型在受控通道里执行可审计的步骤。

### 4.2 Terminal-first 自动化桩

进入「4.2」。

操作：

1. 产物类型选「XCTest 桩」，场景选「1.1 主线程卡顿」，点击「生成并落盘」。
2. 展示文件名、字节数、Documents 路径和代码预览。
3. 点击「复制终端命令」，在 Terminal 执行：

```bash
APP_DATA=$(xcrun simctl get_app_container booted e88ebfa25316fd8c.XClientLab data)
cat "$APP_DATA/Documents/XClientLabAutomation/CPUStallAutomationTests.swift"
```

4. 切到「LLDB 断点」和「MCP 指令」各生成一次，说明三类产物分别对应「回归」「现场」「编排」。

讲解点：

> 一键生成的价值不是省几次点击，而是把「场景 → 测试桩 / 断点 / MCP 计划」变成确定性产物。模型可以生成和解释，MCP 可以执行，文件落盘后可审计。

边界要主动说明：

> 生成的 XCTest 文件需要手动加入 `XClientLabTests` target，因为 iOS App 沙盒不能修改 Xcode 工程文件。这个边界本身就是工程化的一部分：生成器负责内容，工程配置仍由人控制。

## 4.5 模块化架构：把「解耦」跑起来（可选 2 分钟）

进入「架构 → 5.1 / 5.2」。

### 5.1 依赖图与组装根

操作：

1. 看依赖图：`LabContracts`（契约、0 依赖）← `LabFeatureKit`（实现 + 资源）← App 组装根。
2. 点击「RESOLVE ×2」，观察 singleton 两次解析是同一个对象，transient 每次都是新对象。
3. 点开容器注册表，说明 App 只认协议，替换实现不需要改 View。

讲解点：

> 古法是「画一张架构图，代码里照样 import 具体类型」；新实践是把依赖方向变成编译期约束。本地 SPM 包让「契约不能反向依赖实现」从口头约定变成构建失败。

### 5.2 资源包 × 服务替换

操作：

1. 切换 `BundledUserProvider` / `MockUserProvider`，观察卡片数据变化。
2. 点击「解析 demo-profiles.json」，说明 JSON 来自 `Bundle.module`，不经过 App bundle。
3. 点击「RUN CHAIN」，展示 `UserDirectoryService` 串联 provider + analytics 两个协议的事件链。

讲解点：

> 资源隔离和依赖倒置是同一件事的两面：模块自己带资源、自己提供实现，App 只负责组装。面试时可以现场把 Mock 换回去，证明「替换成本」不是 PPT 上的形容词。

---

## 5. 收尾（1 分钟）

一句话总结：

> 性能看证据链，异常看现场保全，交易所看状态机与帧预算，AI-Native 看纪律与可审计产物，架构看依赖方向与替换成本。XClientLab 把这些做成了可重复的实验，而不是一次性的演示。

可继续追问的方向：

- 如果把 1.1 的解析搬到后台，如何保证 UI 状态一致性？
- 如果 3.2 的盘口推送带 sequence，如何做 gap 检测与重放？
- 如果 2.1 的崩溃发生在线上，如何用 MetricKit / PLCrashReporter 补齐符号化？
- 如果 MCP 要接入真实 Xcode，如何做权限、超时和命令白名单？

---

## 附：常用取证命令

```bash
# 构建（SPM + SwiftLint 插件）
xcodebuild -project XClientLab.xcodeproj -scheme XClientLab \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation build

# 测试（8 个用例）
xcodebuild test -project XClientLab.xcodeproj -scheme XClientLab \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation

# 安装 / 启动
xcrun simctl install booted ./DerivedData/Build/Products/Debug-iphonesimulator/XClientLab.app
xcrun simctl launch --console booted e88ebfa25316fd8c.XClientLab

# 查看 4.2 产物
APP_DATA=$(xcrun simctl get_app_container booted e88ebfa25316fd8c.XClientLab data)
ls -lh "$APP_DATA/Documents/XClientLabAutomation"
```
