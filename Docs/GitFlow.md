# XClientLab Git 工作流（Git Flow）实践指南

> 本文档定义本仓库的分支模型、合并策略、分支保护与发布规范。目标是让 `main` 永远可发布，让每一次合并都可追溯、可回滚。

## 目录

1. [分支模型与职责](#1-分支模型与职责)
2. [分支命名](#2-分支命名)
3. [日常开发：feature 分支](#3-日常开发feature-分支)
4. [发布流程：release 分支](#4-发布流程release-分支)
5. [紧急修复：hotfix 分支](#5-紧急修复hotfix-分支)
6. [合并策略与冲突处理](#6-合并策略与冲突处理)
7. [分支保护与 CI 门禁](#7-分支保护与-ci-门禁)
8. [提交信息与版本 Tag](#8-提交信息与版本-tag)
9. [常见事故清单](#9-常见事故清单)
10. [何时不用 Git Flow](#10-何时不用-git-flow)
11. [本仓库当前状态](#11-本仓库当前状态)

---

## 1. 分支模型与职责

| 分支 | 来源 | 合并去向 | 生命周期 | 核心规则 |
| :--- | :--- | :--- | :--- | :--- |
| `main` | — | — | 永久 | 永远可发布。只接受 `release/*` 与 `hotfix/*`，每次合并打 tag |
| `develop` | `main` | — | 永久 | 集成分支。接收 `feature/*`，代表下一个版本的内容 |
| `feature/*` | `develop` | `develop` | 天级 | 一个需求一条分支，不超过 3 天 |
| `release/*` | `develop` | `main` 和 `develop` | 天～周级 | 功能冻结，只修 bug、改版本号 |
| `hotfix/*` | `main` | `main` 和 `develop` | 小时～天级 | 线上紧急修复，修复后打 patch tag |

要点：

- `main` 与 `develop` 是长期分支，其余分支用完即删。
- `release` 与 `hotfix` 合回 `main` 后，必须再回合到 `develop`。
- 任何分支都不直接把功能代码推到 `main`。

## 2. 分支命名

```text
feature/JIRA-123-short-description
release/1.4.0
hotfix/1.4.1
```

- 一律使用小写英文与半角连字符。
- 有工单号时放在最前面，便于检索。
- 描述控制在 3～5 个单词，不写中文。

## 3. 日常开发：feature 分支

### 3.1 开分支

```bash
git switch develop
git pull --ff-only
git switch -c feature/123-order-retry-guard
```

### 3.2 开发与同步

```bash
# 每天至少同步一次 develop，避免最后一天集中解冲突
git fetch origin
git rebase origin/develop
```

本地提交可以随意整理。推送到远端后，分支已共享，**不再 rebase**，改为合并。

### 3.3 提交与提 PR

```bash
git push -u origin feature/123-order-retry-guard
gh pr create --base develop --title "feat: order retry guard" --body "..."
```

PR 要求：

- 标题符合 `<type>: <description>` 格式。
- 描述写清改动点、影响范围与验证方式。
- CI 全绿后才能合并。
- 合并使用 `--no-ff`，保留分支边界。

### 3.4 收尾

```bash
git switch develop
git pull --ff-only
git branch -d feature/123-order-retry-guard
git push origin --delete feature/123-order-retry-guard
```

## 4. 发布流程：release 分支

`develop` 上的功能达到发版范围后，切出 `release` 分支并冻结功能。

```bash
git switch develop
git pull --ff-only
git switch -c release/1.4.0

# 只允许：版本号、构建号、changelog、发版必需的 bugfix
git commit -m "chore(release): 1.4.0"
git push -u origin release/1.4.0
```

进入 `release` 分支后的规则：

- 禁止合入新功能。新需求一律回到 `develop`，等下一版。
- 修复的 bug 最终也要回合到 `develop`。
- 在 `release` 分支上跑完整回归，包括 `make test` 与真机冒烟。

发布顺序：

```bash
# 1. 合并到 main
gh pr create --base main --title "chore(release): 1.4.0"
# 评审通过后合并，或本地执行
git switch main
git pull --ff-only
git merge --no-ff release/1.4.0

# 2. 打 tag，触发 CD（cd.yml 监听 v* tag）
git tag -a v1.4.0 -m "XClientLab 1.4.0"
git push origin main v1.4.0

# 3. 回合到 develop，否则下一版会漏掉版本号与修复
git switch develop
git pull --ff-only
git merge --no-ff main
git push origin develop

# 4. 删除发布分支
git branch -d release/1.4.0
git push origin --delete release/1.4.0
```

## 5. 紧急修复：hotfix 分支

线上出现 P0/P1 问题时，从 `main` 拉分支，不从 `develop` 拉。

```bash
git switch main
git pull --ff-only
git switch -c hotfix/1.4.1

# 修复 + 补测试
git commit -m "fix: order state race on reconnect"
git push -u origin hotfix/1.4.1
```

合并与发布：

```bash
# 1. 合回 main
git switch main
git pull --ff-only
git merge --no-ff hotfix/1.4.1
git tag -a v1.4.1 -m "XClientLab 1.4.1"
git push origin main v1.4.1

# 2. 合回 develop（关键，漏掉等于下次重新上线 bug）
git switch develop
git pull --ff-only
git merge --no-ff hotfix/1.4.1
git push origin develop

# 3. 清理
git branch -d hotfix/1.4.1
git push origin --delete hotfix/1.4.1
```

## 6. 合并策略与冲突处理

| 场景 | 做法 | 原因 |
| :--- | :--- | :--- |
| `feature` → `develop` | PR + `--no-ff` | 保留一个需求一个合并节点，便于回滚 |
| `release` / `hotfix` → `main` | PR + `--no-ff` + tag | 发布点清晰，可对照 App Store 版本 |
| 同步 `develop` 到本地分支 | `rebase` | 保持线性历史，冲突在自己分支内解决 |
| 同步到已共享的远端分支 | `merge` | 避免改写他人已拉取的历史 |
| 合并冲突 | 在源分支解决 | 不要把冲突留到 `develop` 或 `main` 上 |

禁止事项：

- 禁止在 `main` 或 `develop` 上直接 `rebase`。
- 禁止 `git push --force` 到共享分支。个人分支如需强推，使用 `--force-with-lease`。
- 禁止用 `git merge` 把 `main` 反向合进 `feature` 分支来“同步”。

## 7. 分支保护与 CI 门禁

Git Flow 成立的前提是分支保护。没有门禁时，规则会被逐步绕过。

### 7.1 GitHub 分支保护建议

| 分支 | 保护规则 |
| :--- | :--- |
| `main` | 禁止直接 push；至少 1 个 review；CI 通过；必须走 PR |
| `develop` | 禁止直接 push；CI 通过；必须走 PR |
| `release/*`、`hotfix/*` | 禁止 force push；合并需负责人确认 |

### 7.2 本仓库现有的门禁

- `.github/workflows/ci.yml`：在 push 和 PR 到 `main`、`develop` 时触发。
- `.github/workflows/cd.yml`：监听 `v*` tag，负责打包与分发。
- `.githooks/pre-commit`：提交前对暂存区的 Swift 文件运行 SwiftLint。
- 本地预检：`make verify`（SwiftLint + SwiftFormat 检查）。

初始化钩子：

```bash
make install-hooks
```

## 8. 提交信息与版本 Tag

### 8.1 提交信息

```text
<type>: <description>

<optional body>
```

类型：`feat`、`fix`、`refactor`、`docs`、`test`、`chore`、`perf`、`ci`。

- 一行标题控制在 72 字符内。
- 标题用英文祈使句，首字母小写，句末不加句号。
- 破坏性改动在正文写 `BREAKING CHANGE:`。

### 8.2 版本号

采用语义化版本 `MAJOR.MINOR.PATCH`：

- `MAJOR`：不兼容的接口或行为变更。
- `MINOR`：向下兼容的新功能。
- `PATCH`：向下兼容的 bugfix。

### 8.3 Tag 规范

```bash
git tag -a v1.4.0 -m "XClientLab 1.4.0"
git push origin v1.4.0
```

- 使用带注释的 tag（`-a`），不用轻量 tag。
- tag 只打在 `main` 上，不打在 `develop` 或 `release` 分支上。
- tag 与 App Store / TestFlight 的构建号一一对应，发版记录里写清楚。

## 9. 常见事故清单

| 事故 | 后果 | 预防 |
| :--- | :--- | :--- |
| `hotfix` 只合回 `main`，没合回 `develop` | 下一版重新引入已修复的线上 bug | 合并检查清单里固定包含“回合 develop” |
| `release` 合并后忘了回合 `develop` | 版本号、changelog 丢失 | 发布脚本或 PR 模板加检查项 |
| 在 `release` 分支上继续加功能 | 发布范围失控，回归成本上升 | 功能一律回 `develop` |
| `feature` 分支存活超过一周 | 冲突堆积，评审失真 | 拆小需求，每天同步 `develop` |
| 共享分支被 rebase 或强推 | 他人历史错乱 | 开启分支保护，个人分支用 `--force-with-lease` |
| 忘记打 tag 或 tag 打错分支 | 无法定位线上版本，无法回滚 | 发布流程固定为“合并 → tag → 推送” |
| 直接在 `develop` 上提交 | 绕过评审与 CI | 开启分支保护 |

## 10. 何时不用 Git Flow

| 场景 | 建议 |
| :--- | :--- |
| iOS 客户端、有明确发版节奏 | 适合 Git Flow，发布分支与 App Store 版本对齐 |
| Web 服务、一天多次部署 | 改用 trunk-based 开发 + feature flag，`release` 分支是负担 |
| 1～3 人小团队 | 简化为 `main` + `feature/*`，减少回合并操作 |

Git Flow 的成本是分支多、回合多。团队没有 PR 流程与分支保护时，直接套用五条分支意义不大。

## 11. 本仓库当前状态

- 远端存在 `main` 与 `develop`，CI 同时覆盖两者。
- 本地存在 `feature`、`hotfix`、`release` 三条占位分支。它们与 `main` 指向同一提交，且未推送到远端，**暂不清理**。
- 目前还没有任何 tag。建议下一次发布时按第 4 节流程补上 `v0.1.0` 起步的版本号。
- 实际执行流程为：`develop` 集成 → 短期 `feature/*` → PR 合入 `main`。在启用 `release/*` 与 `hotfix/*` 之前，先保证分支保护与 tag 规范落地。
