---
description: XClientLab 并发安全与内存管理红线：弱引用捕获、线程竞态防御、Timer 释放与循环削峰
paths:
  - "XClientLab/**"
  - "Packages/**"
---
# 并发安全与内存管理规范

## 1. 逃逸闭包与强引用环拦截
- 任何逃逸闭包（`@escaping`）、异步分发（`DispatchQueue.async` / Combine `sink`）内访问 `self`，必须强制声明 `[weak self]`。
- delegate 协议必须声明为 `AnyObject`，并在宿主类中以 `weak var delegate: ...?` 弱引用修饰。
- 严禁强引用持有控制器或持有者对象；在 `deinit` 中断言释放，排查泄漏。

## 2. 计时器与异步源（Timer / DispatchSourceTimer）
- `Timer` / `DispatchSourceTimer` 必须具备生命周期感知，在页面 `viewDidDisappear` 或 `deinit` 中显式调用 `cancel()` 或 `invalidate()`，并置 `nil`。
- 异步定时器内部回调严禁访问已失效的底层指针或地址；在 UAF 敏感场景必须先判定对象生命周期再执行 `memcpy` 或成员访问。

## 3. 多线程数据竞争与原子性
- 共享可变状态严禁直接跨线程裸读写；`counter.pointee += 1` 不是原子操作，属于 Read-Modify-Write，高并发下必然导致 Lost Writes。
- 跨线程访问必须通过 **OSAllocatedUnfairLock**、**串行队列（Serial Queue）** 或 **Swift Actor** 进行状态收敛。
- 临界区保护原则：
  1. 锁范围必须保持绝对最小，严禁在临界区内调用耗时 IO 或发起外部网络请求；
  2. 严禁嵌套持有多把不同线程锁，防止发生死锁（Deadlock）。

## 4. 循环短命对象与内存削峰
- 在批量处理大量数据（如解析数千条 JSON、解密或图像渲染）的密集 `for` 循环中，必须用 `@autoreleasepool { ... }` 及时释放瞬时内存，平抑内存锯齿（Memory Sawtooth）。
- 内存缓存（`NSCache`）必须设置明确的 `countLimit` 与 `totalCostLimit`，并在收到系统内存警告（`didReceiveMemoryWarning`）时主动释放非活跃资源。
