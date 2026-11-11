# CLAUDE.md - XClientLab AI Engineering Guidelines

This file provides guidance to Claude Code (claude.ai/code), Cursor, and other agentic assistants when working in the `XClientLab` repository.

---

## 1. 项目概览

**XClientLab** 是一个面向 iOS 高级/资深开发与架构师的技术实验与工程化 Sandbox：
- **主线**：解决真实交易所与金融客户端的两大核心难题——**极端行情下的渲染性能重构**（100+ Tick/s、聚合裁剪、主线程帧预算）与**跨国弱网下的 TCP 假连接 + 订单状态竞态**（单调 Sequence 防状态回滚、心跳自愈与 Jitter 重连）。
- **技术栈**：纯代码 **UIKit + MVVM + Combine + SnapKit**（无 SwiftUI、无 Storyboard/XIB），Swift 5 语言模式，iOS 18.0+ 基线。
- **依赖管理**：纯 SwiftPM（Alamofire / Kingfisher / Moya / SnapKit / Starscream / SnapshotTesting），以及 `Packages/` 下两个本地 SPM 包（`LabContracts` 契约层与 `LabFeatureKit` 实现层）。
- **自动化交付**：Fastlane + GitHub Actions CI/CD，44+ 自动化用例（单元、快照、UI 测试 0 失败）。
- **工程格式**：`objectVersion = 110`（Xcode 27.x 工程格式）。

---

## 2. 常用开发与构建命令

所有核心命令收敛在根目录 [`Makefile`](Makefile)：

```bash
# SPM 依赖解析
make resolve

# 命令行构建（跳过插件提示与签名要求）
make build

# 运行自动化测试（44 个用例：单元、快照、UI 测试）
make test          # 原生 xcodebuild
make ci            # Fastlane scan 全量分步测试

# 质量门禁与规范
make lint          # SwiftLint 静态代码规范检查
make format-check  # SwiftFormat 格式化状态检查

# 持续交付与打包 (Fastlane)
make cd-testflight    # 打包 App Store 签名 IPA 并直传 TestFlight
make cd-adhoc         # 打包 Ad-Hoc IPA 并发布至蒲公英
make cd-package-sim   # 打包模拟器 .app.zip 供快速免证书测试验证
```

---

## 3. 架构约定与编码红线（Hard Rules）

详细分项规则参见 `.claude/rules/` 目录：
- [`performance.md`](.claude/rules/performance.md)：主线程 16ms 帧预算、大 JSON 异步解析、图片降采样、防 Overdraw；
- [`concurrency-and-memory.md`](.claude/rules/concurrency-and-memory.md)：逃逸闭包强制 `[weak self]`、Timer/DispatchSource 生命周期、锁临界区最小化、循环削峰；
- [`financial-precision.md`](.claude/rules/financial-precision.md)：资金严禁使用 `Double`/`Float`、必须使用 `String`/`Decimal`、非幂等写入接口严禁自动重试；
- [`architecture.md`](.claude/rules/architecture.md)：纯代码 UIKit + SnapKit、单向数据流 `ViewState`、UI 六态交付矩阵、模块单向依赖（`App ➔ LabFeatureKit ➔ LabContracts`）；
- [`testing.md`](.claude/rules/testing.md)：自动化测试覆盖与证据链表达红线。

---

## 4. AI-Native 五位一体体系 (Playbook)

本项目将资深研发经验固化为工程资产：
1. **Rules**（`.claude/rules/`）：硬性架构红线与禁令，常驻上下文；
2. **Skills**（`.claude/skills/`）：8 大专项调试剧本（`lldb-async-crash`、`hitch-stall-profiler`、`network-race-guard`、`concurrency-race-debug`、`figma-to-uikit` 等）；
3. **Agents**（`.claude/agents/`）：角色分工（写代码的开发与独立只读的 `code-reviewer` 审阅者）；
4. **Hooks**（`.githooks/pre-commit`）：Git 提交前毫秒级增量 SwiftLint 门禁；
5. **MCP**（`.claude/mcp/server.py` 与 `.claude/mcp.json`）：受控通道打通本地 `xcodebuild`、`simctl`、`fastlane` 与 `lldb` 工具链。
