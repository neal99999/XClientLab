---
name: memory-leak-tracer
description: 专门用于排查 iOS 内存锯齿、瞬时暴涨与对象泄漏（对应场景 1.2）。采用世代分析法 (Generation Analysis) 区分缓存与泄漏，精准排查 Retain Path 循环引用与 @autoreleasepool 缺失。
---

# memory-leak-tracer Skill

本 Skill 对应 App 内「01 性能优化 → 1.2 长列表 + 瞬时大对象分配」，专用于排查客户端常驻内存（Footprint）持续攀升、退出页面内存不降、以及瞬时大内存导致的 OOM（Out Of Memory / Jetsam 杀死）。

---

## 一、排查核心痛点与反模式

1. **混淆“缓存”与“真实泄漏”**：
   - 图片或网络响应暂存在内存字典中是合理的，只要它有明确的上限和清理策略（如 `totalCostLimit` 或收到内存警告时清除）。
   - 真正的泄漏是：**业务流程已经结束、页面已 Dismiss，但对象仍被强引用闭环持有，无法被 ARC 释放**。
2. **只看单次瞬时内存**：
   - 进一次页面发现内存涨了 10MB 就断定泄漏；实际上可能是系统框架首次加载共享动态库或字体缓存。

---

## 二、世代分析法（Generation Analysis 纪律）

必须使用科学的**“三次进出法则”**来确诊是否有真实内存泄漏：

```
[基线 Baseline] ➔ Push 页面 ➔ 执行业务 ➔ Pop 退出 ➔ [标记世代 Gen A]
                ➔ Push 页面 ➔ 执行业务 ➔ Pop 退出 ➔ [标记世代 Gen B]
                ➔ Push 页面 ➔ 执行业务 ➔ Pop 退出 ➔ [标记世代 Gen C]
```

*   **判定标准**：
    - 如果一个对象在 Gen A、Gen B、Gen C 中**持续递增且从不减少**，则 100% 存在内存泄漏；
    - 审查重点不是几千个基础数据类型（如 `String` / `Array`），而是你的业务核心对象（如 `ViewController`、`ViewModel`、`Coordinator`）。

---

## 三、四大致命强引用环审查清单

在审查代码时，按以下清单逐条筛查 Retain Path：

### 1. 闭包捕获未弱化 (`[weak self]`)
*   **高危特征**：`self` 强持有了异步任务或闭包回调，而闭包内部直接访问 `self.property` 或 `self.method()`。
*   **审查关键**：
    ```swift
    // 危险：self 持有 service，service 持有 handler，闭包捕获 self 形成闭环
    self.networkService.fetchData { [weak self] result in
        guard let self = self else { return }
        self.updateUI(result)
    }
    ```

### 2. 定时器与显示链接强持有
*   **高危特征**：`Timer.scheduledTimer(timeInterval:target:selector:...)` 或 `CADisplayLink(target:selector:)` 会强引用传入的 target。
*   **审查关键**：即使在 `deinit` 中写 `timer.invalidate()` 也无济于事，因为定时器持有 target，`deinit` 永远不会被触发！必须在 `viewWillDisappear` 或明确生命周期结束时注销。

### 3. 通知与观察者未注销
*   **高危特征**：使用 block 形式添加通知 `NotificationCenter.default.addObserver(forName:...)` 返回的 token 未在生命周期结束时 `removeObserver`，导致监听 block 及其引用的上下文长期驻留。

### 4. Delegate 未使用 weak
*   **高危特征**：协议委托属性未声明为 `weak`：
    ```swift
    // 危险：
    var delegate: MyComponentDelegate?
    // 正确：
    weak var delegate: MyComponentDelegate?
    ```

---

## 四、瞬时内存暴涨与收缴（Allocations Churn）

针对场景 1.2 中瞬时加载大图或处理数万条记录的循环：

*   **高危特征**：在单一 RunLoop 周期内创建了数万个临时对象，ARC 将它们排队在系统默认的 autoreleasepool 中，导致内存瞬间激增几十兆直至 Jetsam 崩溃。
*   **治理标准范式**：
    ```swift
    for record in largeDataset {
        @autoreleasepool {
            // 在每次小迭代结束时立即销毁临时分配的字符串或解压图像
            let processed = processHeavyRecord(record)
            saveToDisk(processed)
        }
    }
    ```

---

## 五、Agent 交付报告模板

```markdown
### 🧠 内存泄漏与世代分析报告

- **诊断结论**：[存在确认泄漏 / 瞬时锯齿暴涨 / 正常缓存驻留]
- **内存指标**：
  - 初始基线：`A MB`
  - 3 次进入后驻留：`B MB`（净增 `+C MB`）
  - 泄漏对象类型：`XViewController` (存活实例数: 3, 预期: 0)
- **强引用链 (Retain Path) 追踪**：
  ```text
  XViewController (Root)
    └── ViewModel
          └── Closure (Escaping)
                └── [captured strong self] ➔ XViewController  <-- 环路闭合
  ```
- **代码定位**：`FilePath.swift:LineNumber`
- **最小修复方案**：在闭包捕获列表补充 `[weak self]` 或在退出页面时切断持有链。
```
