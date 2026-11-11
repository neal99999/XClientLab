---
description: 只读分析卡顿与主线程阻塞
argument-hint: "[操作路径，默认 K 线切周期/高频更新]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读分析卡顿与主线程阻塞。不修改代码。

1. 明确 `$ARGUMENTS` 的操作路径；为空时默认合约 K 线切周期与高频刷新。
2. 自检设备与 app；优先 attach 已运行进程，避免把启动阶段算进卡顿。
3. 快速预检（可选）：`sample <pid> 3 1` 看主线程栈（以本机可用为准）；随后用 `tpl "Time Profiler"` 录制 15～30 秒，覆盖卡顿动作。
4. 导出 time-profile 与线程相关表；按主线程栈聚合权重，找耗时函数和阻塞点：锁等待、同步 IO、布局、图片解码、大循环、主线程网络或数据库。
5. 回源码定位调用点，判断是计算量、锁、IO 还是刷新风暴。
6. 输出 3～5 项：文件:行号、证据（采样/调用栈）、复现条件、影响、最小建议、验证方法；区分实测与推断，说明 trace 不能证明的部分。
