---
description: 只读分析 CPU 热点与调用栈
argument-hint: "[场景/模块，默认合约 K 线]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读分析 CPU 热点。不修改代码。

1. 明确 `$ARGUMENTS` 场景；确认构建配置，并说明 Debug 数值不代表线上。
2. 自检；attach 或 launch。
3. 用 `tpl "Time Profiler"` 录制 15～30 秒覆盖目标操作；确需线程调度/IO 证据时再加 `tpl "System Trace"`。
4. 导出 time-profile；按 self/total 权重排序函数与调用栈，聚合到模块/文件。
5. 回源码定位热点：排序、解析、指标计算、格式化、日志、主线程忙等。
6. 输出：CPU 指标（样本数/占比/线程）、top 栈、3～5 项定位与最小建议；区分实测与推断。
