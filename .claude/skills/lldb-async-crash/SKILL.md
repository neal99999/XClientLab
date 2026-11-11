---
name: lldb-async-crash
description: 遵循严格通道纪律（确认状态 → 暂停 → 轮询 stopped → 批量取证 → 仅一次恢复）进行 LLDB 异步崩溃现场分析。专用于定位 EXC_BAD_ACCESS、0x1d 极低地址野指针、UAF 释放后使用、死锁及后台队列系统栈崩溃。
---

# lldb-async-crash Skill

本 Skill 对应 App 内「AI-Native → 4.1 通道纪律与 Skills」，专用于处理真实工程中最棘手的**异步系统栈崩溃（如 2.1 场景中的 `EXC_BAD_ACCESS` / `0x1d` 野指针）**。

---

## 1. 为什么必须遵守「通道纪律」？

在异步崩溃现场（例如 `DispatchSourceTimer` 回调或后台并发队列中）：
1. **进程状态不可预测**：Xcode attach 时进程可能仍在 `running`；若此时直接下发 `bt all`，命令会挂起或执行失败，甚至破坏崩溃现场。
2. **符号信息容易丢失**：Crashed Thread 通常只剩 `libdispatch.dylib`、`libsystem_platform.dylib` 或 `_platform_memmove`，业务帧已被优化出栈。
3. **经验容易沦为肌肉记忆**：排查依赖资深工程师的手动操作，难以复用。

**核心铁律**：先确认状态，严格按状态机切换，一次性批量固定现场，`process continue` 仅允许发生一次。

---

## 2. 通道状态机与 8 步纪律

```
[IDLE] ➔ process status ➔ [RUNNING] ➔ process interrupt ➔ 轮询 stopped ➔ [STOPPED]
                                                                            ⬇️
[RESUMED] ⬅️ process continue (仅一次) ⬅️ register read / image lookup ⬅️ bt all 批量取证
```

| 步骤 | 命令 | 目的 | 违规风险（若跳过） |
| :--- | :--- | :--- | :--- |
| **Step 1** | `process status` | 确认当前状态（running 或 stopped） | 盲目操作可能导致进程挂死 |
| **Step 2** | `process interrupt` | **仅在 running 时执行**，挂起进程 | 若已是 stopped 则无须触发 |
| **Step 3** | `process status` | 轮询确认状态进入 stopped（最多 5 次） | 状态未稳定前下发命令会丢失数据 |
| **Step 4** | `thread list` | 建立全线程索引，锁定 Crashed Thread 编号 | 避免只看单线程遗漏死锁关联方 |
| **Step 5** | `bt all` | **一次性**提取所有线程调用栈 | 禁止边单步调试边读栈 |
| **Step 6** | `register read x0 x1 x2 x3` | 读取当前寄存器（针对 ARM64 参数） | 提取内存拷贝中的源地址、目的地址与长度 |
| **Step 7** | `image lookup -a $pc` | 将程序计数器 (PC) 映射到具体二进制及偏移 | 无符号表时定位发生故障的 Mach-O 模块 |
| **Step 8** | `process continue` | **仅一次**恢复进程 | 禁止多次随意 continue 导致二次崩溃 |

---

## 3. 标准批量取证模板 (Batch Script)

AI Agent 或工程师在 attach 后应一次性下发如下批处理序列：

```lldb
# 1. 状态锁定
process status

# 2. 安全中断与全栈留存
process interrupt
thread list
bt all

# 3. 寄存器参数提取（提取关键入参）
register read x0 x1 x2 x3 lr pc

# 4. 寻址反查
image lookup -a $pc

# 5. 退出或恢复
process continue
```

---

## 4. 典型异常现场解读指南

### 4.1 `0x000000000000001d` 极低地址崩溃
*   **现象**：`EXC_BAD_ACCESS (SIGSEGV)`，错误地址落在 `0x1d` 等极低地址。
*   **根因判定**：极低地址不可能为合法堆对象地址。通常是因为指向对象的指针已被释放并清零/被小整数覆盖，随后访问对象属性（如偏移 `+0x1d` 的成员变量）造成越界。
*   **对应场景**：2.1 系统栈 UAF（`DispatchSourceTimer` 被释放后回调仍触发触发野指针访问）。

### 4.2 `_platform_memmove` 崩溃
*   **现象**：崩溃栈顶停留在 `_platform_memmove` 或 `_platform_bzero$VARIANT$Base`。
*   **诊断动作**：检查 `register read x0 x1 x2`：
    *   `x0` (dst)：写入目标地址，若为无效地址则为野指针写入；
    *   `x1` (src)：源数据地址，若为已失效指针则为读已释放内存；
    *   `x2` (length)：拷贝长度，若为一个异常极大值（如 `0xffffffff...`）则为整数溢出。

---

## 5. Agent 交付报告规范

Agent 诊断完成后必须按照以下结构化格式输出报告，**严禁凭空猜测，每项必须有 LLDB 数据作为依据**：

```markdown
### 🚨 LLDB 异步崩溃取证报告

- **崩溃线程**：Thread #N (`crashed`)
- **崩溃指令**：`image lookup` 命中模块 `<Module>` + 偏移 `<Offset>`
- **寄存器现场**：
  - PC: `0x...`
  - X0: `0x...` (目标指针状态分析)
  - X1: `0x...` (源指针状态分析)
- **根因判定**：[已确认 / 存在高度嫌疑]
- **生命周期证据**：指出是哪一个对象的生命周期早于异步回调结束。
- **最小修复方案**：弱引用保护 / 取消句柄提前失效 / 状态机拦截。
```
