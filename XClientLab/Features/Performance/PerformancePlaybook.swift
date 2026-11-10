import UIKit

/// 性能实验室的内容模型。
///
/// 把“讲什么”从“怎么排 UI”里拆出来：五个主题各自有目标、检查清单、
/// 古法痛点、AI/MCP 切入点和现场证据。控制器只负责把内容排成卡片，
/// 以后补一个主题不需要再写一套页面。
struct PerformanceTopic {
    struct Stat {
        let label: String
        let value: String
        let unit: String?
        let detail: String
        let color: UIColor
    }

    struct Point {
        let lead: String
        let body: String
    }

    struct Section {
        let kicker: String
        let title: String
        let points: [Point]
    }

    struct Evidence {
        let title: String
        let subtitle: String
        let identifier: String
        let destination: () -> UIViewController
    }

    let id: String
    let index: String
    let title: String
    let subtitle: String
    let goal: String
    let accent: UIColor
    let stats: [Stat]
    let sections: [Section]
    let pitfall: String
    let aiNote: String
    let evidence: [Evidence]
}

enum PerformancePlaybook {
    static let topics: [PerformanceTopic] = [
        launch,
        ui,
        network,
        memory,
        cpu,
    ]

    static func topic(id: String) -> PerformanceTopic? {
        topics.first { $0.id == id }
    }

    // MARK: - 01 Launch & package

    private static let launch = PerformanceTopic(
        id: "launch",
        index: "01",
        title: "启动速度与包大小",
        subtitle: "启动不是“加个启动图”，而是把 main 前后的工作量拆开算账。",
        goal: "首帧前只做必须做的事：能合并的依赖合并，能延后的初始化全部延后；包体先删再换，最后才谈压缩。",
        accent: LabUI.cyan,
        stats: [
            .init(label: "PRE-MAIN", value: "<400", unit: "ms", detail: "冷启动预算", color: LabUI.cyan),
            .init(label: "MAIN-POST", value: "<100", unit: "ms", detail: "didFinish 同步", color: LabUI.amber),
            .init(label: "SIZE", value: "↓10", unit: "%", detail: "资源/编译", color: LabUI.mint),
        ],
        sections: [
            .init(kicker: "PRE-MAIN", title: "main 之前：减少加载与重定位", points: [
                .init(
                    lead: "减少 / 合并动态库",
                    body: "每个 dylib 都有 dyld 加载、符号绑定和 page fault 成本。能进静态库的依赖不要拆成多个动态库；先看 `otool -L` 和启动 trace，再决定合并谁。"
                ),
                .init(
                    lead: "减少 ObjC 类、分类与静态构造函数",
                    body: "`+load`、`__attribute__((constructor))`、全局 C++ 对象都会在 main 前执行。能改成懒加载的注册表，就不要在启动时全量扫描。"
                ),
                .init(
                    lead: "二进制插装与二进制重排",
                    body: "先用 `-finstrument-functions` / signpost 找到启动热路径，再用 `-order_file` 把热函数排到相邻页，减少冷启动 page fault；不要凭感觉排序。"
                ),
            ]),
            .init(kicker: "MAIN-POST", title: "main 之后：首帧只服务首屏", points: [
                .init(
                    lead: "延迟 SDK / 三方库初始化",
                    body: "推送、埋点、DB、图片库不要在 `didFinishLaunchingWithOptions` 里同步做完。用 lazy、后台队列或首帧后的 `viewDidAppear` 分批启动。"
                ),
                .init(
                    lead: "启动图不是优化",
                    body: "启动图只掩盖白屏，不减少任何工作量。真正的指标是首帧时间、主线程阻塞和用户可交互时间。"
                ),
                .init(
                    lead: "首屏依赖最小化",
                    body: "首屏只装配必要服务；非首屏模块用路由/懒加载按需拉起，避免“启动时把整个 App 都点亮”。"
                ),
            ]),
            .init(kicker: "APP THINNING", title: "包大小：删、换、压、裁", points: [
                .init(
                    lead: "先删无用资源",
                    body: "清理未引用图片、重复字体、旧 xcassets；用 `xcrun size`、`assetutil` 和链接 map 找大文件，不要靠猜。"
                ),
                .init(
                    lead: "矢量图替代多倍位图",
                    body: "单尺寸 PDF/SVG 交给 Asset Catalog，避免 @1x/@2x/@3x 三套位图；复杂插画再考虑按需下载。"
                ),
                .init(
                    lead: "动画与编译配置",
                    body: "帧动画换 Lottie/代码动画；开启 LTO、`-Osize`、App Thinning、On-Demand Resources。Bitcode 已被 Apple 废弃，不要再把它当答案。"
                ),
            ]),
        ],
        pitfall: "古法：盯着启动日志、凭感觉删资源，最后只会说“快了”。没有 main 前/后分段、首帧时间、包大小 diff，就无法证明优化真的有效。",
        aiNote: "让 MCP 读取 App Launch trace、`xcodebuild -showBuildSettings` 和链接 map，按 pre-main / main-post / 资源三类生成“可删、可延迟、可合并”清单，再逐项回归。",
        evidence: []
    )

