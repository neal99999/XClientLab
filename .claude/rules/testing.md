---
description: IBIT 的构建与验证规则：主 App 无测试 target，只能用编译 + 手动回归，禁止把"编译通过"说成"功能验证通过"
paths:
  - "**/*.swift"
  - "MCIBIT/**"
---
# 测试与验证

## 能自动化的
- 本地 SwiftPM 包有测试，改到它们时必须跑：
  - `cd MCIBIT/SwiftPM/Wrapper && swift test`
  - `cd MCIBIT/SwiftPM/TrueTime && swift test`
- 编译验证：
  ```bash
  xcodebuild -workspace MCIBIT/MCIBIT.xcworkspace -scheme MCIBIT -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
  ```
  首次构建可能因内网私有 pod（MCCommon、MAH_user）失败；失败就如实报告「未完成编译验证」，不要绕过或改 Podfile。
- 只跑局部时说明范围，例如 `-workspace ... -scheme MCIBIT build` 的耗时通常以分钟计，不要反复全量构建。

## 不能自动化的
- 主 App **没有 XCTest / UI Test target**，业务逻辑没有自动化回归手段。
- 因此任何业务改动都必须列出手动回归场景，至少覆盖：
  - 进入/退出页面、返回手势、复用到该页面的其他入口
  - 切币对、切周期、页面消失、退登、前后台切换（WebSocket 订阅）
  - 深色/浅色主题、切换语言（会重建 TabBar 与部分导航栈）
  - 金额/数量展示与下单/撤单（非幂等接口）
  - 弱网、超时、接口业务失败、登录失效

## 表述红线
- 没跑过的检查不要写成「已验证」；写「未验证 + 原因 + 最小验证步骤」。
- 编译成功只代表编译成功，不代表功能正确；禁止编造测试通过率、覆盖率、FPS、耗时、内存数字。
- 改了共享状态（单例、通知、全局 Provider）时，回归范围要主动放大并在报告里写明。
