---
description: XClientLab 架构边界、UI 六态矩阵与模块化契约原则
paths:
  - "XClientLab/**"
  - "Packages/**"
---
# 架构边界与 UI 六态交付规范

## 1. 技术栈基线
- **纯代码 UIKit + SnapKit**，禁止使用 SwiftUI 或 XIB / Storyboard。
- 架构模式：严格的 **MVVM + Combine 单向数据流**：
  - ViewModel 维护唯一状态源 `ViewState`；
  - 界面统一由 `render(_ state: ViewState)` 函数推导，禁止散落各种布尔标记。
  - 用户交互统一封装为 Intent / Action 发送给 ViewModel。

## 2. 模块化与依赖方向红线
- 依赖方向严禁颠倒：
  ```
  App Target (组装根) ──► LabFeatureKit (实现层) ──► LabContracts (纯协议契约层, 0 外部依赖)
  ```
- 模块间通信基于面向协议（POP + DI），禁止在模块内部反向依赖 App Target 或同级业务模块。
- 严禁擅自修改 `Packages/` 或外部第三方 Pods/SPM 源码，自定义扩展一律通过 Extension 或包装适配器（Adapter）实现。

## 3. UI 还原的“六态防御矩阵”
任何新页面或组件在交付前，必须在代码中显式实现并覆盖以下全部六种状态：
1. **Loaded（正常态）**：标准业务展示，适配深色主题；
2. **Loading（加载态）**：骨架屏（Skeleton）或精准指示器，阻断重复点击；
3. **Empty（空态）**：无数据占位图与引导行动按钮；
4. **Error（错误态）**：可感知的明确报错文案与一键重试动作；
5. **Offline / Flaky（弱网/离线态）**：弱网横幅提示与降级缓存展示；
6. **Boundary / Overflow（临界值态）**：超长文本省略、极端大额数值展示与小屏设备适配。