    // MARK: - 02 UI

    private static let ui = PerformanceTopic(
        id: "ui",
        index: "02",
        title: "UI 渲染优化",
        subtitle: "卡顿通常不是“画得不够快”，而是层级、透明、离屏和无效刷新太多。",
        goal: "把每一帧的布局、绘制、合成成本压到预算内；列表只创建屏幕附近的行，圆角尽量不要触发离屏。",
        accent: LabUI.violet,
        stats: [
            .init(label: "FRAME", value: "16.7", unit: "ms", detail: "60Hz 预算", color: LabUI.cyan),
            .init(label: "OFFSCREEN", value: "0", unit: "pass", detail: "目标", color: LabUI.mint),
            .init(label: "REUSE", value: "1x", unit: "cell", detail: "复用", color: LabUI.amber),
        ],
        sections: [
            .init(kicker: "HIERARCHY", title: "层级与透明：先减，再画", points: [
                .init(
                    lead: "减少视图嵌套",
                    body: "能用一层 `UIStackView` 或自绘解决的，不要套五层容器。层级越深，layout 与 draw 的遍历越贵。"
                ),
                .init(
                    lead: "减少透明视图",
                    body: "大面积 `backgroundColor = .clear` 叠加会产生 overdraw。用 Color Blended Layers 检查，把静态背景合成成一张图或一个 `CALayer`。"
                ),
                .init(
                    lead: "静态内容扁平化",
                    body: "网格、渐变、重复装饰不要用几百个 subview 拼；离屏渲染成一张背景图，运行时只贴图。"
                ),
            ]),
            .init(kicker: "LIST", title: "列表：复用、高度、异步", points: [
                .init(
                    lead: "cell 复用",
                    body: "`dequeueReusableCell` + 轻量 `prepareForReuse`；重计算不要放在 `cellForRow`，否则滚动时每一帧都在算。"
                ),
                .init(
                    lead: "缓存 cell 高度",
                    body: "固定行高直接设 `rowHeight`；动态高度用缓存字典 + `estimatedRowHeight`，避免反复 `systemLayoutSizeFitting`。"
                ),
                .init(
                    lead: "图片异步加载",
                    body: "Kingfisher/SDWebImage 异步解码 + 降采样，主线程只赋值；图片尺寸按 cell 实际像素生成，不要先解全图再缩。"
                ),
            ]),
            .init(kicker: "DRAW", title: "圆角与重绘：别让 GPU 替你加班", points: [
                .init(
                    lead: "避免离屏圆角",
                    body: "`cornerRadius + masksToBounds` 对含内容的 view 可能触发 offscreen。优先 CoreGraphics 预渲染圆角图，或透明圆角覆盖层。"
                ),
                .init(
                    lead: "预渲染要按 scale",
                    body: "用 `UIGraphicsImageRenderer` 按屏幕 scale 生成圆角图；缓存到 `NSCache`，不要每次 cell 配置都重新画。"
                ),
                .init(
                    lead: "减少无效刷新",
                    body: "合并 `setNeedsDisplay` / `setNeedsLayout`；只刷新脏矩形，动画优先改 `CALayer` 属性，不要每帧重画整棵视图树。"
                ),
            ]),
        ],
        pitfall: "古法：View Debugger 看到层级深，但不知道 overdraw/离屏；改完没有 FPS、hitch、离屏帧对比，只能凭感觉说“顺了”。",
        aiNote: "让 MCP 同时读取 View Hierarchy 与 Color Offscreen-Rendered 截图，按透明层、离屏圆角、重复布局分类；再结合 Hitch trace 给出“扁平化/预渲染/缓存高度”的优先级。",
        evidence: [
            .init(
                title: "现场看 5,000 行列表的复用与内存",
                subtitle: "Allocations 锯齿实验同时暴露 cell 复用、临时对象和峰值。",
                identifier: "perf.evidence.list",
                destination: { AllocationStormViewController() }
            ),
        ]
    )

