---
description: 只读分析能耗、网络与 GPU 使用
argument-hint: "[页面/场景与录制时长]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读分析能耗、网络与 GPU 使用。不修改代码。

1. 明确 `$ARGUMENTS` 场景与时长；默认 30～60 秒。
2. 自检；attach 已运行 app；说明能耗结论受设备、亮度、网络影响，不能跨设备比较。
3. 用 `Power Profiler` 录制；网络密集时加 `Network`；GPU/动画密集时按需用 `tpl "Metal System Trace"`。
4. 导出对应表：能耗影响、CPU/GPU 活动、网络请求与字节数、唤醒/定位/显示。
5. 结合源码定位高频轮询、定时器、WebSocket 心跳、图片下载、日志、后台任务。
6. 输出：指标表、3～5 项定位与最小建议；明确哪些是实测、哪些是推断；不编造电量百分比。
