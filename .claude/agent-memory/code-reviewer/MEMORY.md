# code-reviewer 记忆

> 只记录长期有用的结论；每次评审后追加，超过 200 行时合并同类项、删过期项。
> 会话启动只加载前 200 行 / 25KB，重要结论往前放。

## 项目事实
- 主 App 无 XCTest / UI Test target，业务改动只能手动回归；SwiftPM 包（Wrapper、TrueTime）有 `swift test`。
- 金额/数量一律 String 大数扩展，禁止 `Double`；下单/撤单非幂等，禁止自动重试。
- 主题 key 三处同步：`WhiteTheme.plist`、`BlackTheme.plist`、`MLThemePathKey`。
- 新文件不会自动进 target（`project.pbxproj` 无 `PBXFileSystemSynchronizedRootGroup`），需手动 Add Files。
- 编译输出大量废弃 API 与重复 Compile Sources 告警属已知现状，不要当成本次改动的问题。

## 高频问题（按出现频率追加）
- WebSocket：切币对/周期、页面消失、退登、前后台未退订 → 重复数据/串币。
- 金额展示：把 String 转 `Double` 做乘除；精度/小数位未按交易对配置。
- 主题：新增颜色只加了一个 plist，`MLThemePathKey` 漏枚举 → 深色模式崩溃或取不到色。
- 国际化：新增文案只补 zh-Hans，en/zh-Hant 缺失。
- 线程：网络回调直接刷 UI，未回主线程；`[weak self]` 漏写导致 VC 不释放。
- 日志：`print` 带 token/订单参数/资产。

## 评审偏好
- 顺序：资金与崩溃 > 数据一致性 > 主题/国际化 > 风格。
- 结论先行，最多 5 项；每项必须有文件:行号与证据。
- 不确定标「待验证」，不把风格偏好标成 HIGH。

## 历史结论 / 已知坑
- 2026-11-09：本机 Xcode 27.1 上 `xctrace record` 触发 `XRAugmentationManager resetAnalysisCoreForPreflight` 断言；Instruments 录制需 GUI fallback，评审时不要要求 agent 交出实测 trace。
- 2026-11-09：DSH 不读取 `.claude/commands`，项目内 `.dsh/skills/*.md` 是适配层；改命令只改 `.claude/commands`，不要改适配层正文。