    // MARK: - 03 Network

    private static let network = PerformanceTopic(
        id: "network",
        index: "03",
        title: "网络请求优化",
        subtitle: "网络优化不是“加个缓存”，而是把请求数量、缓存层级和弱网策略一起设计。",
        goal: "同一份数据只请求一次；能合并的合并，能复用的复用；弱网下用超时、退避和幂等保证最终一致。",
        accent: LabUI.mint,
        stats: [
            .init(label: "REQUESTS", value: "1x", unit: "batch", detail: "同屏合并", color: LabUI.mint),
            .init(label: "CACHE HIT", value: ">80", unit: "%", detail: "目标", color: LabUI.cyan),
            .init(label: "TIMEOUT", value: "3", unit: "s", detail: "弱网预算", color: LabUI.amber),
        ],
        sections: [
            .init(kicker: "COALESCE", title: "减少请求：合并、去重、单飞", points: [
                .init(
                    lead: "批量接口",
                    body: "同一屏多个组件请求同一 symbol/同一列表时，合并成一次 batch；不要让 10 个 cell 各自发一次行情请求。"
                ),
                .init(
                    lead: "single-flight",
                    body: "相同请求在途时复用同一个 `Task`/回调，避免并发重复打网关；返回后统一广播给等待者。"
                ),
                .init(
                    lead: "debounce / 节流",
                    body: "搜索、筛选、滚动加载用 debounce；高频行情用时间窗聚合，不要把每条推送都变成一次请求。"
                ),
            ]),
            .init(kicker: "CACHE", title: "缓存分层：内存、KV、数据库", points: [
                .init(
                    lead: "NSCache",
                    body: "内存缓存，系统内存紧张会自动回收；适合图片、解析后的 DTO、短期行情快照。设置 `countLimit` / `totalCostLimit`。"
                ),
                .init(
                    lead: "MMKV / SQLite",
                    body: "MMKV 适合高频 KV 与冷启动恢复；SQLite 适合查询、分页和离线数据。不要把所有东西都塞 UserDefaults。"
                ),
                .init(
                    lead: "HTTP 缓存",
                    body: "用 ETag / Cache-Control / stale-while-revalidate；先返回旧数据再后台刷新，弱网下体验更稳。"
                ),
            ]),
            .init(kicker: "WEAK NETWORK", title: "弱网：超时、退避、幂等", points: [
                .init(
                    lead: "超时与重试上限",
                    body: "设置连接/读取超时和最大重试次数；指数退避 + jitter，避免所有客户端在同一秒重连。"
                ),
                .init(
                    lead: "请求幂等",
                    body: "下单/支付必须带幂等键；重试只能重放安全请求，不能重复扣款。"
                ),
                .init(
                    lead: "可观测性",
                    body: "记录 P50/P95、缓存命中率、合并率、重试次数；没有这些指标，网络优化无法回归。"
                ),
            ]),
        ],
        pitfall: "古法：Charles 一条条看请求，靠肉眼找重复；没有请求数、命中率、P95，就不知道优化的是“数量”还是“等待”。",
        aiNote: "让 MCP 读取 Network trace / HAR，按 endpoint 聚合重复请求，输出“可合并、可缓存、可延迟”的候选，并给出 TTL 与超时建议。",
        evidence: [
            .init(
                title: "弱网重连：退避 + Jitter + 上限",
                subtitle: "看状态机如何避免重连风暴。",
                identifier: "perf.evidence.reconnect",
                destination: { ReconnectViewController() }
            ),
            .init(
                title: "高频盘口：节流 + 差分",
                subtitle: "看事件如何折叠成状态，避免主线程被推送数量驱动。",
                identifier: "perf.evidence.book",
                destination: { OrderBookViewController() }
            ),
        ]
    )

