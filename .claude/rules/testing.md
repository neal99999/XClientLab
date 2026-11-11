---
description: XClientLab 构建验证与测试规范：单元测试、快照测试、UI 回归与确定性证据链
paths:
  - "XClientLabTests/**"
  - "XClientLabUITests/**"
  - "XClientLab/**"
---
# 自动化测试与工程验证规范

## 1. 自动化测试分层结构
本项目包含完整的可自动化验证测试套件（基线 44+ 用例，0 失败）：
1. **领域逻辑单元测试 (`XClientLabTests`)**：
   - 金额/时间格式化换算、行情计算、委托挂单规则校验、Sequence 版本号比对；
2. **ViewModel 与异步测试 (`XClientLabTests`)**：
   - 基于 Mock 的网络服务响应、状态流转（loading/loaded/failed）与 Combine 管道异步期望验证；
3. **UI 组件快照测试 (`XClientLabTests/ComponentSnapshotTests.swift`)**：
   - 基于 `swift-snapshot-testing` 验证设计稿还原度，差异率阈值收敛至 `0.00% PASS`；
4. **核心 UI 链路测试 (`XClientLabUITests`)**：
   - 验证交易所首屏加载、极端行情压力注入、弱网切断与自愈链路。

## 2. 命令行与 CI 验证命令
所有改动在提交前必须经过本地测试验证：
```bash
# 运行全部测试（Fastlane Scan 驱动，分步执行防竞争）
make ci
# 或直接运行：
make test
```

## 3. 证据链表述红线
- 严禁空口宣称“测试全部通过”或“性能已无异常”；
- 必须给出明确的量化证据：
  - 测试用例执行数与通过率；
  - Instruments Time Profiler / HitchMonitor 的实际耗时指标（如 `21.8ms ➔ 3.2ms`）；
  - 编译器警告数与 SwiftLint 扫描报告。
