---
description: 只读分析冷/热启动阶段耗时
argument-hint: "[冷启动/热启动/首屏]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读分析启动耗时。不修改代码。

1. 明确 `$ARGUMENTS`：冷启动、热启动或首屏；为空时默认冷启动。
2. 自检设备；用 `tpl "App Launch"` 配合 `--launch -- <app 路径>` 录制；冷启动前先 `xcrun simctl terminate` 结束 app。
3. 导出启动相关表：总时长、pre-main、初始化阶段、首帧；没有对应表就按实际 schema 报告，不编造阶段耗时。
4. 备选（模板不可用时）：`xcrun simctl launch --console-pty` 记录输出时间戳，只能作为粗略参考。
5. 结合源码看 AppDelegate/SceneDelegate、+load/initialize、SDK 初始化、首屏网络与布局。
6. 输出：阶段耗时表、3～5 项定位（文件:行号）、最小建议、验证方法；区分实测与推断。
