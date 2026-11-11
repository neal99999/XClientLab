# XClientLab 面试演示脚本

目标：15–20 分钟内，让面试官看到「能复现 → 能观测 → 能归因 → 能改造」的完整闭环，而不是只展示几个 API。

---

## 0. 开场（1 分钟）

一句话定位：

> 这是一个 iOS 性能与稳定性 Sandbox。每个场景都先故意制造一个可重复的异常，再用 Instruments / LLDB / 指标面板拿出证据，最后说明 AI MCP 如何把取证过程工程化。

工程采用 UIKit + MVVM + Combine，页面全部代码构建、约束用 SnapKit，没有 SwiftUI / Storyboard；现场可以直接打开 Xcode Debug View Hierarchy 讲真实 UIView 树。底部有四个 Tab：**交易所专项 / 实验室 / 交付与防线 / AI 工坊**。主线先把交易所的两个案例讲透，性能、异常、架构都放到「实验室」里作为追问区。

---

## 1. 交易所专项（8–10 分钟，主线）

> 这一节是整场的主菜。详细逐字稿、追问 Q&A 和事实边界见 [交易所主线讲法](Exchange-Story.md)，这里只给现场操作顺序。

### 1.1 案例一：极端行情渲染性能重构（4 分钟）

进入「交易所专项 → 案例一」。

1. 先用 30 秒讲结果：100+ Tick/s、20–30 FPS、下单延迟 >1s；三步改造后 55+ FPS、<16ms、CPU −20%。
2. 默认「旧链路 · 全量重绘」，点 `START STRESS`，读出 FPS ~40、MAIN THREAD ~21ms、ORDER P95 1000+ms。
3. 点「市价平仓 · 测延迟」，解释“按钮没坏，是 main queue 在排队”。
4. `STOP`，切「重构后 · 聚合 + 裁剪」，再跑一次，对照主线程和订单延迟。
5. 讲三步：算力搬家 + 版本凭证、视口裁剪 + 脏矩形、100ms 时间窗聚合。

讲解点：

> 卡顿不是“体验问题”，是交易问题。用户在剧烈行情里点平仓，主线程每多排 16ms，滑点就多一分。优化的目标不是“画得更多”，而是“主线程只做最新、最少的那一帧”。

### 1.2 案例二：跨国弱网 + 订单状态竞态（4 分钟）

进入「交易所专项 → 案例二」。

1. 保持「开启心跳探测」，点「注入断网 · 电梯场景」，观察 2.8s 自愈。
2. 关掉心跳再注入一次，观察停在“假连接”。
3. 保持「开启版本号保护」，点「注入乱序事件 · HTTP 慢响应」：WS `seq=12 filled` 先到，HTTP `seq=9 pending` 被丢弃。
4. 关掉保护再注入一次，观察状态回滚到「挂单中」。
5. 讲两层防线：应用层 5s Ping / 2 次丢 Pong / 10s 无下行；业务层单调 Sequence + `pending → filled` 单向状态机。

讲解点：

> Reachability 只说明“有网卡”，TCP keepalive 又是分钟级；客户端必须自己判死链。订单状态则要假设“任何两条通道都可能乱序”，用版本号拒绝旧事件，用状态机兜底不可回滚。

---

## 2. 追问：性能优化（5 分钟，五条链路）

进入「实验室 → 性能优化」。先讲结论：

> 性能不是“某个 API 慢”，而是启动、UI、网络、内存、CPU 五层成本。先分层、再测量，最后只改瓶颈。

页面先给五条链路，再给两个真实波形（CPU / Allocations）。不要一上来就跑 1.1。

### 2.1 启动速度与包大小

进入「01 启动速度与包大小」。

操作：

1. 看「本次启动的现场数字」：didFinish → 首帧、ObjC 类数、dyld 镜像数、Bundle 大小。
2. 讲 main 前：减少/合并动态库，减少 ObjC 类、分类、`+load`/静态构造函数；用二进制插装找到启动热路径，再用 `-order_file` 重排。
3. 讲 main 后：不在 `didFinishLaunchingWithOptions` 里同步初始化推送、埋点、DB；用 lazy / 后台队列 / 首帧后启动。
4. 讲包大小：先删无用资源，再用 PDF/SVG 单尺寸、Lottie、LTO / `-Osize` / App Thinning。Bitcode 已被 Apple 废弃，不要把它当答案。

讲解点：

> 启动图只掩盖白屏，不减少工作量。真正可回归的是首帧时间、main 前/后分段、类/镜像数量和包大小 diff。

### 2.2 UI 渲染优化

进入「02 UI 渲染优化」。

按四个点讲：

- 减少视图嵌套和透明视图；用 Color Blended Layers 看 overdraw，静态背景合成成一张图。
- 列表用 cell 复用、缓存高度；重计算不要放在 `cellForRow`。
- 图片异步加载、按目标像素降采样；圆角优先 CoreGraphics 预渲染或透明覆盖层，避免 `cornerRadius + masksToBounds` 触发离屏。
- 合并 `setNeedsDisplay` / `setNeedsLayout`，只刷新脏矩形；动画优先改 `CALayer` 属性。

讲解点：

> 改完必须用 FPS / hitch / 离屏帧对比，不能只说“感觉顺了”。

### 2.3 网络请求优化

进入「03 网络请求优化」。

- 合并：同屏同 symbol 的请求做 batch；在途请求 single-flight；搜索用 debounce。
- 缓存：NSCache（内存、自动回收）、MMKV（高频 KV）、SQLite（查询/离线）、HTTP ETag / Cache-Control。
- 弱网：连接/读取超时、指数退避 + jitter、重试上限、幂等键。

