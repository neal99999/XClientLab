---
name: review-pr
description: 对当前分支的 git diff 做只读代码评审，对照 XClientLab 架构红线（资金精度、并发线程、主线程帧预算、UI六态、模块依赖）逐条提取代码证据。当用户需要审阅改动、提交 PR 前把关、评估上线风险时使用。
---

# review-pr Skill

对当前改动进行只读审查。目标是**先找出会让用户亏钱、线上 Crash、主线程掉帧、多线程死锁的问题，绝不在代码风格与格式上制造噪音**。

---

## 1. 确定审查范围

收集改动上下文（先看统计再读具体文件，避免撑爆上下文）：

```bash
git rev-parse --abbrev-ref HEAD
git status --short
git diff --stat
git diff --cached --stat
git diff --stat main...HEAD
```

随后按文件取 diff：`git diff -- <path>`（或 `git diff main...HEAD -- <path>`）。

---

## 2. 审查依据（必须严格遵循）

- 根目录 [`CLAUDE.md`](file:///CLAUDE.md)
- 六大架构规范目录 [`.claude/rules/`](file:///.claude/rules/)：
  - `financial-precision.md`：资金大数精度、非幂等重试禁令、单调 Sequence ID；
  - `performance.md`：主线程 16ms 帧预算、耗时计算下沉后台、ImageIO 降采样；
  - `concurrency-and-memory.md`：逃逸闭包 `[weak self]`、Timer 生命周期释放、锁粒度最小化；
  - `architecture.md`：纯代码 UIKit + SnapKit、UI 六态交付矩阵、模块单向依赖；
  - `testing.md`：单元/快照测试验证与客观证据链。

---

## 3. 按严重度优先级审查清单

### 3.1 资金与价格计算（最高阻断优先级 P0 BLOCKER）
- 金额/标价/保证金是否使用了 `Double` 或 `Float` 进行运算；
- 下单、撤单、平仓等写入接口是否擅自增加了超时无脑重试；
- 订单与推送状态是否缺少单调递增 `Sequence ID` 检查，是否可能导致成交状态倒退回挂单中。

### 3.2 线程与内存生命周期（P0 BLOCKER / P1 MAJOR）
- 异步闭包、Combine `sink`、`Task` 是否遗漏了 `[weak self]`；
- `Timer` / `DispatchSourceTimer` 是否未在销毁时显式 `cancel()`；
- 共享可变变量是否未受锁或 Actor 保护（警惕 `counter.pointee += 1` 的假原子性）。

### 3.3 性能与卡顿风险（P1 MAJOR）
- 主线程是否执行全量 JSON 反序列化（> 50 条对象）或正则；
- 高频 WebSocket 行情（> 50 Tick/s）是否缺少 100ms 节流与单槽合并；
- 图片加载是否缺少基于视图像素的目标尺寸降采样；
- 列表滚动中是否频繁调用 `setNeedsDisplay` 或使用 `masksToBounds` 导致离屏渲染。

### 3.4 交付完整性与 UI 六态（P1 MAJOR）
- 新功能是否完整覆盖 **Loaded / Loading / Empty / Error / Offline / Boundary** 六种状态；
- 是否遵循单向数据流 `ViewState ➔ render(_:)`。

---

## 4. 交付报告格式

审查完成后输出结构化评级报告（参考 `code-reviewer` 输出模板），明确标识是否通过，并给出可验证的最小修复建议。
