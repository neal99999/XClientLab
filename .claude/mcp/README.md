# XClientLab MCP (Model Context Protocol) 核心工程目录

> 本目录为 XClientLab 项目的一级 **MCP 工具链服务中心**。通过标准 JSON-RPC 2.0 stdio 协议，打通 LLM Agent 与本地 macOS / Xcode / 模拟器底层工具链，以及 GitHub、Figma、Jira、Slack 等企业级开发协作平台。

---

## 1. 目录架构

```
mcp/
├── server.py              # iOS 本地开发 MCP Server 核心实现（纯 Python 3 标准库）
├── ios_dev_mcp.py         # server.py 的同名兼容别名入口
├── tools.json             # iOS 本地 8 大 Tools 的标准 JSON-Schema
├── test_client.py         # 本地 MCP 通信与工具调用自测客户端
├── .env.example           # 外部服务 (GitHub, Figma, Jira, Slack) 凭证配置模板
└── README.md              # 架构说明与快速接入指南
```

---

## 2. 注册的 MCP 服务全景列表

在 [`mcp.json`](../mcp.json)、[`mcp_config.json`](../mcp_config.json)、[`.cursor/mcp.json`](../.cursor/mcp.json) 及 [`.claude/mcp.json`](../.claude/mcp.json) 中已配置以下 5 大 MCP 服务：

### 1. `xclientlab-ios-tools` (本地 iOS 研发与取证)
- **实现方式**：`python3 mcp/server.py`（零外部依赖，极速启动）
- **核心能力**：
  - `xcode_build`: 自动跳过签名与 SPM 宏插件限制编译工程；
  - `xcode_test`: 运行单元测试与 UI 测试；
  - `fastlane_run`: 调度 Fastlane 执行任一 lane（`test`, `package_simulator`, `beta` 等）；
  - `simctl_booted_info`: 获取当前活跃模拟器信息；
  - `simctl_screenshot`: 抓取模拟器当前屏幕，用于 UI 还原度比对；
  - `simctl_install_launch`: 编译后自动安装并唤起 App；
  - `lldb_disciplined_batch`: 8 步通道纪律 LLDB 异步崩溃取证序列；
  - `diagnostics_summary`: 汇总最新构建与测试日志。

### 2. `github` (代码仓库与 PR 协同)
- **运行方式**：`npx -y @modelcontextprotocol/server-github`
- **所需凭证**：`GITHUB_PERSONAL_ACCESS_TOKEN`
- **核心能力**：
  - 检索仓库文件、阅读代码历史；
  - 创建、审查 Pull Request，发布代码审查评论；
  - 查看 GitHub Actions CI/CD 流水线状态与失败日志；
  - 搜索与关联 Issue。

### 3. `figma` (设计稿解析与像素还原)
- **运行方式**：`npx -y @modelcontextprotocol/server-figma`
- **所需凭证**：`FIGMA_ACCESS_TOKEN`
- **核心能力**：
  - 深度遍历 Figma 画板节点，提取图层结构与绝对坐标；
  - 自动提取 Design Tokens（色值、间距、字体层级、圆角）；
  - 配合 `simctl_screenshot` 实现设计稿 vs 真实渲染像素级比对（0.00% Diff）。

### 4. `jira` (需求与缺陷生命周期跟踪)
- **运行方式**：`npx -y @modelcontextprotocol/server-atlassian`
- **所需凭证**：`JIRA_URL`, `JIRA_USERNAME`, `JIRA_API_TOKEN`
- **核心能力**：
  - 查询当前 Sprint 的任务清单与需求详情；
  - 遇到线上或测试 Crash 时，自动创建并关联 Bug Ticket；
  - 联动 Git Commit / PR 自动流转 Issue 状态（In Progress ➔ Code Review ➔ Done）。

### 5. `slack` (研发告警与团队消息通知)
- **运行方式**：`npx -y @modelcontextprotocol/server-slack`
- **所需凭证**：`SLACK_BOT_TOKEN`, `SLACK_TEAM_ID`
- **核心能力**：
  - CI/CD 构建失败或 TestFlight 交付成功时，向研发频道推送卡片通知；
  - 捕获异常现场并发送截图与崩溃调用栈摘要；
  - 监听指定讨论线程并提取上下文。

---

## 3. 环境变量与凭证配置

参考 [`mcp/.env.example`](.env.example)，将相关 Token 导出至本地终端环境变量或配置在编辑器的环境变量中：

```bash
# 复制模板
cp mcp/.env.example mcp/.env

# 填入真实凭证后 source
source mcp/.env
```

---

## 4. 本地自测验证

本地 iOS 服务通过以下脚本即可秒级完成连通性验证：

```bash
python3 mcp/test_client.py
```

输出：
```
🚀 [1/3] Testing 'initialize'...
✅ Server initialized: xclientlab-ios-mcp v2.0.0
🚀 [2/3] Testing 'tools/list'...
✅ Tools registered (8): xcode_build, xcode_test, fastlane_run, ...
🚀 [3/3] Testing 'lldb_disciplined_batch' tool execution...
✅ LLDB Disciplined Batch output successfully received!

🎉 ALL MCP SERVER SELF-TESTS PASSED!
```
