---
name: concurrency-race-debug
description: 专门用于排查多线程数据竞争、非原子读写踩踏与死锁（对应场景 2.2）。结合 Thread Sanitizer (TSan) 机制，审查读写对称性锁保护与单调锁申请顺序。
---

# concurrency-race-debug Skill

本 Skill 对应 App 内「02 异常攻坚 → 2.2 多线程非原子读写与 munmap 踩踏」，专用于排查多线程环境下偶发的计数丢失、字典/数组写坏（SIGSEGV）、以及互锁导致的 App 无响应死锁。

---

## 一、排查核心痛点与反模式

1. **假性线程安全（“写时加锁，读时裸读”）**：
   - 很多开发者以为给 `setValue` 加了锁就安全了，但 `getValue` 裸读未加锁；读线程可能读到写线程只修改了一半的非法指针，导致不可逆崩溃。
2. **锁的重入与死锁**：
   - 使用不可重入锁（如 `os_unfair_lock`）在同一个线程内部重复获取；
   - 两个线程互相以不同顺序申请两个锁（AB 锁交错死锁）。
3. **把并发队列当成同步队列**：
   - 多个线程同时向同一个全局 `concurrent` 队列提交写任务，缺乏 `barrier` 或锁隔离。

---

## 二、TSan (Thread Sanitizer) 取证与报告解析

### 1. 开启与捕获
在 Xcode Scheme 或命令行测试时开启 TSan：
```bash
xcodebuild test ... -enableThreadSanitizer YES
```

### 2. TSan 报告特征解码
典型的 Data Race 报告结构如下：
```text
WARNING: ThreadSanitizer: data race (pid=1234)
  Write of size 8 at 0x000100234 by thread T2:
    #0 ViewController.updateData() OrderBook.swift:45
  Previous read of size 8 at 0x000100234 by thread T1:
    #0 ViewController.render() OrderBook.swift:80
```
*   **关键诊断信息**：
    - 两个线程（T1 与 T2）在无同步栅栏的情况下同时访问了地址 `0x000100234`；
    - 必须确定这两处调用位置是否位于同一个锁的作用域中。

---

## 三、四大核心排查清单

### 1. 共享集合类型的非原子突变
*   Swift 原生集合（`Array`、`Dictionary`、`Set`）均为值类型，但在写时复制（COW）和内存重新分配扩容时，**跨线程访问绝非线程安全**。
*   **高危特征**：没有使用锁或 actor 保护的全局字典或单例属性。

### 2. 读写对称性 (Read-Write Symmetry)
*   **铁律**：读和写必须共享同一把锁。
```swift
// ❌ 错误反模式：写时加锁，读时裸读
func append(_ item: Int) {
    lock.lock()
    array.append(item)
    lock.unlock()
}
func get(_ index: Int) -> Int {
    return array[index] // 💥 此时另一线程可能正在扩容重配内存，导致 SIGSEGV
}

// ✅ 正确范式：读写完全受锁保护
func get(_ index: Int) -> Int {
    lock.lock()
    defer { lock.unlock() }
    return array[index]
}
```

### 3. 死锁排查与单调锁时序 (Lock Ordering)
*   如果代码必须获取多把锁（例如 `LockA` 和 `LockB`），系统中的所有线程**必须严格按照固定顺序（例如先 A 后 B）申请锁**，严禁逆序申请，否则高频并发必发死锁。

### 4. 现代 Swift Concurrency 规范
*   跨并发上下文共享状态时，优先采用 `actor` 或 `@MainActor` 隔离，依靠编译器在编译期做 Data Race Safety 检查；
*   对于底层极高性能场景，采用 `os_unfair_lock` 取代昂贵的 `pthread_mutex` 或 `NSLock`。

---

## 四、Agent 交付报告模板

```markdown
### ⚡ 多线程数据竞争与死锁排查报告

- **严重等级**：CRITICAL (高频崩溃/死锁) / HIGH (偶发踩踏/数据不一致)
- **踩踏类型**：[Data Race 非原子读写 / 丢失写次数 / AB-BA 互相死锁]
- **涉事线程与代码**：
  - Thread A (Write): `FilePath.swift:LineNumber`
  - Thread B (Read/Write): `FilePath.swift:LineNumber`
- **锁状态分析**：指出是否存在单侧未加锁、锁对象未共享或锁重入问题。
- **治理建议**：
  - 方案 1：采用 `os_unfair_lock` 保证读写完全对称；
  - 方案 2：将共享状态封装入专用 `actor`；
  - 方案 3：调整加锁顺序消除死锁环路。
```