    // MARK: - 04 Memory

    private static let memory = PerformanceTopic(
        id: "memory",
        index: "04",
        title: "内存优化",
        subtitle: "内存问题往往不是“占得多”，而是“该释放的没释放，或者一次拿了太多”。",
        goal: "先消灭循环引用和未注销的观察者，再谈分页、降采样和缓存上限；最后用 Memory Graph 证明对象真的释放了。",
        accent: LabUI.coral,
        stats: [
            .init(label: "RETAIN CYCLE", value: "0", unit: "leak", detail: "目标", color: LabUI.mint),
            .init(label: "PAGE", value: "分页", unit: nil, detail: "大对象", color: LabUI.cyan),
            .init(label: "CACHE", value: "NSCache", unit: nil, detail: "自动回收", color: LabUI.amber),
        ],
        sections: [
            .init(kicker: "OWNERSHIP", title: "引用关系：谁持有谁", points: [
                .init(
                    lead: "闭包 / Block 用 weak self",
                    body: "长期持有的闭包（网络回调、动画、通知）默认强引用 self；用 `[weak self]`，并在闭包内 `guard let self else { return }`。"
                ),
                .init(
                    lead: "Delegate 用 weak",
                    body: "`weak var delegate`，协议继承 `AnyObject`；不要让被代理对象反向强持有代理。"
                ),
                .init(
                    lead: "Timer / DispatchSource 要失效",
                    body: "`Timer` 的 target 会强持有 self；用 block + weak self，并在 `deinit`/`viewDidDisappear` invalidate。`DispatchSource` 也要 cancel。"
                ),
                .init(
                    lead: "通知与观察者",
                    body: "NotificationCenter 的 block token、KVO、Combine cancellable 都要在销毁时移除；不要只依赖“系统会自动清理”。"
                ),
            ]),
            .init(kicker: "FOOTPRINT", title: "大对象：分页、降采样、及时释放", points: [
                .init(
                    lead: "分页加载",
                    body: "大列表/大 JSON/大图不要一次性全量进内存；分页或流式解析，只保留屏幕附近的数据。"
                ),
                .init(
                    lead: "图片降采样",
                    body: "先读尺寸再按目标像素解码，避免“全图解码后再缩小”；大图用 `CGImageSourceCreateThumbnailAtIndex`。"
                ),
                .init(
                    lead: "autoreleasepool",
                    body: "循环里产生大量临时对象时，用 `autoreleasepool` 按批释放，削平峰值而不是等自动释放池统一回收。"
                ),
            ]),
            .init(kicker: "TOOLS", title: "用证据收尾", points: [
                .init(
                    lead: "Allocations",
                    body: "看峰值、增长趋势和瞬时对象；确认是缓存、图片还是列表数据导致的锯齿。"
                ),
                .init(
                    lead: "Leaks",
                    body: "看对象是否在预期生命周期后仍存活；Leaks 只能抓“完全不可达”的环，不能替代 Memory Graph。"
                ),
                .init(
                    lead: "Memory Graph",
                    body: "直接看 retain path：谁持有了谁、哪条闭包/Timer 没断。修复后再跑一次，确认对象 deinit。"
                ),
            ]),
        ],
        pitfall: "古法：Leaks 跑一遍看到红叉，却不知道谁持有；Allocations 只看总量，看不到峰值和释放时机。没有 retain path，就只能猜。",
        aiNote: "让 MCP 解析 Memory Graph / Leaks 的 retain path，按闭包、Timer、Delegate、Notification 归类，生成最小修复和一条能验证 deinit 的回归用例。",
        evidence: [
            .init(
                title: "现场看 Allocations 锯齿与峰值",
                subtitle: "5,000 行列表 + 高频临时对象，观察 footprint 曲线。",
                identifier: "perf.evidence.alloc",
                destination: { AllocationStormViewController() }
            ),
            .init(
                title: "生命周期与 UAF 现场",
                subtitle: "对象释放后仍被使用，系统栈如何给出地址线索。",
                identifier: "perf.evidence.uaf",
                destination: { UAFScenarioViewController() }
            ),
        ]
    )