讲解点：

> 网络优化要报三个数：请求数、缓存命中率、P95；只看“快了”没有意义。

### 2.4 内存优化

进入「04 内存优化」。

- 闭包/Block 用 `[weak self]`；delegate 用 `weak`；Timer/DispatchSource 在 `deinit`/`viewDidDisappear` invalidate/cancel；通知 token 要移除。
- 大对象分页、图片降采样、循环里 `autoreleasepool` 削峰。
- NSCache 设 `countLimit` / `totalCostLimit`；收到内存警告时主动清。
- 工具：Allocations 看峰值，Leaks 看不可达环，Memory Graph 看 retain path。

讲解点：

> 缓存有上限和淘汰策略；泄漏是“不该活却还活着”。两者都只能靠 retain path 区分。

### 2.5 CPU 与主线程

进入「05 CPU 与主线程」。

- 主线程只做 UI/事件；JSON、正则、图片解码、DB、文件 IO 下沉到背景队列。
- 频繁查找用字典/集合（O(1)），不要遍历数组；缓存重复计算，只算可见区。
- 缩小锁临界区、避免嵌套锁；用串行队列/actor 收敛共享状态，注意优先级反转。

讲解点：

> Time Profiler 看 self time，不要只看最重栈；先确认是算法、锁还是主线程排队。

### 2.6 现场波形（可选 2 分钟）

回到性能首页底部：

1. **LIVE 主线程 JSON 风暴**：极端档同步解析 + 正则，观察 >500ms worst pass、Hitch 统计；讲“主线程被同步任务占满”的反模式。
2. **LIVE Allocations 锯齿**：长列表 + 256KB 临时 buffer + 短命对象，观察 footprint 锯齿、Peak/Churn；讲对象池、分页、降采样。

两个场景都保留「古法排查痛点 / AI MCP 新实践」注释：先让 Instruments 给出证据，再让 MCP 把 trace 转成最小复现和可回归用例。

---

## 3. 追问：异常与疑难攻坚（可选 3 分钟）

### 3.1 系统栈黑盒 Crash（UAF / 0x1d）

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

### 3.2 并发读写与野指针踩踏

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

## 4. 实验室：交易所细节（可选 2 分钟）

### 4.1 弱网重连

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

### 4.2 高频盘口

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

## 5. AI 工坊（可选 3 分钟）

### 5.1 Xcode MCP 通道纪律 + Skills

进入「AI-Native → 4.1」。

操作：

1. 在 MCP 通道卡片点击「按纪律执行批处理」，观察状态机逐步走到 STOPPED，再批量执行 5 条命令。
2. 在 running 阶段点击「越权直发 bt all」，观察被守卫拦截并计数。
3. 向下滚动，打开「LLDB 异步崩溃取证」Skill，展示内置 Markdown 预览。
4. 点击「复制 Markdown」。

讲解点：

> 古法是「凭记忆敲 LLDB」；新实践是把纪律写成状态机，把经验写成 Skill。MCP 不是让模型替代工程师，而是让模型在受控通道里执行可审计的步骤。
> 完整的 AI-Native 五位一体架构（Rules + Skills + Agents + Hooks + MCP）与面试 3 分钟话术详见 [AI-Engineering-Playbook.md](AI-Engineering-Playbook.md)。仓库内已配好实际可执行的 [.claude/skills/lldb-async-crash/SKILL.md](../.claude/skills/lldb-async-crash/SKILL.md) 与 MCP 服务配置。

### 5.2 Terminal-first 自动化桩

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

## 6. 架构与模块化：把「解耦」跑起来（可选 2 分钟）

进入「架构 → 5.1 / 5.2」。

### 6.1 依赖图与组装根

操作：

1. 看依赖图：`LabContracts`（契约、0 依赖）← `LabFeatureKit`（实现 + 资源）← App 组装根。
2. 点击「RESOLVE ×2」，观察 singleton 两次解析是同一个对象，transient 每次都是新对象。
3. 点开容器注册表，说明 App 只认协议，替换实现不需要改 View。

讲解点：

> 古法是「画一张架构图，代码里照样 import 具体类型」；新实践是把依赖方向变成编译期约束。本地 SPM 包让「契约不能反向依赖实现」从口头约定变成构建失败。

### 6.2 资源包 × 服务替换

操作：

1. 切换 `BundledUserProvider` / `MockUserProvider`，观察卡片数据变化。
2. 点击「解析 demo-profiles.json」，说明 JSON 来自 `Bundle.module`，不经过 App bundle。
3. 点击「RUN CHAIN」，展示 `UserDirectoryService` 串联 provider + analytics 两个协议的事件链。

讲解点：

> 资源隔离和依赖倒置是同一件事的两面：模块自己带资源、自己提供实现，App 只负责组装。面试时可以现场把 Mock 换回去，证明「替换成本」不是 PPT 上的形容词。

---

## 7. 收尾（1 分钟）

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

# 测试（44 个用例；推荐 fastlane scan）
fastlane test

# 等价裸命令
xcodebuild test -project XClientLab.xcodeproj -scheme XClientLab \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation -disableAutomaticPackageResolution

# 安装 / 启动
xcrun simctl install booted ./DerivedData/Build/Products/Debug-iphonesimulator/XClientLab.app
xcrun simctl launch --console booted e88ebfa25316fd8c.XClientLab

# 查看 4.2 产物
APP_DATA=$(xcrun simctl get_app_container booted e88ebfa25316fd8c.XClientLab data)
ls -lh "$APP_DATA/Documents/XClientLabAutomation"
```
