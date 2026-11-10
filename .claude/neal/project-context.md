# IBIT 命令共用规则

先读根目录 CLAUDE.md 和适用的 AGENTS.md；文档只是导航，以当前源码为准。先查看 git status，保留已有改动，不覆盖、不回退、不提交或推送，除非用户另有明确要求。

## 代码导航

源码根：MCIBIT/MCIBIT/。
- 合约 K 线入口：Modules/FeatureExchange/ViewControllers/MCTradingKLineDetailVC.swift。
- 历史分页与 BS 合并：Core/ThirdParty/CHKLineChart/Custom/VM/MCKLineDataLoader.swift。
- 图表数据与绘制入口：Modules/FeatureExchange/Kline/View/MCKLineView.swift；图表引擎在 Core/ThirdParty/CHKLineChart/Classes/。
- 数组同步：上述 Custom/VM/MCThreadSafeArray.swift。数组加锁不等于请求顺序、对象属性和页面生命周期都安全。
- 行情分发：Services/DataCenter/MCFuturesMarketManager.swift、MCSpotMarketManager.swift。
- 连接、心跳、重连、频道解析：Core/Networking/Websocket/。
- 现货页面：Modules/FeatureSpot/；行情列表：Modules/FeatureMarket/。
- 网络请求：Core/Networking/。

## 证据与表达

- 中文、大白话，先说结论；默认报告最重要的 3～5 项，用户要求全量时再展开。
- 每项包含：严重程度、已确认/存在风险/待验证、文件:行号及方法、证据、触发条件、影响、最小建议、验证步骤。运行复现与静态确认分别说明。
- 沿调用方和回调追踪后再下结论；不要仅凭关键词、注释、weak self 或锁判断安全性。反例：页面回调未带周期，不代表上游没按周期分发。
- 查找主动排除风险的证据。没有发现时说明覆盖范围和未验证部分，不凑问题。
- 性能结论须区分调用路径与实测瓶颈；不编造耗时、FPS、内存、收益、个人贡献和测试通过结果。
- 缺少依赖、运行条件、服务端协议或日志时明确限制，列出最小验证方法。

## 执行边界

- 检查、链路和材料命令只读：不编辑代码、配置或文档，不运行有副作用的脚本；输出到对话。生成文件须用户明确要求。
- 只读是工作指令，不是操作系统级沙箱。不要擅自扩大工具授权或修改权限配置。
- 不访问或输出密钥、令牌、账户隐私和生产订单参数。现场演示仅用只读操作；改变账户或业务数据的场景使用 mock/测试环境。
- 修复与建页沿用 Swift/UIKit 和现有架构，不引入 SwiftUI；不修改 Pods。内置 CHKLineChart 是项目可维护源码，可在任务需要时修改。
- 金额和数量遵循项目大数计算方式；下单超时不能直接当成失败，也不能无条件重试。
- 修改后按影响范围验证；先确认实际 workspace、scheme、模拟器、测试 target，再运行适用检查。不要自动安装依赖、签名、发包或操作生产环境。
