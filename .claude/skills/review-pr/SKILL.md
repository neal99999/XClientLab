---
name: review-pr
description: 对当前分支的 git diff 做只读评审，按 IBIT iOS 项目规范（金额大数运算、主线程、主题/国际化、WebSocket 订阅、Pods 边界、下单幂等）逐条给证据。当用户说“review 一下”“看看这次改动”“提 PR 前帮我把把关”“自审 diff”“这段改完有没有坑”，或准备合并/提交当前改动时使用。也适用于指定文件、路径或 base 分支的评审。
---

# review-pr

只读评审当前改动。目标是先找出会让用户亏钱、崩溃、串数据的问题，其次才是风格。不改代码、不提交、不推送。

## 1. 确定范围

先看用户给了什么范围：

- 无参数：审 `staged + unstaged`；两者都为空时审 `main...HEAD`（整个分支）。
- 给了路径/文件名：只审该路径的 diff。
- 给了 base 分支（如 `develop`）：审 `<base>...HEAD`。
- 给了 PR 号：用 `gh pr diff <n>`，并说明这是远端内容。

收集命令（先统计再逐文件读，避免一次灌爆上下文）：

```bash
git rev-parse --abbrev-ref HEAD
git status --short
git diff --stat
git diff --cached --stat
git diff --stat main...HEAD
```

随后按文件取 diff：`git diff -- <path>`（或 `git diff --cached -- <path>`、`git diff main...HEAD -- <path>`）。

注意：

- 二进制、资源文件（图片、plist、strings、xcodeproj、Podfile.lock）只看变更摘要，不逐行评审。
- `.claude/`、`docs/`、`Scripts/` 的改动按文档/脚本标准审，不套用业务代码规则。
- diff 太大时（超过约 2000 行）先按模块分批，并在报告里写明“本轮只覆盖 X 个文件、Y 行”，不要假装全量审过。

## 2. 先读规范

动手前读这两份，它们是评审依据，不是背景材料：

- 根目录 `CLAUDE.md`
- `.claude/neal/project-context.md`

规范与代码冲突时以当前源码为准，但要在报告里指出“代码现状与文档不一致”。

## 3. 按维度评审

按下面的顺序看，前面的问题优先报：

### 3.1 资金与精度（最高优先级）

- 金额/数量是否用 String 大数扩展（`bigAddContract`、`bigSubContract`、`bigMulContract` 等），而非 `Double`/`Float`/`NSDecimalNumber` 混算。
- 是否有隐式 `Double(...)`、`Float(...)`、`String(format:)` 参与资金计算。
- 精度、小数位是否写死；是否该取币对精度却用了常量。
- 下单/撤单是否被无条件重试；超时是否被当成失败处理。下单接口非幂等。

### 3.2 线程与生命周期

- UIKit 更新是否在主线程；网络/WebSocket 回调线程是否被想当然当成主线程。
- 闭包是否漏了 `[weak self]`；`Timer`、通知观察者、delegate 是否造成强持有环。
- 页面消失、退登、前后台切换时是否清理定时器、观察者、订阅。
- 是否有主线程写、后台读（或反之）的共享字段，例如缓存、`currentInterval`、单例状态。

### 3.3 数据与订阅一致性

- 切币对、切周期、页面消失、退登、前后台切换时是否退订旧 channel。旧频道不退会串币、重复推送。
- 频道名是否走 `MCWebSocketConfig` 的生成方法，而不是手拼字符串。
- 异步请求是否有“响应晚到”保护：请求序号、symbol/interval 快照、回调前校验。
- 缓存/去重集合（如 `mergedBSIds`、分页游标）在切币对或切周期时是否复位。
- 数组/字典跨线程访问是否有同步策略，且该策略是否真的覆盖了读写两侧。

### 3.4 主题与国际化

- 新增颜色/图片 key 是否三处同步：`WhiteTheme.plist`、`BlackTheme.plist`、`MLThemePathKey`。
- UI 取色是否用 `theme_*` 属性，而不是写死 `UIColor`。
- 新文案是否用 `.localized()`，并补全所有 `.lproj`（en / zh-Hans / zh-Hant）。
- 切换语言会重建 TabBar 和部分导航栈，改动全局导航时要提示回归。

### 3.5 布局与资源

- 尺寸是否用 `MCFIT()`，而不是写死 pt。
- 图片是否走 Kingfisher，SVG 是否走 SVGKit。
- 新页面是否继承 `MCBaseViewController`，是否优先复用了 `Services/DesignSystem` 里的组件。

### 3.6 架构边界

- 是否修改了 `Pods/` 里的源码。除内置的 CHKLineChart 外都不允许。
- 改动 CHKLineChart 是否限定在 `Core/ThirdParty/CHKLineChart/`，而不是去改 pod。
- 是否绕过分层直接跨模块引用（App/Core/Services/Mediator/Modules）。
- 是否引入了 SwiftUI、新的第三方库或未锁版本的依赖。

### 3.7 安全与日志

- 是否打印 token、签名、资产、订单参数、用户隐私。
- 是否硬编码密钥、证书口令、内网地址。
- 新增网络请求是否走现有 Provider 与 SSL Pinning，而不是裸 `URLSession`。
- 是否扩大了 `Info.plist` 的明文 HTTP 放行范围。

### 3.8 可维护性

- 是否有与本次改动无关的重构、格式化、废弃 API 清理。项目存在大量已知告警，顺手清理会放大回归面。
- 是否有重复实现（项目里已有却新写一遍）。
- 错误是否被静默吞掉；失败分支是否有用户可感知的反馈。

## 4. 输出

先用一句话给结论（能不能合、最大风险是什么），再列发现。默认最多 5 项，用户要全量时才展开。每项格式：

```
### [严重度] 标题
- 位置：文件:行号 / 方法名
- 证据：引用关键代码或调用链，标明是 diff 新增还是原有代码
- 触发条件：什么操作/时序会命中
- 影响：用户或数据层面会发生什么
- 最小建议：改哪里、怎么改，不展开成重构方案
- 验证：怎么复现、怎么确认修好了
```

严重度：

- **CRITICAL**：资金错误、数据丢失、崩溃、安全漏洞。阻塞合并。
- **HIGH**：确定的逻辑 bug、串数据、线程问题。建议合并前修。
- **MEDIUM**：可维护性、边界遗漏、错误处理缺失。
- **LOW**：风格、命名、注释。

状态必须区分：**已确认**（有代码证据）/ **存在风险**（路径成立但未跑到）/ **待验证**（缺运行条件或服务端协议）。

报告末尾固定加两节：

- **已检查未发现问题**：说明覆盖了哪些维度，避免用户误以为没查。
- **未验证与限制**：没编译、没跑 App、没抓包、没有测试 target 等，逐条写清楚，并给出最小验证步骤。

## 5. 红线

- 只读。不要顺手改代码、改配置、改文档，也不要运行有副作用的脚本。
- 不要提交、推送、发包，不要操作真实业务数据。
- 不确定就标“待验证”，不要编造耗时、FPS、内存、覆盖率或测试通过结果。
- 没实际运行的检查，不要说成“已验证”。
- 风格偏好不要包装成 bug；不确定是否问题时放进“建议”，不要放 CRITICAL/HIGH。
