---
description: 只读检查内存泄漏、峰值与增长趋势
argument-hint: "[页面/模块/操作，默认合约 K 线详情]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读检查内存问题：泄漏、循环引用、峰值和增长趋势。不修改代码，不自动构建。

1. 明确目标：`$ARGUMENTS` 指定的页面/模块/操作；为空时默认 `project-context.md` 的合约 K 线详情链路。
2. 按 `instruments-cli.md` 第 0 节自检；确认 booted 设备、被测 app 的 bundle id 与 `.app` 路径。没有可用构建时说明需要构建并给出命令，等用户确认，不擅自构建安装。
3. 录制两个独立 trace：`Leaks`（泄漏）与 `Allocations`（峰值/增长），各 20～30 秒。录制前写清复现动作（进入页面 → 切换周期/币对 → 返回 → 重复 3 次），录制期间按该动作操作。
4. 先 `xctrace export --toc` 找 leaks/allocations 表，再按 schema 导出并解析；记录对象类型、次数、增长量。导出失败就如实报告，不估算。
5. 对可疑对象回源码追持有链：闭包捕获 self、delegate 强引用、通知未移除、单例或缓存持有、Timer/CADisplayLink、K 线回调与页面生命周期、图片缓存。
6. 输出：结论先行；有泄漏点则按严重程度给 3～5 项。指标表含对象/次数/增长、采样条件、trace 路径；每项含文件:行号、证据、触发条件、影响、最小修复方向、验证方法。区分实测与静态推断，没有实测不下"已确认泄漏"的结论。
