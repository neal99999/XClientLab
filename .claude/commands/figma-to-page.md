---
description: 根据 Figma 标注或截图，按六态矩阵与 Design Token 生成像素级纯代码 UIKit (SnapKit) 页面与快照测试
argument-hint: "<页面名称> [业务说明或 Figma 标注]"
disable-model-invocation: true
---

先读取仓库根目录的 `CLAUDE.md` 与 `.claude/neal/project-context.md`，遵守纯代码 UIKit (SnapKit)、无 SwiftUI、Design Token 映射规范。
本命令严格遵循 `.claude/skills/figma-to-uikit/SKILL.md` 定义的标准操作程序（SOP）。

# 输入解析
`$ARGUMENTS` 格式：`<页面名称> [业务说明或 Figma 标注]`
如果未提供输入，只问一句：“请提供页面名称以及 Figma 设计稿的标注/文本/截图说明”然后停止。

# 执行步骤

### 1. 视觉 Token 转换与映射
- 提取设计中的颜色，自动映射为 `LabUI.*` 语义色（严禁出现硬编码十六进制色值）；
- 提取字号与字重，映射为标准文字阶梯（`LabUI.font(..., weight:)`）；
- 间距强制对齐 4pt/8pt 网格系统。

### 2. 停顿确认：输出《六态补全与边界确认表》✋（人来掌舵）
在写任何代码前，必须先输出以下表格并明确暂停，等待用户确认：
```markdown
### 📋 UI 六态补全与边界设计确认

| 状态 | Figma 原稿是否存在 | 建议补全方案 |
| :--- | :---: | :--- |
| **1. 正常态 (Loaded)** | ✅ 存在 | 按照设计稿标准满数据渲染 |
| **2. 加载态 (Loading)** | ❌ 缺失 | 建议方案：居中 Activity Indicator 或卡片骨架屏 |
| **3. 缺省态 (Empty)** | ❌ 缺失 | 建议方案：展示空盒子图标 + "暂无数据" + 刷新按钮 |
| **4. 异常态 (Error)** | ❌ 缺失 | 建议方案：展示错误插画 + 错误信息 + 明确的"重试"按钮 |
| **5. 边界保护 (Boundary)** | ❌ 缺失 | 标题超长截断（2 行尾随省略），右侧按钮设置抗压缩 |
| **6. 交互防抖 (Debounce)** | ❌ 缺失 | 核心操作按钮增加 0.5s 防重复点击保护 |

请确认以上补全方案是否符合您的预期？（确认后我将开始生成代码）
```

### 3. 生成代码（用户确认后执行）
- **`XxxViewController.swift`**：继承 `LabBaseViewController`，使用 SnapKit 纯代码构建布局，实现统一的 `func render(_ state: XxxViewState)` 渲染入口；
- **`XxxViewModel.swift`**：使用 `@MainActor` + Combine，声明清晰的 `ViewState` 枚举驱动视图。

### 4. 生成像素级验收快照测试
- 在 `XClientLabTests/` 目录下生成对应的 `XxxSnapshotTests.swift`；
- 使用 `SnapshotTesting` 库生成针对 375pt 基准宽度的视觉对比用例。

### 5. 质量校验
- 运行 `make lint` 确保 0 Error；
- 检查是否存在任何强制拆包（force unwrap）或主线程阻塞隐患。
