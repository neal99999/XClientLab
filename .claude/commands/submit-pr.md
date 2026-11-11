---
description: 提交 PR 标准工作流——本地自动化自测 → 独立上下文 AI 预审（降噪与风险分级）→ 人类确认 → 提 PR
argument-hint: "[目标基线分支，默认 main]"
disable-model-invocation: true
---

先读取仓库根目录的 `.claude/neal/project-context.md` 并遵守共用规则。
本命令严格遵循 `.claude/workflows/submit-pr.md` 定义的标准操作程序（SOP）。

# 目标基线分支
`$ARGUMENTS` 为目标分支名（例如 `main` 或 `develop`），若未提供则默认使用 `main`。

# 执行步骤

1. **环境与改动核查**：
   - 运行 `git status --short` 确认工作区是否有未暂存/未提交的代码；
   - 确认当前分支及基线分支（`$ARGUMENTS` 或 `main`）；
   - 查看改动概览：`git diff --stat <base>...HEAD` 与 `git log <base>...HEAD --oneline`。若无任何改动，提示用户并停止。

2. **自动化自测门禁**：
   - 运行代码检查：`make lint`；
   - 运行测试用例（如 `make test` 或说明验证方式）；
   - 检查代码格式：`make format-check`。
   - 任何一项出错，展示错误证据并立刻停止，不得继续。

3. **换脑独立预审（降噪与分级）**：
   - 以独立只读审查员视角检视 `git diff <base>...HEAD`；
   - 遵循降噪原则：不提代码缩进、格式等已由工具处理的琐碎问题；
   - 检查致命隐患：目标达成度、跨模块破坏、金额大数运算、并发线程安全、强引用环；
   - 输出风险分级（🟢 低风险 / 🟡 中风险 / 🔴 高风险）。

4. **人类掌舵（关键停顿）**：
   - 汇总生成《PR 准备就绪报告》（改动范围、自测证据、AI 预审意见与风险评级、拟定 PR 标题和正文）；
   - **向用户展示报告，并明确暂停等待用户确认**；
   - 严禁未经用户许可擅自推送分支或创建 PR。

5. **执行创建（用户确认后）**：
   - 推送分支：`git push -u origin <当前分支>`；
   - 调用 `gh pr create` 创建 PR；
   - 输出 PR 网页 URL 及后续 Merge Queue / CI 观察提示。
