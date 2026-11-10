---
description: 只读收集并符号化崩溃日志、定位崩溃点
argument-hint: "[时间/设备/复现动作，默认最近一次崩溃]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md`（用 `git rev-parse --show-toplevel` 定位，不要写成相对当前目录的路径——当前会话 cwd 可能是子目录 `MCIBIT/`）和 `.claude/neal/instruments-cli.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读分析崩溃日志并定位。不改代码、不上传日志、不输出令牌或账户参数。

1. 明确 `$ARGUMENTS`：崩溃类型/时间/复现动作/模拟器或真机；为空时取最近一次与本 app 相关的崩溃。
2. 收集日志：
   - 模拟器：`~/Library/Logs/DiagnosticReports/*.ips`，按时间排序，优先匹配本 app 的 bundle id 与版本。
   - 真机：`xcrun devicectl list devices`，用 `device copy from --domain-type systemCrashLogs` 拉到临时目录。
3. 读 `.ips`：首行 JSON 头（app/build/os/exception/termination），再读 backtrace 与各线程；找出崩溃线程。
4. 符号化：有 dSYM 时用 `symbolicatecrash` 或 `atos`；没有 dSYM 时只给系统符号与偏移，明确说明无法还原业务函数名。
5. 分类判断：EXC_BAD_ACCESS/野指针、Swift 运行时（fatalError/数组越界/强制解包）、watchdog 0x8badf00d、jetsam/OOM、主线程死锁、断言、被系统终止。
6. 回溯到源码调用点（文件:行号），给 3～5 个有证据的假设；区分"崩溃栈直接证据"与"推断"。
7. 输出：崩溃摘要表（时间/设备/版本/异常/终止原因）、关键栈、定位、复现条件、最小修复方向、还需哪些信息。
