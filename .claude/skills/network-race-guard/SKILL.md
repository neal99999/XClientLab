---
name: network-race-guard
description: 专门用于排查弱网假连接、事件乱序到达与状态回滚竞态（对应场景 3.1 & 3.2）。通过单调递增版本号 (Sequence ID) 校验与单向状态机，防止旧事件覆盖新状态，保证接口幂等性。
---

# network-race-guard Skill

本 Skill 对应 App 内「03 交易所专项 → 3.1 弱网 WS 重连」与「3.2 跨国弱网 + 订单状态竞态」，专用于排查移动端在复杂弱网下出现的状态回退、假连接挂起与重复下单问题。

---

## 一、排查核心痛点与反模式

1. **假连接（Zombie Connection）**：
   - 手机进入电梯或切 Wi-Fi 时，物理网卡断开，但 TCP 栈并未收到 FIN 报文；
   - 系统 `Reachability` 显示“网络可用”，TCP keepalive 默认高达数分钟，客户端停留在“以为自己连着网”的假死状态，丢失关键行情与交易通知。
2. **多通道事件乱序导致状态倒退**：
   - 订单通过 HTTP 提交，状态通过 WebSocket 实时推送；
   - WebSocket 的最新推送 `seq=12, status: filled` 先到达，随后迟到的慢 HTTP 响应 `seq=9, status: pending` 晚到达；
   - 如果客户端不做版本控制，界面会从“已成交”被强行**回滚**为“挂单中”，造成重大交易混乱。
3. **超时无脑重试导致重复下单**：
   - 写入接口（如开仓、平仓、转账）在超时后擅自重试，此时远端撮合引擎可能已经成交，重试将导致用户账户产生二次扣款。

---

## 二、两层防线与治理架构

```
               ┌────────────────────────────────────────────────────────┐
               │                  网络时序两层安全防线                  │
               └───────────────────────────┬────────────────────────────┘
                                           │
              ┌────────────────────────────┴───────────────────────────┐
              ▼                                                        ▼
    【第一道：应用层心跳探测】                                【第二道：业务层单调状态机】
    • 5s 应用层 Ping 报文                                     • Sequence 版本号严格单调递增
    • 连续 2 次丢失 Pong 立即判死                              • seq <= currentSeq 报文一律丢弃
    • 10s 无任何下行流量触发强制自愈                           • 单向状态机：pending ➔ filled 禁止回滚
```

---

## 三、四大核心排查清单

### 1. 应用层心跳与死链自愈（场景 3.1）
*   **审查项**：是否仅依赖 Reachability 判断网络？
*   **规范**：必须在应用层自主维护主动心跳计时器：
    - 定时发送特定轻量 Ping 帧；
    - 记录未响应的 Pong 次数；
    - 结合**指数退避 + 随机抖动（Jitter）**算法进行重连，防止成千上万客户端在弱网恢复瞬间同时重连打垮服务端网关：
      $$T_{wait} = \min(T_{max}, T_{base} \times 2^{retry}) \pm \text{jitter}$$

### 2. 单调版本凭证 (Sequence ID / Version)
*   **审查项**：跨通道（HTTP + WS）数据合并时，是否存在后到覆盖先到的风险？
*   **规范**：模型必须包含单调递增版本凭证（如 `sequence` 或 `timestamp`）：
    ```swift
    // 强制版本检查：只有版本号严格大于当前版本才允许更新
    guard incomingEvent.sequence > currentOrder.sequence else {
        log.warning("丢弃陈旧或乱序事件: seq=\(incomingEvent.sequence), 当前=\(currentOrder.sequence)")
        return
    }
    ```

### 3. 单向不可逆状态机 (One-Way State Machine)
*   **审查项**：状态转移是否存在逆向流转？
*   **规范**：交易状态迁移必须被限制为单向有向无环图（DAG）：
    $$\text{Created} \longrightarrow \text{Pending} \longrightarrow \text{Partially Filled} \longrightarrow \text{Filled / Cancelled}$$
    - 一旦进入 `Filled` 或 `Cancelled` 终态，**任何通道来的变更一律拒绝流转回中间态**。

### 4. 写入操作幂等性与超时策略
*   **审查项**：网络模块是否存在针对 POST / 写入接口的自动重试？
*   **规范**：
    - 只读（GET/Query）接口允许在超时后受控重试；
    - 写入（下单/扣款/撤单）接口必须带有客户端唯一 `clientOrderId` 做幂等兜底，且**超时后绝不允许自动重试**，必须提示用户手动刷新查询。

---

## 四、Agent 交付报告模板

```markdown
### 🌐 网络时序与状态竞态审查报告

- **风险等级**：CRITICAL (资金重复扣减/状态回退) / HIGH (假死连接无感知)
- **审查维度**：[弱网心跳探测 / 事件乱序回退 / 非幂等接口重试]
- **隐患代码位置**：`FilePath.swift:LineNumber`
- **竞态场景还原**：
  ```text
  WS 推送 seq=12 (filled) 先到达 ➔ 界面显示已成交
  HTTP 慢响应 seq=9 (pending) 后到达 ➔ [缺失版本检查] ➔ 界面错误回退为挂单中！
  ```
- **整改标准**：
  - 补充单调 Sequence 校验守卫；
  - 封锁状态机逆向转移路径；
  - 移除写入接口的无条件重试逻辑。
```