    // MARK: - 05 CPU

    private static let cpu = PerformanceTopic(
        id: "cpu",
        index: "05",
        title: "CPU 与主线程",
        subtitle: "CPU 优化不是“多开线程”，而是把工作放到正确的队列，并减少无效计算和锁竞争。",
        goal: "主线程只做 UI 和事件响应；用合适的数据结构、缓存和锁粒度，把单帧主线程成本压到 16ms 以内。",
        accent: LabUI.cyan,
        stats: [
            .init(label: "MAIN", value: "<16", unit: "ms", detail: "单帧预算", color: LabUI.cyan),
            .init(label: "LOOKUP", value: "O(1)", unit: nil, detail: "字典/集合", color: LabUI.mint),
            .init(label: "LOCKS", value: "0", unit: "contention", detail: "目标", color: LabUI.amber),
        ],
        sections: [
            .init(kicker: "THREADING", title: "线程：主线程只服务 UI", points: [
                .init(
                    lead: "耗时任务下沉",
                    body: "JSON 解析、正则、图片解码、DB 查询、文件 IO 放背景队列；主线程只接收结果并刷新 UI。"
                ),
                .init(
                    lead: "选择合适 QoS",
                    body: "用户可见的用 `.userInitiated`，后台预取用 `.utility`；不要把所有任务都丢到 `.background` 导致首屏变慢。"
                ),
                .init(
                    lead: "避免同步等待",
                    body: "主线程不要 `sync` 到串行队列，也不要用信号量等异步结果；这会直接制造不可控的卡顿和优先级反转。"
                ),
            ]),
            .init(kicker: "ALGORITHM", title: "数据结构与缓存", points: [
                .init(
                    lead: "查找用字典/集合",
                    body: "频繁查找不要遍历数组：`Dictionary`/`Set` 平均 O(1)，数组是 O(n)；先看数据规模和访问模式。"
                ),
                .init(
                    lead: "减少重复计算",
                    body: "把布局、格式化、指标计算缓存起来；输入不变就不要重复算，尤其是 cell 配置和滚动回调。"
                ),
                .init(
                    lead: "只算可见区",
                    body: "长列表/图表只处理视口内的数据；滚动时取消离屏任务，避免“用户看不到的也在算”。"
                ),
            ]),
            .init(kicker: "CONCURRENCY", title: "锁：缩小临界区", points: [
                .init(
                    lead: "缩短持锁时间",
                    body: "锁内只做内存读写，不做 IO、网络、回调；把不共享的计算移到锁外。"
                ),
                .init(
                    lead: "避免嵌套锁",
                    body: "多把锁按固定顺序获取；能用串行队列/actor 解决就不要手写多锁，减少死锁面。"
                ),
                .init(
                    lead: "优先级反转",
                    body: "低优先级任务持锁、高优先级任务等待会反转；用 `os_unfair_lock` 的优先级继承，或把共享状态收敛到单一队列。"
                ),
            ]),
        ],
        pitfall: "古法：Time Profiler 看到最重栈，却分不清是算法、锁还是主线程排队；凭感觉换 API，最后只是把瓶颈挪了个位置。",
        aiNote: "让 MCP 读取 Time Profiler 的 self time 与调用次数，生成可复现的 microbenchmark，再对比数组 vs 字典、无锁 vs 锁、主线程 vs 背景队列。",
        evidence: [
            .init(
                title: "现场制造主线程 >500ms 卡顿",
                subtitle: "同步 JSON + 正则，观察 worst pass 与 dropped frames。",
                identifier: "perf.evidence.cpu",
                destination: { CPUStallViewController() }
            ),
        ]
    )
}
