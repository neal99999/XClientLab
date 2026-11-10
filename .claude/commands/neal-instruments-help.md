---
description: 自检 Instruments/xctrace 环境并给出仪器命令索引与参数建议
argument-hint: "[可选：模块/页面/场景，用于推荐命令]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读自检并给出 Instruments 命令索引。不录制、不构建、不改代码。

1. 按 `instruments-cli.md` 第 0 节执行自检，收集：Xcode 路径与版本、xctrace 版本、可用模板、包内模板路径、booted 设备、真机。
2. 输出索引表：功能 | 命令 | 前置条件 | 产出 | 是否产生录制文件。覆盖 help/memory/hang/fps/crash/cpu/launch/energy 八条。
3. 结合 `$ARGUMENTS`（可为空）推荐 1～2 条命令与写法；参数是模块/页面/场景时，一并给出建议的复现动作与录制时长。
4. 报告环境限制：没有设备、没有已安装 app、模板缺失、xctrace 断言；每条都给下一步操作（启动模拟器 / 构建安装 / 按 fallback 处理）。
5. 中文、结论先行；不执行录制，不修改任何文件。
