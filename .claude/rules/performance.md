---
description: XClientLab 性能优化红线：主线程 16ms 帧预算、耗时计算后台化、渲染抗卡顿与内存削峰
paths:
  - "XClientLab/**"
  - "Packages/**"
---
# 性能优化与帧预算规范

## 1. 主线程 16ms 帧预算
- 主线程只负责 **UI 组装、布局计算与事件响应**，严禁在主线程执行耗时操作。
- **长文本正则比对、全量 JSON 反序列化（> 50 条对象）、文件与本地持久化 IO**，必须强制下沉至后台队列（如 `DispatchQueue.global()` 或 Swift Concurrency `Task.detached`）。
- 任何主线程单次运行超过 16ms（120Hz 下超过 8ms）的计算，必须进行分块让出（Chunked Coalescing）或取消保护。

## 2. 渲染性能与过度绘制（Overdraw）
- 减少视图层级嵌套，严禁无意义的容器视图堆叠。
- 静态深色背景统一合成，避免多层半透明 `alpha < 1.0` 视图叠加导致 GPU Blend 负载过重。
- **圆角与遮罩**：严禁高频复用列表中直接使用 `view.layer.cornerRadius + masksToBounds = true`（易触发离屏渲染 GPU 拷贝）；优先使用 CoreGraphics 预渲染圆角，或使用透明覆盖切图。
- 避免全量 `setNeedsDisplay()` / `reloadData()`，盘口高频更新仅对变化脏矩形（Dirty Rect）或局部 Cell / Label 执行精准刷新。

## 3. 高频数据流与时间窗聚合
- 实时行情推流（如 WebSocket > 50 Tick/s）严禁直更 UI；必须配置 **100ms 时间窗节流（Throttle / Debounce）**。
- 单槽合并（Single-slot Coalesce）：当高频事件属于“状态刷新”而非“事件日志”时，主线程只消费最新一帧快照，丢弃中间过期帧。

## 4. 图片加载与降采样
- 异步加载网络或本地大图时，禁止将全尺寸位图直接赋值给 `imageView.image`。
- 必须基于视图物理像素（`pointSize * UIScreen.main.scale`）执行 **ImageIO 降采样（Downsampling）**，杜绝大图解码引起主线程卡顿与 Memory Footprint 锯齿暴涨。
