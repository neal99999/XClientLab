# Terminal-first 自动化说明

对应 App 内「AI-Native → 4.2 终端自动化协同命令桩」。目标是把「场景 → 测试桩 / 断点 / MCP 计划」变成可落盘、可审计、可在终端复用的产物。

## 1. 三种产物

| 类型 | 扩展名 | 用途 | 典型使用 |
| --- | --- | --- | --- |
| XCTest 桩 | `.swift` | 回归验证 | 加入 `XClientLabTests` 后 `xcodebuild test` |
| LLDB 断点 | `.lldb` | 现场取证 | `lldb -p <pid>` 后 `command source` |
| MCP 指令 | `.json` | 编排计划 | 交给 Xcode MCP / 自建工具执行 |

命名规则：

```text
<ScenarioSlug>AutomationTests.swift
<ScenarioSlug>Drill.lldb
<ScenarioSlug>MCP.json
```

场景与 slug：

| 场景 | slug | 默认测试类 |
| --- | --- | --- |
| 1.1 主线程卡顿 | `CPUStall` | `CPUStallAutomationTests` |
| 1.2 分配锯齿 | `AllocationStorm` | `AllocationStormAutomationTests` |
| 2.1 系统栈 UAF | `UAF` | `UAFAutomationTests` |
| 2.2 并发踩踏 | `Race` | `RaceAutomationTests` |
| 3.1 弱网重连 | `Reconnect` | `ReconnectAutomationTests` |
| 3.2 盘口节流 | `OrderBook` | `OrderBookAutomationTests` |

## 2. 落盘位置

App 沙盒：

```text
Documents/XClientLabAutomation/
```

模拟器上读取：

```bash
APP_DATA=$(xcrun simctl get_app_container booted e88ebfa25316fd8c.XClientLab data)
ls -lh "$APP_DATA/Documents/XClientLabAutomation"
cat "$APP_DATA/Documents/XClientLabAutomation/CPUStallAutomationTests.swift"
```

App 内点击「生成并落盘」后，会显示文件名、字节数、创建时间和终端命令。产物最多保留最近 8 条记录，磁盘文件不被自动删除，便于重复演示。

## 3. 产物内容

### 3.1 XCTest 桩

每个桩只验证一个明确的契约，避免「看起来能跑但什么都没证明」：

- 1.1：极端档触发后，`worstPassMs > 500`。
- 1.2：启动分配风暴后，`churnedMB` / `tickCount` 增长。
- 2.1：默认只校验取证报告字段，不主动触发崩溃；破坏性用例由 `XCLIENTLAB_DESTRUCTIVE=1` 门控。
- 2.2：无锁大压力下 `lostWrites > 0`，加锁路径不丢写。
- 3.1：退避序列符合 `min(8, 0.5 * 2^(n-1))`，且最多 6 次。
- 3.2：200 次提交经单槽合并后，只取到 1 个待处理快照。

示例（1.1，节选）：

```swift
import XCTest
@testable import XClientLab

final class CPUStallAutomationTests: XCTestCase {
    @MainActor
    func testExtremePassExceeds500ms() async throws {
        let viewModel = CPUStallViewModel()
        viewModel.intensity = .extreme
        viewModel.runStress()

        try await Task.sleep(nanoseconds: 2_500_000_000)

        XCTAssertGreaterThan(viewModel.worstPassMs, 500)
        XCTAssertGreaterThan(viewModel.totalBlockedMs, 0)
    }
}
```

> 真实生成的桩会包含完整注释和更多断言字段，以上仅示意结构。

### 3.2 LLDB 断点

每个脚本都是一条可复制的取证链，而不是单条 `breakpoint set`：

```lldb
process status
process interrupt
process status
breakpoint set -r 'CPUStallViewModel.*runStress'
thread list
bt all
register read x0 x1 x2 x3
image lookup -a $pc
process continue
```

2.1 的脚本还会把 `CrashProbe.armSystemStackUseAfterFree` 作为断点正则，并提示先确认 `0x1d` 现场。

### 3.3 MCP 指令

JSON 结构包含：

```json
{
  "schema": "xclientlab.mcp.drill/v1",
  "scenario": "cpuStall",
  "guardrails": {
    "timeoutMs": 180000,
    "requireProcessStatus": true,
    "maxResumes": 1,
    "rejectCommandsWhileRunning": true
  },
  "steps": [
    { "tool": "xcode.build", "args": { "scheme": "XClientLab" } },
    { "tool": "lldb.batch", "args": { "mode": "stopped" } },
    { "tool": "xcode.result.parse", "args": { "format": "xcresult" } }
  ]
}
```

真实的 tool 名称和参数需要按你接入的 MCP server 调整；这里定义的是「计划契约」，重点是 guardrails 和步骤顺序。

## 4. 为什么需要手动加入 target

iOS App 沙盒无法修改 `.xcodeproj`，所以生成的 `.swift` 文件不会自动出现在 `XClientLabTests` target 的 Compile Sources 里。两种处理方式：

1. 在 Xcode 中把文件拖入 `XClientLabTests` target，勾选 target membership。
2. 把生成目录作为测试 target 的 folder reference，或写构建脚本在 CI 中复制。

这是有意的边界：生成器负责内容，工程配置由人控制，避免一个演示动作悄悄改坏项目文件。

## 5. 终端工作流

```bash
# 1. 生成后拿到路径
APP_DATA=$(xcrun simctl get_app_container booted e88ebfa25316fd8c.XClientLab data)
ART="$APP_DATA/Documents/XClientLabAutomation"

# 2. 查看
ls -lh "$ART"
cat "$ART/ReconnectMCP.json"

# 3. 复制到工程（示例）
cp "$ART/CPUStallAutomationTests.swift" XClientLabTests/

# 4. 跑单个测试
xcodebuild test \
  -project XClientLab.xcodeproj \
  -scheme XClientLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:XClientLabTests/CPUStallAutomationTests
```

## 6. 设计取舍

- **为什么落在 Documents 而不是 tmp**：演示需要跨启动读取，tmp 可能被系统清理。
- **为什么只保留 8 条记录**：UI 列表可读，磁盘文件仍保留，避免演示时刷屏。
- **为什么测试桩不直接触发 2.1 崩溃**：CI 不应该因为一个默认用例而挂掉；破坏性路径必须显式门控。
- **为什么 MCP 计划是 JSON 而不是直接执行**：计划可审阅、可 diff、可版本化；执行器可以替换。
- **为什么同时生成三种产物**：回归、现场、编排是三个不同阶段，不能用一个脚本假装全覆盖。

## 7. 面试一句话

> Terminal-first 不是「会写几条 shell」，而是把重复的调试动作固化成带契约的产物：测试桩负责回归，LLDB 脚本负责现场，MCP 计划负责编排；人只负责审查和执行边界。
