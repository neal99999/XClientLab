---
name: hitch-stall-profiler
description: 专门用于排查 iOS 主线程卡顿与掉帧（对应场景 1.1）。基于 CADisplayLink / HitchMonitor 指标与 Time Profiler 采样，区分 CPU 密集型与主线程阻塞等待，定位耗时调用栈并指导分块与协同让出重构。
---

# hitch-stall-profiler Skill

本 Skill 对应 App 内「01 性能优化 → 1.1 主线程 JSON + 正则同步阻塞」，专用于排查客户端滑动掉帧、UI 挂起（Hang）以及主线程卡顿问题。

---

## 一、排查核心痛点与反模式

1. **盲目异步化（Blind Async）**：
   - 看到卡顿就直接套 `DispatchQueue.global().async` 或 `Task.detached`，极易破坏 UI 刷新时序、引发多线程数据竞争（Data Race）或状态穿透。
2. **凭空猜测热点**：
   - 凭代码直觉猜“这个 Auto Layout 约束可能太慢”，忽视了真正的耗时往往在隐蔽的大对象序列化、全量正则或大数组排序中。
3. **缺少帧预算意识**：
   - 60Hz 屏幕单帧预算仅为 **16.6ms**（120Hz ProMotion 仅为 **8.3ms**）。主线程任何超过该阈值的同步执行都会直接产生用户可感知的 Hitch。

---

## 二、指标模型与取证命令链

### 1. 指标切入（HitchMonitor）
XClientLab 内部使用 `HitchMonitor`（基于 `CADisplayLink` 采样）输出以下客观数据：
- **Worst Hitch (ms)**：单次最长阻塞时间（例如 >500ms 即触发严重冻结）；
- **Blocked Total (ms)**：压测周期内主线程累计挂起时间；
- **Hitch Ratio (ms/s)**：每秒画面产生的掉帧时间（苹果推荐工业级指标 <5ms/s 为优秀）。

### 2. Time Profiler 取证纪律
若在 CI 或本地用命令行取证：
```bash
# 录制 5 秒 Time Profiler 采样
xctrace record --template 'Time Profiler' --attach <ProcessName> --time-limit 5s --output ./HitchProfile.trace
```

### 3. 区分两类瓶颈（CPU Bound vs Wait Bound）
在分析调用栈时，必须首先定性：
*   **CPU 密集型（CPU Bound）**：
    - 主线程 CPU 占用率接近 100%；
    - 典型根因：循环解析大 JSON（`JSONSerialization`）、全量正则回溯匹配（`NSRegularExpression`）、大集合快速遍历排序。
*   **主线程等待（Wait Bound / Blocked Time）**：
    - 主线程 CPU 占用率低，但耗时极长；
    - 典型根因：主线程等待锁（`os_unfair_lock` / `semaphore.wait()`）、主线程同步读写磁盘或网络（`Data(contentsOf: url)`）。

---

## 三、代码级审查清单

在审查疑似卡顿代码时，按以下优先级检查：

1. **序列化与文本解析**：
   - 是否在主线程一次性反序列化数千条记录；
   - 是否对长文本重复初始化 `NSRegularExpression`（正则对象创建极其昂贵，必须静态化复用）。
2. **集合操作与内存拷贝**：
   - 循环内是否频繁对大数组做连续 `filter / map`，生成多份昂贵的大数组中间态副本；
   - 是否在主线程做大字典的深拷贝（Deep Copy）。
3. **UI 布局与图层重建**：
   - 是否在每次数据刷新时执行 `removeAllSubviews()` 并重新创建约束；
   - 是否触发了离屏渲染（圆角 + 遮罩 `masksToBounds` + 动态阴影未指定 `shadowPath`）。

---

## 四、治理与重构标准范式

重构代码时必须遵循以下工程化范式：

```swift
// 推荐重构范式：分块 (Chunking) + 协同取消检查 (Cancellation Check) + 增量上屏
Task.detached(priority: .userInitiated) {
    let chunkSize = 500
    for chunk in rawData.chunks(ofCount: chunkSize) {
        // 1. 支持及时取消，避免旧任务无谓消耗 CPU
        try Task.checkCancellation()
        
        // 2. 增量解析处理
        let parsed = chunk.map { parseItem($0) }
        
        // 3. 聚合结果后切回主线程上屏
        await MainActor.run {
            self.appendItems(parsed)
        }
        
        // 4. 协同让出执行权，让高优先级任务先跑
        await Task.yield()
    }
}
```

---

## 五、Agent 交付报告模板

```markdown
### ⏱️ 主线程卡顿取证报告

- **卡顿等级**：CRITICAL (>500ms) / HIGH (>100ms) / MEDIUM (>16ms)
- **客观指标**：Worst Hitch: `X ms` | Blocked Total: `Y ms` | 丢帧率: `Z frames/s`
- **瓶颈定性**：[CPU 密集型 / 主线程等待与锁阻塞]
- **热点调用栈**：
  ```text
  1.0  AppDelegate -> runStress()
  0.8    JSONSerialization.jsonObject()  <-- 瓶颈所在 (80% 耗时)
  0.2    NSRegularExpression.enumerateMatches()
  ```
- **根因分析**：说明主线程单次处理规模与缺乏分块机制。
- **推荐治理**：[分块流式解析 / 正则静态复用 / 增量局部刷新]。
```
