# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

IBIT(MCIBIT)是 Swift + UIKit 的加密货币交易所 iOS 客户端,包含首页、行情、现货、合约、跟单、资产等业务。单 App Target + 目录级模块化,业务代码为 MVVM(VC + VM + Model)风格,基础设施大量使用单例与通知。

仓库根目录的架构文档是最全面的上下文来源,动手前先读:

- `项目架构与新人接手指南.md` — 总体架构、启动链路、网络/WebSocket、交易模块、调试检查清单(最重要)
- `模块-*.md` — 各模块细粒度说明(AppDelegate / Base / Menu / PublicActivity / Tool / TabBarController / Notification / Resources / MAHPod / SwiftPM / 国际化脚本)
- `CommonAPI.md` — `Common+Data` 常用方法(最新价、标记价、精度等)

源码位于 `MCIBIT/MCIBIT/`:`Configuration/`(全局配置)、`Modules/`、`Resources/`(证书/字体/主题/多语言/动画)。

## 常用命令

全部在 `MCIBIT/` 目录下执行。

```bash
# 首次环境准备
bundle install
bundle exec pod install                 # 需内网访问 git.kdmex.com 拉私有 pod(MCCommon、MAH_user)
bundle exec fastlane match_all          # 下载证书/描述文件(readonly)
bundle exec fastlane force_match        # 证书过期/新增设备时重建,需管理员权限

# 打开工程:必须用 workspace(xcodeproj 不含 Pods 与本地 SwiftPM 包)
open MCIBIT.xcworkspace

# 命令行编译
xcodebuild -workspace MCIBIT.xcworkspace -scheme MCIBIT -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# 发包(fastlane)
bundle exec fastlane build_testflight version:x.x.x build:n   # TestFlight
bundle exec fastlane build_appstore version:x.x.x build:n     # App Store
bundle exec fastlane sync_devices                             # 用 devices.txt 注册新设备
```

- 主 App **没有 XCTest/UI Test Target**,业务改动只能靠手动回归。唯一的自动化测试在本地 SwiftPM 包内:`cd SwiftPM/Wrapper && swift test`、`cd SwiftPM/TrueTime && swift test`。
- `build_debug` / `build_debug_develop` lane 传入的 `Dev` 配置在当前工程中不存在(仅 Debug/Beta/TestFlight/AppStore 四个配置),使用前需先修复。
- Xcode 里直接 Product > Archive 走的是 scheme 的 ArchiveAction = **Debug** 配置;正式发包走 fastlane lane。
- fastlane 密钥/Token 在 `fastlane/.env.default`。

### 国际化脚本

```bash
cd Scripts && pip3 install -r requirements.txt
python3 exportToExcel.py                 # Resources/System 下 Localizable.strings -> localizableToExcel.xls
python3 importLocalizable.py -f xxx.csv  # 翻译好的 CSV 直接替换 .strings,无需二次操作
```

## 构建配置与环境

- 配置:`Debug` / `Beta` / `TestFlight` / `AppStore`(project 默认 AppStore),对应不同 Bundle ID(`com.exchange.ibit` / `com.exchange.ibitTF` / `com.mochain.bourse`)。发包前必须确认所选 Configuration。
- 环境通过 Info.plist 的 `APP_ENVIRONMENT` / `APP_CHANNEL` 构建设置注入,由 `Configuration/AppPackageConfig.swift` 读取;`APP_VERSION` / `APP_BUILD` 因多渠道手动维护,发包前必须人工核对。
- Debug 包可在 App 内(DebugTools 网络环境切换页)运行时切换 dev/test/beta/product,选择由 `DebugConfiguration`(`Modules/PublicActivity/Managers/EnvironmentManager/MCEnvironmentManager.swift`)持久化。
- 最低 iOS 13 / Swift 5;纯代码 UI(UIKit + SnapKit),不使用 XIB。

## 架构要点

### 启动与导航

`Modules/AppDelegate/`:激活网络引擎 → 数美反欺诈 → TrueTime(NTP)→ MMKV → 推送(仅 TestFlight 包生效)→ Lottie 启动页 `MCLaunchActivityVC` → Firebase/主题/语言/键盘/Zendesk → 根控制器 `MCTabBarController`。启动期收到的 URL Scheme 待主界面完成后再路由(`Routes.swift` 中的 URLRouter)。

5 个 Tab 由 `AppPackageConfig.swift` 的 `APPMODULELIST` 决定:首页 / 行情 / 交易(中间 Plus 按钮,`TABBARPLUSINDEX`)/ 跟单 / 资产。跳转方式:Tab 内 push/pop、`MCRounteManager` 枚举路由、`URLRouter` 外部跳转。

