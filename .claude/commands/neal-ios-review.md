---
description: 只读审查 UIKit 代码的正确性、线程、复用和异常边界
argument-hint: "[文件/模块，默认当前业务代码 diff]"
disable-model-invocation: true
---

先读取 `.claude/neal/project-context.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读。无参数优先检查当前 staged 与 unstaged 业务代码 diff，并读取相关调用上下文；无 diff 时选择合约 K 线入口并说明范围。检查循环引用的完整持有链、UIKit 主线程、共享状态同步、Cell 复用与异步图片错位、索引边界、可选值、错误/取消/重试状态、金额精度和重复提交。内存或性能专项问题只指出证据与后续验证，不重复输出多份报告。

输出检查范围、按严重程度排列的最多 5 项发现及验证步骤；逐条给出共用规则要求的证据。没有确定问题就明确说明，不把风格偏好当 bug。不修改代码。
