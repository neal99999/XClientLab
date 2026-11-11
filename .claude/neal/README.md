# Neal 的 IBIT 命令

这些是本仓库的 Claude Code 项目命令，文件在 `.claude/commands/`；从仓库根目录打开 Claude Code 后，输入 `/neal-` 查看。若当前会话未发现新命令，重新打开项目会话检查。命令内容仍受当前工具权限和模型指令执行情况约束；只读约定不是硬沙箱。

| 命令示例 | 用途 | 修改代码 |
|---|---|---|
| `/neal-trace-flow 行情订阅` | 页面→请求/推送→合并→UI | 否 |
| `/neal-check-market-data 合约 K 线` | 合并、乱序、切换和恢复 | 否 |
| `/neal-ios-review` | 默认检查当前业务 diff | 否 |
| `/neal-check-performance K 线高频更新` | 计算、刷新和渲染 | 否 |
| `/neal-check-memory 合约 K 线详情` | 持有链和资源释放 | 否 |
| `/neal-fix-bug 周期切换后旧响应覆盖新图表` | 最小修复与验证 | 是 |
| `/neal-add-uikit-page 币种详情页，入口为行情列表` | UIKit 页面与状态 | 是 |
| `/neal-prepare-interview` | 三个实际模块的展示材料 | 否 |
| `/neal-interview-scenarios` | 异常场景与演示准备表 | 否 |
| `/neal-instruments-help` | 自检 Instruments 环境并推荐仪器命令 | 否 |
| `/neal-instruments-memory 合约 K 线详情` | 泄漏、峰值与增长 | 否 |
| `/neal-instruments-hang K 线切周期` | 卡顿与主线程阻塞 | 否 |
| `/neal-instruments-fps 行情列表滚动` | 掉帧与 hitch 指标 | 否 |
| `/neal-instruments-crash` | 崩溃日志收集、符号化与定位 | 否 |
| `/neal-instruments-cpu 首页刷新` | CPU 热点与调用栈 | 否 |
| `/neal-instruments-launch` | 冷/热启动阶段耗时 | 否 |
| `/neal-instruments-energy 行情页` | 能耗、网络与 GPU | 否 |

建议先追踪链路，再专项检查，选定问题后修复。默认输出 3～5 个重点，要求全量时可在参数中说明。

共用规则与源码导航在 `project-context.md`。没有预置首轮发现，避免后续审查照抄已过期结论。

Instruments 系列基于 `xctrace` 与 Instruments 模板，模板路径、录制/导出/符号化流程、已知问题与 fallback 都在 `instruments-cli.md`。需要本机安装 Xcode/Instruments；录制产物默认写到 `/tmp/ibit-instr/`，分析结束可删除。前缀是 `neal-instruments-`（不是 `instrumens`）。

## 在 Codex 中使用

这批文件不会自动给 Codex 注册同名斜杠命令。可以直接说：

> 读取并执行 `.claude/commands/neal-check-market-data.md`，将参数设为“合约 K 线”；读取其中指定的共用规则。

## 验证范围

创建时检查文件数量、frontmatter、参数占位符、共用文件链接与源码导航是否存在。之前已人工阅读合约 K 线链路；这不等于新命令已在 Claude Code 中实际调用，也不等于已做运行时性能或内存验证。

Claude Code 官方格式参考：https://code.claude.com/docs/en/skills
