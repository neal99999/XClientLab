# IBIT Instruments 命令行手册

`/neal-instruments-*` 系列命令的共用事实与流程。先读 `.claude/neal/project-context.md`；本文件只补充 Instruments/xctrace 的可执行细节，不改变只读与报告约定。

## 0. 环境自检（每次先做）

```bash
XC=$(xcode-select -p); echo "$XC"
xcrun xctrace version
ls -d "$XC/Applications/Instruments.app"
xcrun xctrace list templates
xcrun simctl list devices booted
xcrun xctrace list devices
```

包内模板按名字定位，不要硬编码 Xcode 版本：

```bash
APP="$(xcode-select -p)/Applications/Instruments.app"
tpl() { find "$APP/Contents/Packages" -name "$1.tracetemplate" -print -quit; }
TP=$(tpl "Time Profiler"); AL=$(tpl "App Launch"); HI=$(tpl "Animation Hitches")
ST=$(tpl "System Trace"); MT=$(tpl "Metal System Trace")
printf '%s\n' "$TP" "$AL" "$HI" "$ST" "$MT"
```

- 可直接用模板名的标准模板（以 `xctrace list templates` 实际输出为准）：Allocations、Leaks、Network、Power Profiler、File Activity、Swift Concurrency、SwiftUI、CPU Counters、Processor Trace、Core AI、Foundation Models。
- Xcode 27.1 实测：Time Profiler、App Launch、Animation Hitches、System Trace、Metal System Trace 按名字找不到（`Cannot find template matching name: ...`），必须用上面的包内路径配合 `--template <路径>`。
- `xctrace list instruments` 返回 `No instruments found`，不要依赖 `--instrument` 名称。

## 1. 目标与录制方式

| 目的 | 模板 | 建议方式 |
|---|---|---|
| 内存泄漏 | `Leaks` | launch，固定复现动作 |
| 内存峰值/增长 | `Allocations` | launch |
| CPU 热点 | `tpl "Time Profiler"` | attach 或 launch |
| 掉帧/hitch | `tpl "Animation Hitches"` | attach，边操作边录 |
| 启动耗时 | `tpl "App Launch"` | launch，冷启动前先 terminate |
| 系统级线程/IO/调度 | `tpl "System Trace"` | attach |
| 能耗 | `Power Profiler` | attach |
| 网络 | `Network` | attach |
| GPU/动画 | `tpl "Metal System Trace"` | attach |

设备与 app 路径：

```bash
xcrun simctl list devices booted
xcrun simctl listapps booted | grep -i ibit            # 确认 bundle id
APP_PATH=$(xcrun simctl get_app_container <UDID> <bundle id> app); echo "$APP_PATH"
xcrun simctl launch --console-pty <UDID> <bundle id> # 可选：看启动日志
```

录制（输出放临时目录，不要写进仓库）：

```bash
OUT=/tmp/ibit-instr/$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
# attach 已运行进程（pid 用 simctl spawn launchctl list 或 pgrep 确认）
xcrun xctrace record --device <UDID> --template "$TP" --attach <pid> \
  --time-limit 25s --output "$OUT/run.trace" --no-prompt
# 或由 xctrace 启动 app
xcrun xctrace record --device <UDID> --template "$TP" \
  --launch -- "$APP_PATH" --time-limit 25s --output "$OUT/run.trace" --no-prompt
```

真机把 `--device <UDID>` 换成 `xcrun xctrace list devices` 里的真机名或 UDID；未连接时如实说明。

## 2. 导出与解析（先 TOC，再按 schema 取表）

```bash
xcrun xctrace export --input "$OUT/run.trace" --toc --output "$OUT/toc.xml"
python3 - "$OUT/toc.xml" <<'PYPARSE'
import sys, xml.etree.ElementTree as ET
for t in ET.parse(sys.argv[1]).getroot().iter('table'):
    print(t.get('schema'), '|', t.get('name'))
PYPARSE
```

按 TOC 里真实存在的 schema 导出，不猜表名：

```bash
xcrun xctrace export --input "$OUT/run.trace" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="<schema>"]' > "$OUT/table.xml"
```

- 大表用 `ET.iterparse` 流式解析，先统计行数再抽样，避免一次性打印几十万行。
- 表不存在、schema 变化或导出失败：报告实际 TOC 内容并停止该步，不要编造指标。
- 所有数值必须能指回 trace 文件与表名。

符号化：

```bash
xcrun xctrace symbolicate --input "$OUT/run.trace" --output "$OUT/run-sym.trace" --dsym <dSYM 路径或目录>
```

## 3. 崩溃日志

```bash
ls -lt ~/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head
xcrun devicectl list devices
xcrun devicectl device copy from --device <UDID> --source . \
  --destination "$OUT/crash" --domain-type systemCrashLogs
```

`.ips` 首行是 JSON 头，之后是 backtrace。符号化：

```bash
"/Applications/Xcode.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources/symbolicatecrash" \
  crash.ips <App>.app.dSYM > crash.txt
atos -o <App>.app.dSYM/Contents/Resources/DWARF/<App> -arch arm64 -l <loadAddress> <address> ...
```

没有 dSYM 时只给系统符号与偏移，明确说明无法还原业务函数名。

## 4. 已知问题与 fallback

- Xcode 27.1 本机实测：`xctrace record`（含 `--show-recording-options`）报
  `Assertion failed: (_coreForNextRun != core), function -[XRAugmentationManager resetAnalysisCoreForPreflight:], file XRAugmentationManager.m, line 90`，生成的 `.trace` 为空。
  处理：先 `open -a "$APP"` 让 Instruments 完成一次初始化，再重试一次；仍失败就改用 Instruments GUI 录制同名模板，保存 `.trace` 后用 `xctrace export` 只读分析。不要反复重试或改系统/权限配置。
- `xcrun xctrace list devices` 为空：先 `open -a Simulator` 或 `xcrun simctl boot <name>`；真机需连接、信任、开启 Developer Mode。
- 录制会写 `~/Library` 等目录；在被沙箱限制的环境里可能失败，改在终端或 Claude Code 的普通 Bash 中执行。
- Debug 构建的性能数字不代表线上；指标必须连同构建配置、设备型号、系统版本一起报告。
- 录制会产生较大的 `.trace` 文件：默认放 `/tmp/ibit-instr/`，分析结束提醒用户可删除；不要提交进仓库。

## 5. 报告要求

- 中文、结论先行；默认 3～5 项，每项含：严重程度、已确认/待验证、文件:行号、证据（trace 表/行/调用栈）、触发条件、影响、最小建议、验证方法。
- 明确区分"实测"与"静态推断"；没有采到数据就写没采到，不补数字。
- 只读：不修改代码、配置或工程文件，不自动构建、不签名、不上传日志、不输出令牌或账户参数。
