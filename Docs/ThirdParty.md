# 第三方依赖（SPM）

XClientLab 的第三方库全部通过 Swift Package Manager 接入，`XClientLab.xcodeproj/project.pbxproj`
里只有远程包引用（`XCRemoteSwiftPackageReference`），没有把源码或二进制提交进仓库。
解析结果固定在 `XClientLab.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
（v3 格式，`originHash` 由 Xcode 解析时计算写入；升级版本后重跑 `make resolve` 即可）。

## 依赖清单

| 包 | 版本（pin） | 用途 | 接入方式 |
| --- | --- | --- | --- |
| [Alamofire](https://github.com/Alamofire/Alamofire) | 5.12.2 | HTTP 会话、重试、事件拦截器 | 链接到 app target |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | 8.15.0 | 图片下载与内存/磁盘缓存 | 链接到 app target |
| [Moya](https://github.com/Moya/Moya) | 15.0.3 | 类型安全的 API 抽象（依赖 Alamofire） | 链接到 app target |
| [SnapKit](https://github.com/SnapKit/SnapKit) | 6.0.0 | UIKit 声明式 Auto Layout | 链接到 app target |
| [Starscream](https://github.com/daltoniam/Starscream) | 4.0.8 | WebSocket 客户端 | 链接到 app target |
| [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins) | 0.65.1 | 构建期 SwiftLint 检查 | build tool plugin |
| [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | 0.64.6 | 代码格式化 | 仅版本 pin，执行走 CLI |

Moya 会传递引入 `Alamofire`（同一个包，不会重复链接）；未使用的 `RxSwift` /
`ReactiveSwift` / `RxMoya` / `ReactiveMoya` 不参与构建，只是 SwiftPM 的解析结果。

`XClientLab/Features/Architecture/ThirdPartyStack.swift` 是接入自检：它对每个库都做了真实调用
（`Session`、`ImageCache`、`MoyaProvider`、`snp.makeConstraints`、`WebSocket(request:)`），
所以「能编译」本身就证明产物被正确解析、编译并链接。该类型不被 UI 调用，启动时零网络请求。

## 为什么是在 pbxproj 里手工写包引用

Xcode 自带的「Add Package Dependencies」只存在于 GUI；本项目需要在命令行/Agent 环境里可复现，
且当时可用的自动化工具有硬限制：

- `xcodeproj` gem 1.27.0 在本机加载失败（`rexml` 版本冲突），且其对象模型不认识
  `buildToolPlugins`，回写会丢 Xcode 27 的新键。
- XcodeGen / Tuist 生成的工程对 SPM build tool plugin 的支持有已知缺陷
  （tuist#9269：插件被写成普通 `PBXTargetDependency`，Xcode 不会执行）。

因此采用「文本插入 + 幂等校验」的方式写入，插入位置与 Xcode 27.1 自己写出的结构一致：

```text
XCSwiftPackageProductDependency (链接产物)
  productName = Alamofire; / productName = Moya; ...

XCSwiftPackageProductDependency (构建期插件)
  productName = "plugin:SwiftLintBuildToolPlugin";     // 关键：plugin: 前缀
  ↓ 由 PBXTargetDependency.productRef 引用
PBXTargetDependency
  ↓ 挂在 PBXNativeTarget.dependencies
```

如果漏掉 `plugin:` 前缀，Xcode 会报
`Missing package product 'swiftlintplugins_SwiftLintBuildToolPlugin.SwiftLintBuildToolPlugin'`
并从构建计划里剔除插件；这也正是 Tuist/XcodeGen 至今仍在踩的坑。

## SwiftLint：构建期检查

- 配置：仓库根目录 `.swiftlint.yml`（app target 与 CLI 共用）。
- 阈值按现有代码调宽（行宽 warning 160 / error 300、文件长度 800、函数体 150 等），
  因此当前基线是 **0 violation**；三项历史隐患用 `// swiftlint:disable:next` 显式标注，
  而不是整条规则关掉。
- 二进制由插件自己下载（`SwiftLintBinary` artifact），不依赖 Homebrew 版本，
  所以本机 `swiftlint` 与构建期版本必须同为 0.65.x 才有一致的规则行为。
- **首次在 Xcode GUI 里构建**会弹「Trust & Enable」确认框，选择信任后不再提示；
  命令行构建需加 `-skipPackagePluginValidation`（Makefile 已内置）。
- 只想手动跑一次：`make lint`。

## SwiftFormat：为什么只接了 CLI

SwiftFormat 的包只提供两类产物：

1. `swiftformat` 可执行文件；
2. `SwiftFormatPlugin`，但它是 **command plugin**（`context.package.targets` 范围），
   Xcode app target 无法把它当 build tool plugin 使用——这是上游设计，不是配置问题
   （见 `Plugins/SwiftFormatPlugin/SwiftFormatPlugin.swift` 的 `performCommand`）。

所以：包引用用于锁定工具链版本，真正的格式化走本机 CLI：

```bash
make format        # 全量格式化 XClientLab/
make format-check  # 只检查，CI 用
```

现有代码**尚未**做一次性全量格式化（`make format` 会产生一个纯格式 diff，建议独立提交）。
`.swiftformat` 里已经按项目风格固定了 `--indent 4`、`--swiftversion 5.0`、`--maxwidth 160`。

## 常用命令

```bash
make resolve   # 解析/更新依赖，改写 Package.resolved
make build     # 命令行构建（含 -skipPackagePluginValidation）
make lint      # SwiftLint
make format    # SwiftFormat 全量格式化
```

## 新增一个库

1. 在 `project.pbxproj` 追加 `XCRemoteSwiftPackageReference`，并把
   `XCSwiftPackageProductDependency` 放进 app target 的 `packageProductDependencies`；
2. 同步在 app target 的 Frameworks 阶段加 `PBXBuildFile`（`productRef` 指向该依赖）；
3. 用 `xcodebuild -resolvePackageDependencies` 生成/更新 `Package.resolved`；
4. 在 `XClientLab/Features/Architecture/ThirdPartyStack.swift` 里补一行版本与调用自检（界面入口：Tab「架构」→ RUN SELF-CHECK）。

约定：**能锁 `upToNextMajorVersion` 就锁**，`Package.resolved` 随仓库提交；
升级依赖时只改 `Package.resolved` 或最小版本，并在 PR 里贴 `make build` 结果。

## 验证记录

```bash
xcodebuild -project XClientLab.xcodeproj -scheme XClientLab \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation build
# BUILD SUCCEEDED

swiftlint lint --no-cache XClientLab
# Done linting! Found 0 violations, 0 serious in 24 files
```
