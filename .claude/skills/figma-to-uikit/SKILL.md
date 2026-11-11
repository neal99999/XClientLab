---
name: figma-to-uikit
description: 从 Figma 设计稿/标注到像素级纯代码 UIKit (SnapKit) 的标准化还原技能。包含 Auto Layout 声明式映射、Design Token 对齐、UI 六态防御矩阵补全、文本边界保护与 Snapshot 快照比对验证。
---

# figma-to-uikit Skill

本 Skill 专用于解决客户端开发中的核心痛点：**如何让 AI 生成的代码既符合现有工程架构（UIKit + SnapKit），又能像素级还原 Figma，并主动补全设计师经常遗漏的异常态、空数据态与极限边界**。

---

## 一、为什么直接把 Figma 截图丢给 AI 会失控？

1. **数值膨胀与反模式**：
   - AI 倾向于直接抄写 Figma 上的绝对尺寸（例如 `make.width.equalTo(143)`），在不同 iPhone 机型（SE / Pro / Pro Max）上极易撕裂；
   - 随处硬编码十六进制色值（`UIColor(hex: "0x1A2B3C")`），彻底破坏工程的 Design System 与暗黑模式支持。
2. **只有“理想态（Happy Path）”**：
   - 设计师通常只提供数据塞满时的完美视觉稿，从不提供空列表、接口报错、网络断开、骨架屏或超长文本截断的样式。
3. **“看着差不多”不是“像素级还原”**：
   - 人眼很难精确发现 2pt 的内边距偏差或 1.2 倍行高差异，只有**机器级快照对比（Snapshot Testing）**才能给出确定性的 0 误差证明。

---

## 二、Figma Auto Layout ➔ SnapKit 声明式映射法则

严禁使用绝对坐标系，必须将 Figma 的 Auto Layout 属性转换为标准的 UIKit / SnapKit 约束：

| Figma 属性 | 布局语义 | UIKit / SnapKit 标准实现 | 严禁的反模式 |
| :--- | :--- | :--- | :--- |
| **Direction: Vertical** | 垂直流式布局 | `UIStackView(axis: .vertical)` 或链式 `top.equalTo(previous.bottom).offset(gap)` | 严禁为内部元素写死绝对 Y 坐标 |
| **Direction: Horizontal** | 水平流式布局 | `UIStackView(axis: .horizontal)` 或链式 `leading.equalTo(previous.trailing).offset(gap)` | 严禁为文字容器写死固定宽度 |
| **Resizing: Fill** | 撑满父容器 | `make.edges.equalToSuperview().inset(padding)` 或 `make.width.equalToSuperview()` | 严禁写死 `width.equalTo(375)` |
| **Resizing: Hug** | 尺寸由内容自适应 | 依赖 `intrinsicContentSize`，设置 `setContentHuggingPriority(.defaultHigh, for: .horizontal)` | 严禁多余添加 `width.greaterThanOrEqualTo` |
| **Resizing: Fixed** | 确定几何图形 | `make.size.equalTo(CGSize(width: w, height: h))`（仅限头像、图标、徽章） | 严禁对文本 Label 使用固定宽高 |
| **Gap / Spacing** | 元素间距 | 对齐 4pt / 8pt 网格（8, 12, 16, 24, 32） | 严禁出现 11pt、17pt 等非网格随意杂音 |

---

## 三、Design Tokens 强制映射表

在生成代码前，AI 必须查表将视觉属性替换为工程已有的 Design Tokens：

### 1. 颜色 Token (严格遵循 LabUI / ThemeManager)
*   页面底色 ➔ `LabUI.backgroundPrimary`
*   卡片底色 ➔ `LabUI.backgroundSecondary`
*   主标题文字 ➔ `LabUI.textPrimary`
*   二级说明文字 ➔ `LabUI.textSecondary`
*   弱提示与占位符 ➔ `LabUI.textTertiary`
*   主题品牌色 ➔ `LabUI.violet` / `LabUI.cyan`
*   警告与危险色 ➔ `LabUI.amber` / `LabUI.coral`
*   成功与安全色 ➔ `LabUI.mint`

