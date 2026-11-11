---
description: 只读追踪页面持有链、订阅和异步任务的释放
argument-hint: "[页面或模块，默认合约 K 线详情]"
disable-model-invocation: true
---

先读取 `.claude/neal/project-context.md` 并遵守共用规则。
用户范围：$ARGUMENTS

只读。检查闭包保存方与捕获、delegate、Timer/DisplayLink、通知 token、WebSocket 本地/远端订阅、Rx/Combine、GCD/Task、图片请求、缓存增长。区分页面消失与销毁、有限任务暂时持有与永久循环；检查退订后在途回调。不能仅因没写 deinit 或 removeObserver 就判泄漏，先确认注册方式与 API 生命周期。

输出持有关系/资源表（创建、持有、停止、释放位置）及最多 5 项发现；给 Memory Graph/Leaks 的最小验证步骤和重复进出页面的观察方法。无运行证据不能称“已复现泄漏”。不修改代码或插入日志。
