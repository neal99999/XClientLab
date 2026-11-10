# Testing

XClientLab 的测试按「纯逻辑 → 网络/ViewModel → 组件快照 → 核心 UI」分层。目标是让面试演示时能先跑确定性用例，再打开 App 讲异常现场。

## 1. 运行方式

```bash
# 本机全量（Unit + Snapshot + UI）
make test

# CI 同款：fastlane scan
fastlane test
# 或
bundle exec fastlane test

# 单层
xcodebuild test ... -only-testing:XClientLabTests/DomainCoreTests
xcodebuild test ... -only-testing:XClientLabTests/MarketDataViewModelTests
xcodebuild test ... -only-testing:XClientLabTests/ComponentSnapshotTests
xcodebuild test ... -only-testing:XClientLabUITests
```

构建/测试需要 `CODE_SIGNING_ALLOWED=NO` 和 `-skipPackagePluginValidation`（SwiftLint build tool plugin）；全量测试额外加 `-disableAutomaticPackageResolution`，避免 CI 卡在 SPM 解析。

## 2. 40 个用例的分布

| 测试类 | 数量 | 说明 |
| --- | ---: | --- |
| `DomainCoreTests` | 20 | `Money` 解析/格式化、`TradingTime` UTC 换算、`MarketDataParser` 异常 payload、`OrderValidator` 业务规则 |
| `MarketDataViewModelTests` | 6 | actor Mock 注入、success/malformed/retry/normalization/empty/reset 状态迁移 |
| `ComponentSnapshotTests` | 4 | `LabModuleHeaderView`、`LabCardView`、`LabMetricTileView` 行、`LabCalloutView` |
| `XClientLabTests`（既有） | 6 | 盘口合并、退避常量、CPU payload、Allocations 数据、Markdown parser、12 档盘口 |
| `XClientLabUITests` | 4 | 启动首屏、1.1 push、CPU RUN 完成回 IDLE、3.2 盘口 START/STOP |

## 3. 纯逻辑：把交易规则从 UI 里拆出来

`XClientLab/Core/TradingCore.swift` 不依赖 UIKit：

- `Money` 以 `minorUnits: Int64` 存储，`parse` 拒绝负数和超过两位小数，`formatted` 固定 `en_US_POSIX` + 强制分组，避免模拟器 locale 让断言漂移。
- `TradingTime` 固定 UTC；`MarketDataParser` 把「空 ticks / 非法 symbol / 非正价格 / 错误时间戳」映射成带 index 的错误。
- `OrderValidator` 用静态正则校验 symbol，并校验正价格/正数量/notional 上限。

这类用例跑得极快，适合作为 pre-commit 和 CI 第一道门。

## 4. 网络层：Protocol + Mock + 状态机

`MarketDataProviding` 只暴露一个 async 方法；生产实现是 `URLSessionMarketDataService`，测试实现是 `actor MockMarketDataService`（结果队列 + 请求 symbol 记录）。

`MarketDataViewModel` 的状态是显式枚举：

```swift
enum State: Equatable {
    case idle
    case loading(symbol: String)
    case loaded(TickerQuote)
    case failed(message: String)
}
```

测试覆盖成功、服务端 malformed、失败后重试、大小写/空格归一化、空 symbol 短路、reset。重点不是「网络通不通」，而是「UI 在每种状态下该显示什么」。

## 5. 快照：锁住公共组件

`swift-snapshot-testing 1.17.6` 通过 SPM 接入 `XClientLabTests`。基线在：

```text
XClientLabTests/__Snapshots__/ComponentSnapshotTests/
```

维护约定：

1. 修改组件后先 `record = true` 跑一次，生成/更新 PNG；
2. 人眼检查 4 张基线（暗色、字号、间距、Callout 颜色）；
3. 立刻改回 `record = false` 并重跑，确认 `TEST EXECUTE SUCCEEDED`；
4. 基线 PNG 随代码提交，CI 只做比对，不录制。

## 6. 核心 UI 链路

只保留 4 条稳定链路，避免 UI 测试变成 flaky 大全：

- App 启动后能看到「性能优化专项」；
- 1.1 入口 push 到「1.1 CPU 卡顿」；
- 点 `cpu.run` 后，按钮从 `BLOCKING…` 回到 `RUN BLOCKING WORK`（真实跑完 12 个 pass）；
- 交易所 tab → 3.2 → `START FEED` → `STOP FEED` → `START FEED`。

定位符统一使用 `accessibilityIdentifier`（`tab.exchange`、`exc.scenario.book`、`book.toggle`、`cpu.run`），不依赖中文文案的层级。

## 7. Fastlane + CI

`fastlane/Fastfile` 的 `test` lane 调用 `scan`，固定：

- `project: XClientLab.xcodeproj`
- `scheme: XClientLab`
- `destination: platform=iOS Simulator,name=iPhone 18 Pro Max`（可用 `SIMULATOR_DESTINATION` 或 `SIMULATOR_NAME` 覆盖）
- `xcargs: CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -disableAutomaticPackageResolution`
- 结果包输出到 `fastlane/test_output/`

CI 在 `.github/workflows/ci.yml`，直接调用 `xcodebuild test`（不经过 fastlane，少一层 Ruby 依赖）：

- runner：`xcode-27`（macOS 27 + Xcode 27.0~27.2；本项目是 objectVersion 110 的 Xcode 27 工程格式，Xcode 26 打不开）
- destination：`platform=iOS Simulator,OS=27.1`，与快照基线的录制 runtime 对齐。run #4 验证过：27.2 runtime 上含 SF Symbol/渐变的 3 个快照出现像素差异，纯文本的通过；不指定机型，快照用固定 360x220 的 ViewImageConfig，机型无关
- 参数与本地一致：`CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -disableAutomaticPackageResolution`
- scheme 由 `XClientLab.xcodeproj/xcshareddata/xcschemes/XClientLab.xcscheme` 共享，CI checkout 后可直接使用
- `.xcresult` 与测试日志通过 `actions/upload-artifact` 保留 7 天

`bundle exec fastlane test` 仍可用于本地复跑同一条链路。

## 8. 边界

- 2.1/2.2 的破坏性路径不在 CI 默认开启；真实崩溃演示必须由人手动触发。
- 快照基线依赖系统字体渲染；跨 Xcode/iOS 大版本升级时允许一次显式重录，并在 PR 中单独说明。
- UI 测试只覆盖导航与状态切换，不覆盖高频盘口的数值正确性；数值正确性由纯逻辑和 ViewModel 测试保证。