`Modules/Menu/` 下 28 个子目录即全部业务页面(Exchange/Futures/Spot/Order/Home/Market/FollowOrder/Capital/Mine/Login&Register 等)。注意 `Spot（现货）/` 是空目录遗留,实际代码在 `Spot/`;`Modules/Tool(工具)/` 是只剩 .DS_Store 的历史遗留目录。

### 网络层(Modules/PublicActivity/Managers/MCNetWorkManager/)

Moya + Alamofire。每个业务一个 Endpoint 枚举(`MCSpotAPIEndPoint`、`MCFuturesAPIEndPoint`…),`MCCustomTargetType` 统一 baseURL/headers/参数;全局 Provider 按业务划分(`SpotApi`、`FuturesApi`、`AssetsApi`…);`MCNetProvider` 统一解析成功/业务失败/网络失败/登录失效。普通线路做 SSL Pinning(证书在 `Resources/Certificates/`),MAH 线路可配代理。

### WebSocket(Modules/PublicActivity/Managers/WebsocketManager/)

三层结构:`MCWebSocketEntity`(连接/心跳 10s/重连)→ 业务 SocketDriver(`MCSocketSpotMarketDriver`、`MCSocketFuturesMarketDriver`、`MCSocketSpotOrderDriver`、`MCSocketAccountOrderDriver` 等)→ Manager/Delegate 分发页面。**切币对、切周期、页面消失、退登、前后台切换时必须退订旧 channel**,否则出现重复数据与串币。

### 主题与国际化

- 主题:SwiftTheme 封装(`MCThemeManager`),颜色/图片定义在 `Modules/PublicActivity/Managers/ThemeManager/` 的 `WhiteTheme.plist` / `BlackTheme.plist`。新增 key 必须三处同步:两个 plist + `MLThemePathKey` 枚举;UI 一律用 `theme_*` 属性取色。
- 国际化:字符串用 `.localized()`(`Tool/Common(通用)/Func(方法)/CommonFunc+Language.swift`);资源在 `Resources/System/*.lproj`(en / zh-Hans / zh-Hant,枚举层支持 9 种语言)。新增文案需补全所有语言。**切换语言会重建 TabBar 及部分导航栈**,改动全局导航必须回归该场景。

### 本地 SwiftPM 包(MCIBIT/SwiftPM/,以本地包形式接入工程)

- `Wrapper`:Swift Macro(`@AutoCodable` 等)与 Codable 工具,大量模型/枚举用它生成序列化代码。
- `TrueTime`:NTP 网络时间,App 内时间以其为基准(防用户改本机时间)。

### 第三方依赖

- CocoaPods 管理,版本在 `Podfile` 中全部锁定;`MCCommon`(基础方法/扩展/Key)与 `MAH_user`(MAH 网络代理 SDK,源码在 `Modules/MAHPod/`)是内网私有 pod。
- **例外**:K 线引擎 `Modules/Tool/ThirdParty(第三方)/CHKLineChart/` 是内置源码(Podfile 中 `CHKLineChartKit` 已注释),团队直接改这里的源码——改 K 线逻辑不要动 Pods,也不要试图升级该 pod。
- 其余情况:不要修改 `Pods/` 里的源码;需要改第三方时按 README 约定内置源码(如 CHKLineChart 的做法)。

## 编码约定与雷区

- 金额/数量一律用 String 大数扩展运算(`bigMulContract`、`bigAddContract` 等,见 `Tool/Extension/String/`),禁止 `Double` 参与资金计算。
- 尺寸用 `MCFIT()`(基于 375pt 设计稿等比缩放);图片用 Kingfisher 加载(SVGKit 支持 SVG)。
- `Tool/Common(通用)/Head(常量类)/CommonConstant.swift` 通过 `@_exported` 全局引入 SnapKit/Moya/RxSwift 等常用框架,新文件通常无需重复 import。
- 页面继承 `MCBaseViewController`(自动挂 `MCNavigationView`、自动埋点、自动主题);新增页面前先查 `Modules/Base` 是否已有基类/组件。
- 全局单例/Provider/通知很多,修改共享状态时回归范围要放大;下单接口非幂等,禁止无条件自动重试。
- `Info.plist` 目前全局允许非 HTTPS 请求(已知技术债);网络日志不得打印 token/资产/订单参数。
- 主 App 编译存在大量废弃 API 与重复 Compile Sources 告警,属已知现状,不要顺手大范围清理。
