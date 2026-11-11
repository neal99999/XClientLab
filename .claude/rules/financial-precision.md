---
description: XClientLab 交易资金精度与接口幂等性安全红线（严禁 Double 算钱、严禁非幂等重试）
paths:
  - "XClientLab/**"
  - "Packages/**"
---
# 交易资金精度与幂等安全规范

## 1. 资金与价格计算精度
- **严禁使用 `Double` 或 `Float` 进行资金、价格、数量的运算或存储**（二进制浮点数无法精确表示十进制小数，会导致类似 `0.1 + 0.2 = 0.30000000000000004` 的严重资金误差）。
- 所有金额、标价、保证金、持仓数量，在领域模型（Model）中必须保持 `String` 或 `Decimal` 类型。
- 换算、乘除加减必须调用基于 `NSDecimalNumber` / 高精度大数封装方法，显式指定舍入模式（如 `.plain`、`.down`）与保留位精度。

## 2. 接口幂等性与超时重试红线
- **下单、撤单、市价平仓、资产转账等写入接口，严禁客户端擅自配置无脑自动重试**。
- 当写入请求发生网络超时（`timeout`）或假死中断时：
  1. 状态只能标记为「状态未知（Unknown / Pending）」，绝不能擅自判定为「失败」并自动重新发起下单；
  2. 必须引导用户前往订单列表/成交记录确认，或通过单调递增的 `ClientOrderId`（幂等键）向服务端主动轮询查询。

## 3. 多通道事件乱序与单调版本号（Sequence ID）
- 订单与资产状态经常同时由 **HTTP 响应** 与 **WebSocket 推送** 两个通道下发；
- 客户端必须维护单调递增的 `Sequence ID`：
  - 只有当 `incomingSeq > currentSeq` 时才允许触发状态更新；
  - 遇到迟到的慢响应报文（`incomingSeq <= currentSeq`），必须坚决丢弃，防止已成交（Filled）被回滚为挂单中（Pending）。
- 状态机流转必须遵循单向不可逆规则：`pending ➔ partially_filled ➔ filled / cancelled`。
