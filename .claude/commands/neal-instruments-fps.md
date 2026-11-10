---
description: 只读分析掉帧与 hitch 指标
argument-hint: "[滚动/动画/高频刷新场景]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读分析掉帧与刷新流畅度。不修改代码。

1. 明确 `$ARGUMENTS` 的滚动/动画/高频刷新场景；为空时默认行情列表滚动与合约 K 线高频更新。
2. 自检；attach 已运行 app，避免冷启动干扰。
3. 用 `tpl "Animation Hitches"` 录制 20～30 秒，期间执行目标操作 2～3 轮。
4. 导出 hitch 相关表：hitch 次数、hitch 时长或占比、涉及帧；统计均值/最大值。表缺失时报告实际 schema 并停止该步，不编造 FPS。
5. 说明限制：xctrace 27.1 标准模板没有 Core Animation FPS 表；要绝对 FPS 需 Instruments GUI 的 Core Animation，或临时用 CADisplayLink 采样（后者要改代码，必须用户明确同意）。
6. 定位：布局/约束、图片解码与缩放、文字排版、图层合成、主线程重活、刷新频率过高、重复 reload。
7. 输出：结论先行；hitch 指标表与证据；3～5 项代码定位与最小建议；明确写"未测绝对 FPS"。
