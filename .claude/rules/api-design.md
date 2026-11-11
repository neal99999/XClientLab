---
description: XClientLab 网络通信与数据模型设计约定（Moya Endpoint、模型映射、弱网心跳与安全红线）
paths:
  - "XClientLab/Core/Networking/**"
  - "XClientLab/Models/**"
  - "Packages/**"
---
# 网络通信与模型规范

## 1. 弱网假死连接探测与自愈（场景 3.1）
- **绝不单纯依赖系统 Reachability 状态**（Reachability 只代表网卡硬件通畅，无法感知 NAT 超时或 TCP 单向黑洞）。
- 应用层必须自主维护心跳探测机制：
  - 定时（如 5s）发送应用层轻量 Ping 帧；
  - 连续 2 次丢失 Pong 或超过 10s 无任何下行流量，立即主动关闭旧 Socket 并触发重连；
  - 重连必须引入 **指数退避 + 随机抖动（Exponential Backoff + Jitter）**，防止客户端群体同时向网关发起雪崩式重连。

## 2. 数据模型与 Codable
- 请求与响应模型一律遵循 `Codable` 协议；显式声明 `CodingKeys` 映射字段名，避免服务端接口调整导致字段静默丢失。
- 标价与金额在解析后必须以 `String` 存储在 Model 中，运算时调用大数计算工具。

## 3. 日志脱敏与安全传输
- 禁止在控制台或持久化日志中以明文输出 Token、API Secret、私钥签名、用户敏感资产信息。
- 所有通信接口强制使用 HTTPS / WSS，严格遵循 iOS App Transport Security (ATS) 规范。
