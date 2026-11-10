---
description: IBIT 网络层与 API 设计约定（Moya Endpoint、Provider、错误映射、幂等与日志红线）
paths:
  - "MCIBIT/MCIBIT/Core/Networking/**"
  - "MCIBIT/MCIBIT/Modules/**/Models/**"
  - "MCIBIT/MCIBIT/Modules/**/*API*.swift"
---
# API 设计约定

## Endpoint 与 Provider
- 每个业务一个 Moya `TargetType` 枚举，命名 `MC<业务>APIEndPoint`，遵循 `MCCustomTargetType`；`baseURL` / headers 由全局 Provider 统一注入，不在 endpoint 里硬编码域名或 token。
- 全局 Provider 按业务拆分（`SpotApi`、`FuturesApi`、`AssetsApi`…）；普通线路走 SSL Pinning（证书在 `MCIBIT/MCIBIT/App/Resources/Certificates/`），不要新增裸 `URLSession` 请求。
- 新增接口时同步检查：是否需要登录态、是否走 MAH 线路、是否需要签名/时间戳（时间以 TrueTime 为基准）。

## 模型
- 请求/响应模型用 `Codable` + `@AutoCodable`（`MCIBIT/SwiftPM/Wrapper` 宏）；字段名用 `CodingKeys` 显式映射，避免服务端改字段名时静默丢值。
- 金额/数量字段保持 `String`，用大数扩展运算；不要在模型层转 `Double`。

## 错误与状态
- 成功/业务失败/网络失败/登录失效统一由 `MCNetProvider` 解析，页面不要各写一套判断。
- 登录失效走现有登出与跳转逻辑；业务错误码要有用户可感知的提示（toast/空态/重试），不要静默吞掉。
- 幂等性：下单、撤单、划转等非幂等接口**禁止无条件自动重试**；超时按「结果未知」处理，提示用户去订单列表确认。

## 分页与缓存
- 分页参数（cursor/page/limit）命名统一；空列表判定与「没有更多」状态要区分。
- 切换币对/周期、退登、页面消失时重置分页游标与去重集合，避免串数据。
- 缓存只做展示加速，不作为资金/订单状态的唯一来源。

## 日志与安全
- 禁止打印 token、签名、资产、订单参数、用户隐私；调试日志用现有 logger，不新增 `print`。
- 新增域名必须配置证书与 ATS 例外评估；不要扩大 `Info.plist` 的明文 HTTP 放行范围。