### 2. 字体与行高 Token
*   超大标题 (Display) ➔ `LabUI.font(24, weight: .bold)`
*   模块标题 (Title) ➔ `LabUI.font(16, weight: .bold)`
*   正文内容 (Body) ➔ `LabUI.font(13, weight: .regular)`
*   数字与行情 (Mono) ➔ `LabUI.font(12, weight: .semibold, mono: true)`
*   辅助标签 (Caption) ➔ `LabUI.font(10, weight: .medium, mono: true)`

---

## 四、UI 六态防御矩阵（The 6-State Matrix）

任何 UI 需求进入编码阶段，AI **必须**主动推导并实现以下 6 种状态，缺一不可：

```
                ┌────────────────────────────────────────────────────────┐
                │                  UI 六态防御矩阵                       │
                └───────────────────────────┬────────────────────────────┘
                                            │
   ┌────────────────┬───────────────────────┼───────────────────────┬────────────────┐
   ▼                ▼                       ▼                       ▼                ▼
【1. 加载态】     【2. 成功态】           【3. 缺省态】           【4. 异常重试态】 【5. 边界极端态】
Loading / Shimmer   Loaded (正常满数据)      Empty (空数据提示文案)   Error & Retry   超长文本/大数防截断
```

1. **加载态 (Loading)**：骨架屏（Shimmer）或居中 `UIActivityIndicatorView`；加载过程中锁定交互，防止重复触发。
2. **正常满数据态 (Loaded)**：Figma 设计稿呈现的标准数据视图。
3. **缺省空数据态 (Empty)**：无记录时展示居中占位图、说明文案及“去添加/刷新”按钮。
4. **异常态与重试闭环 (Error & Retry)**：网络断网、接口超时或解析错误时展示友好错误面板，必须提供显式的“点击重试（Retry Action）”闭环。
5. **极端数据与边界防护 (Boundary & Extreme)**：
   - 超长文本：标题超长 50 字必须配置 `numberOfLines = 2` 与 `lineBreakMode = .byTruncatingTail`；
   - 按钮挤压：右侧按钮设置 `setContentCompressionResistancePriority(.required, for: .horizontal)`，防止文字把按钮挤出屏幕；
   - 资金大数：大金额 Label 必须开启 `adjustsFontSizeToFitWidth = true` 与 `minimumScaleFactor = 0.75`。
6. **交互防抖态 (Interaction & Debounce)**：所有关键提交按钮必须包含 0.5 秒防抖（Throttle），避免连击提交重复数据。

---

## 五、架构模式：ViewState 单向状态机

禁止在控制器中散落大量的 `view.isHidden = true/false`，必须采用单向枚举状态机：

```swift
enum MyPageViewState {
    case loading
    case loaded(MyDataModel)
    case empty(title: String, subtitle: String)
    case error(message: String, retry: () -> Void)
}

final class MyViewController: LabBaseViewController {
    // 整个页面仅暴露唯一的渲染入口，杜绝状态冲突
    func render(_ state: MyPageViewState) {
        loadingView.isHidden = true
        contentView.isHidden = true
        emptyView.isHidden = true
        errorView.isHidden = true

        switch state {
        case .loading:
            loadingView.isHidden = false
            loadingView.startAnimating()
        case .loaded(let model):
            contentView.isHidden = false
            contentView.configure(with: model)
        case .empty(let title, let subtitle):
            emptyView.isHidden = false
            emptyView.show(title: title, subtitle: subtitle)
        case .error(let msg, let retry):
            errorView.isHidden = false
            errorView.show(message: msg, retryHandler: retry)
        }
    }
}
```

---

## 六、像素级机器验收：Snapshot 快照比对闭环

为保证 100% 像素级还原，代码编写完成后必须编写对应的快照测试：

```swift
import SnapshotTesting
import XCTest
@testable import XClientLab

final class MyComponentSnapshotTests: XCTestCase {
    @MainActor
    func testComponentLoadedSnapshot() {
        let view = MyComponentCardView()
        view.configure(with: .mockData)
        
        // 像素级比对（允许机器间微小渲染误差 <= 0.5%）
        assertSnapshot(
            matching: view,
            as: .image(precision: 0.995, layout: .fixed(width: 375, height: 180))
        )
    }
}
```

*   **Diff 自动化修正**：若比对失败，读取生成的 `__Snapshots__` 差分图，检查是由于外边距（Padding）还是字号偏差造成，微调 SnapKit 约束，直到 `TEST SUCCEEDED`。
