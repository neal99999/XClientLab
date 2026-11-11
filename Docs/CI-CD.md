# XClientLab CI/CD 与 Fastlane 自动化交付指南

> 本文档详细阐述 XClientLab 项目的 CI（持续集成）与 CD（持续交付/部署）工作流，以及 Fastlane 自动化脚本的架构设计、本地调试方法与 GitHub Actions 生产环境配置。

---

## 目录

1. [整体架构与流水线设计](#1-整体架构与流水线设计)
2. [Fastlane 体系结构与 Lane 说明](#2-fastlane-体系结构与-lane-说明)
3. [GitHub Actions CI 工作流 (.github/workflows/ci.yml)](#3-github-actions-ci-工作流)
4. [GitHub Actions CD 工作流 (.github/workflows/cd.yml)](#4-github-actions-cd-工作流)
5. [签名与密钥配置指南 (Secrets Checklist)](#5-签名与密钥配置指南)
6. [本地常用命令与调试](#6-本地常用命令与调试)

---

## 1. 整体架构与流水线设计

```
[ Git Push / PR ] 
       │
       ├──► PR / develop 分支 ──► 【CI 流水线 (ci.yml)】
       │                            ├── 1. 静态检查: SwiftLint
       │                            ├── 2. 环境准备: Xcode 27.x + SPM 缓存
       │                            ├── 3. 动态模拟器发现: 适配 preview 镜像
       │                            └── 4. 自动化测试: fastlane test (Unit + UI)
       │
       └──► main 分支 / Tag (v*) ─► 【CD 流水线 (cd.yml)】
                                    ├── 1. 预发布测试 (可选跳过)
                                    ├── 2. 证书/钥匙串导入 (Match 或 Base64 证书)
                                    ├── 3. 产物打包 (gym: AppStore / Ad-Hoc / 模拟器包)
                                    ├── 4. 分发交付 (TestFlight / 蒲公英 / Release)
                                    └── 5. 产物归档 (IPA, dSYM, Simulator Zip)
```

- **环境基线**：Xcode 27.x（工程格式 `objectVersion = 110`，GitHub Actions 必须使用 `runs-on: xcode-27`）。
- **统一驱动**：CI 与 CD 的核心任务均收敛在 `fastlane/Fastfile`，保证本地执行（`make ci` / `make cd-*`）与远端 CI/CD 结果完全一致。

---

## 2. Fastlane 体系结构与 Lane 说明

Fastlane 配置文件位于 `fastlane/Fastfile`，支持以下 Lanes：

### 代码质量与测试

| Lane | 说明 | 示例命令 |
| :--- | :--- | :--- |
| `lane :lint` | 执行 SwiftLint 静态代码规范分析 | `bundle exec fastlane lint` |
| `lane :format_check` | 检查 SwiftFormat 格式化状态（只读） | `bundle exec fastlane format_check` |
| `lane :test` | 分步执行单元测试与 UI 测试（防资源竞争），自动输出 JUnit/HTML 报告与 xcresult | `bundle exec fastlane test`<br>`bundle exec fastlane test destination:"platform=iOS Simulator,name=iPhone 18 Pro Max"` |

> `lane :test` 参数支持：
> - `destination`: 模拟器匹配字符串
> - `type`: 测试套件类型（`"all"` / `"unit"` / `"ui"`）
> - `retry_count`: 失败自动重试次数（默认 2 次）

### 编译与构建

| Lane | 说明 | 示例命令 |
| :--- | :--- | :--- |
| `lane :build_simulator` | 针对 iOS 模拟器快速编译（无代码签名），适合门禁验证 | `bundle exec fastlane build_simulator` |
| `lane :package_simulator` | 编译模拟器 `.app` 并打包为 `.zip` 产物，免证书即下即测 | `bundle exec fastlane package_simulator` |
| `lane :build_ipa` | 调用 `gym` 打包归档并导出 IPA | `bundle exec fastlane build_ipa export_method:"app-store"` |

### 持续交付与分发 (CD)

| Lane | 说明 | 示例命令 |
| :--- | :--- | :--- |
| `lane :setup_signing` | 智能证书钥匙串管理（优先读取 Fastlane Match，次选 Base64 P12 证书临时钥匙串，无密钥时平滑降级） | 内部调用或单独执行 |
| `lane :beta` | 打包 App Store 签名 IPA 并通过 App Store Connect API Key 上传至 **TestFlight** | `bundle exec fastlane beta changelog:"Fix network issue"` |
| `lane :adhoc` | 打包 Ad-Hoc 签名 IPA 并分发至 **蒲公英 (Pgyer)** | `bundle exec fastlane adhoc` |
| `lane :release` | 完整发布流程（自动化测试 ➔ 签名 ➔ TestFlight/App Store 上传） | `bundle exec fastlane release` |

---

## 3. GitHub Actions CI 工作流

文件路径：[`.github/workflows/ci.yml`](file:///.github/workflows/ci.yml)

### 触发条件
- 针对 `main` 和 `develop` 分支的 Pull Request。
- 针对 `main` 和 `develop` 分支的直接 Push。
- 支持 `workflow_dispatch` 手动触发。
- 并发控制：同一分支连续推送时自动取消旧任务（`cancel-in-progress: true`）。

### 主要阶段
1. **Code Quality (Lint)**：在轻量级 `macos-latest` 容器上运行 SwiftLint 快速反馈。
2. **Build & Test**：
   - 运行于 `runs-on: xcode-27`。
   - 自动探测并激活 Xcode 27.1 工具链。
   - 依赖与缓存：SwiftPM 依赖缓存（`org.swift.swiftpm`）+ Ruby Gems 缓存（`vendor/bundle`）。
   - **动态模拟器发现算法**：自动识别 preview 镜像上的实际可用 iOS 27.x runtime 与机型，支持动态新建 `CI-iPhone-27-1` 避开硬编码机型不存在的问题。
   - 执行 `bundle exec fastlane test destination:"$DESTINATION"`。
   - 无论成功与否，自动归档 `fastlane/test_output`（测试报告与 xcresult）。

---

## 4. GitHub Actions CD 工作流

文件路径：[`.github/workflows/cd.yml`](file:///.github/workflows/cd.yml)

### 触发条件
- Push 到 `main` 分支（自动构建候选版本并交付）。
- 推送版本标签 `v*`（如 `git tag v1.0.0 && git push --tags`）。
- 手动触发（`workflow_dispatch`），提供控制台界面参数：
  - `channel`: 选择分发渠道（`testflight` / `adhoc` / `simulator_zip`）。
  - `skip_tests`: 是否跳过发布前回归测试。
  - `build_number`: 自定义构建号（默认自动使用 GitHub Run Number）。
  - `changelog`: 发布更新说明。

### 核心亮点
1. **防并发中断**：设置 `cancel-in-progress: false`，防止发包途中因并发推送导致半包或分发中断。
2. **无密钥平滑降级**：若仓库尚未配置苹果证书 Secret，CD 流水线不会直接报错崩溃，而是自动切换至打包含符号表的模拟器 `.app.zip`，并给出清晰的配置指引。
3. **安全临时钥匙串**：Fastlane 在 CI 环境下动态创建隔离的临时 Keychain 导入证书，任务结束或异常时通过 `after_all` / `error` 钩子自动销毁清理。
4. **GitHub Release 自动关联**：当推送 `v*` 标签时，自动创建 GitHub Release，自动提取提交日志生成 release notes，并将打包好的 IPA / Zip / dSYM 挂载为 Release Assets。

---

## 5. 签名与密钥配置指南

在 GitHub 仓库中，进入 **Settings > Secrets and variables > Actions** 添加以下 Secrets：

### A. App Store Connect API Key（推荐，免 2FA 验证码）

Apple 官方推荐用于 CI 自动化发包的认证方式：

| Secret 键名 | 说明 | 获取路径 |
| :--- | :--- | :--- |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID（如 `D383SF7354`） | App Store Connect ➔ 用户与访问 ➔ 集成 ➔ 密钥 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID（UUID 字符串） | 同上页面顶部 |
| `APP_STORE_CONNECT_KEY_CONTENT` | `.p8` 私钥内容（文本） | 下载生成的 `AuthKey_xxx.p8`，将全文粘贴进 Secret |
| `APP_STORE_CONNECT_KEY_BASE64` | （可选）`.p8` 的 Base64 编码 | `base64 -i AuthKey_xxx.p8 \| pbcopy` |

### B. 证书与描述文件（二选一）

#### 方案一：Base64 导入（最轻量，适合单工程）

```bash
# 1. 导出发布证书 .p12 的 Base64 字符串
base64 -i distribution.p12 | pbcopy
# 粘贴到 Secret: BUILD_CERTIFICATE_BASE64

# 2. 设置该证书密码
# 粘贴到 Secret: P12_PASSWORD

# 3. 导出 Mobileprovision 的 Base64 字符串
base64 -i XClientLab_AppStore.mobileprovision | pbcopy
# 粘贴到 Secret: BUILD_PROVISION_PROFILE_BASE64

# 4. 指定描述文件名称（Xcode Target 配置的描述文件名）
# 填写到 Secret: PROVISIONING_PROFILE_SPECIFIER (例如 XClientLab_AppStore)
```

#### 方案二：Fastlane Match（团队标准化多工程推荐）

| Secret 键名 | 说明 |
| :--- | :--- |
| `MATCH_GIT_URL` | 存储加密证书与描述文件的私有 Git 仓库地址 |
| `MATCH_PASSWORD` | Match 仓库密码（解密密钥） |

### C. 内部测试分发（可选）

| Secret 键名 | 说明 |
| :--- | :--- |
| `PGYER_API_KEY` | 蒲公英开发者 API Key（用于 Ad-Hoc 渠道一键上传分发） |

---

## 6. 本地常用命令与调试

所有常用命令均已在根目录 [`Makefile`](file:///Makefile) 中就绪：

```bash
# 查看全部可用指令
make help

# 运行自动化测试（Fastlane 驱动）
make ci

# 本地打包含符号表的模拟器 zip 包（无需证书，直接双击或拖拽进模拟器安装）
make cd-package-sim

# 打包并上传 TestFlight
make cd-testflight

# 打包 Ad-Hoc IPA（可配合蒲公英分发）
make cd-adhoc

# 代码规范检查
make lint
make format-check
```
