import Foundation
import UIKit

/// 演示数据独立成扩展：页面只读这些确定性文案，避免把「内容」和「状态机」混在一个类型体里。
extension DeliveryGuardViewModel {
    static let snapshotTolerance = 0.5
    static let refreshWindow: TimeInterval = 0.6

    static let noiseComments: [ReviewComment] = [
        ReviewComment(
            id: "nit.rename",
            severity: .nit,
            title: "建议把 orderService 改名为 service，更简洁",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.comment",
            severity: .nit,
            title: "建议补充注释说明这段重试逻辑",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.elegant",
            severity: .nit,
            title: "可以写得更优雅，例如用 reduce 替代 for 循环",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.width",
            severity: .nit,
            title: "这一行超过 120 字符，建议手动换行",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.self",
            severity: .nit,
            title: "建议统一补全 self. 前缀，保持风格一致",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.blank",
            severity: .nit,
            title: "这里多了一个空行，建议删除",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.constant",
            severity: .nit,
            title: "建议把 3 提取为常量（文件顶部已有同名常量）",
            detail: nil,
            location: nil
        ),
        ReviewComment(
            id: "nit.style",
            severity: .nit,
            title: "命名风格建议与相邻文件保持一致",
            detail: nil,
            location: nil
        )
    ]

    static let signalComments: [ReviewComment] = [
        ReviewComment(
            id: "p0.retain-cycle",
            severity: .blocker,
            title: "回调闭包强引用 self，且持锁重入：内存泄漏 + 潜在死锁",
            detail: "self 在异步回调里被强引用，页面退出后无法释放；回调在主线程持有 NSLock 时再次进入同一把锁，触发死锁。",
            location: "TradeOrderService.swift:118 · 需要 [weak self] + 锁外回调"
        ),
        ReviewComment(
            id: "p1.double-money",
            severity: .major,
            title: "金额用 Double 参与计算，绕过大数精度链路",
            detail: "资金计算必须走 String 大数扩展；Double 在 0.1 + 0.2 场景会产生精度偏差，属于业务规则偏差。",
            location: "OrderAmountFormatter.swift:42 · bigAddContract"
        )
    ]

    static let rawComments: [ReviewComment] = noiseComments + signalComments

    static func comments(for mode: ReviewMode) -> [ReviewComment] {
        switch mode {
        case .rawNoise: return rawComments
        case .filtered: return signalComments
        case .converged: return []
        }
    }

    static func convergenceRows(for stage: ConvergenceStage) -> [ConvergenceRow] {
        var rows = [
            ConvergenceRow(
                index: "01",
                title: "第 1 轮 · 全局架构扫描",
                detail: "跨模块依赖与同类问题一次性指出，避免逐行挤牙膏。",
                status: stage.rawValue > 1 ? .done : .active
            ),
            ConvergenceRow(
                index: "02",
                title: "第 2 轮 · 局部增量验证",
                detail: "只读本轮 Diff，不重复上一轮意见，防止审查原地打转。",
                status: stage.rawValue > 2 ? .done : (stage.rawValue == 2 ? .active : .pending)
            ),
            ConvergenceRow(
                index: "03",
                title: "第 3 轮 · 收敛裁决",
                detail: "无新增问题则通过；仍有阻塞项则进入人工仲裁。",
                status: stage.rawValue >= 3 ? .done : .pending
            )
        ]
        if stage == .circuitBreaker {
            rows.append(ConvergenceRow(
                index: "04",
                title: "第 4 轮 · 熔断守卫",
                detail: "超过 3 轮强制暂停自动审查，转 Tier 3 双人 + 安全专员。",
                status: .failed
            ))
        }
        return rows
    }
}
