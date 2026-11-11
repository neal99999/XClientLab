import Combine
import Foundation
import UIKit

/// Scenario 4.3 — AI 交付与质量防线。
///
/// 古法交付痛点：PR 一来就是几百行，评审者看不完也看不出重点；AI 评审又会吐出
/// 大量“建议改名 / 补注释 / 写得更优雅”的噪音，把真正的空指针、死锁与业务偏差
/// 淹没；UI 还原靠人眼比对 Figma，Loading / Empty / Error / 长文本这些异常态
/// 往往要等线上用户来发现。
///
/// 这里的做法：把「信噪比过滤、三轮收敛、风险分级、六态驱动、像素快照」做成
/// 一条可交互的状态机。页面只订阅一份 `ViewState`，所有文案与视图都由
/// `render(_:)` 单向推导，不额外维护散落的布尔开关。
@MainActor
final class DeliveryGuardViewModel: ObservableObject {
    // MARK: - Review domain

    enum ReviewMode: String, CaseIterable, Hashable {
        case rawNoise
        case filtered
        case converged

        var title: String {
            switch self {
            case .rawNoise: return "原始 AI 评审 (噪音严重)"
            case .filtered: return "规则过滤与风险分级 (治理后)"
            case .converged: return "模拟 3 轮收敛状态机"
            }
        }

        var accent: UIColor {
            switch self {
            case .rawNoise: return LabUI.coral
            case .filtered: return LabUI.mint
            case .converged: return LabUI.cyan
            }
        }
    }

    enum ConvergenceStage: Int, Hashable {
        case round1 = 1
        case round2 = 2
        case round3 = 3
        case circuitBreaker = 4

        var accent: UIColor {
            switch self {
            case .round1: return LabUI.cyan
            case .round2: return LabUI.amber
            case .round3: return LabUI.mint
            case .circuitBreaker: return LabUI.coral
            }
        }
    }

    enum Severity: String, Hashable {
        case nit = "NIT"
        case major = "P1 MAJOR"
        case blocker = "P0 BLOCKER"

        var color: UIColor {
            switch self {
            case .nit: return LabUI.steel
            case .major: return LabUI.amber
            case .blocker: return LabUI.coral
            }
        }
    }

    struct ReviewComment: Hashable {
        let id: String
        let severity: Severity
        let title: String
        let detail: String?
        let location: String?
    }

    struct ConvergenceRow: Hashable {
        let index: String
        let title: String
        let detail: String
        let status: ConvergenceStatus
    }

    enum ConvergenceStatus: Hashable {
        case done
        case active
        case pending
        case failed

        var color: UIColor {
            switch self {
            case .done: return LabUI.mint
            case .active: return LabUI.cyan
            case .pending: return LabUI.textTertiary
            case .failed: return LabUI.coral
            }
        }

        var symbol: String {
            switch self {
            case .done: return "✓"
            case .active: return "▶"
            case .pending: return "○"
            case .failed: return "!"
            }
        }

        var label: String {
            switch self {
            case .done: return "已完成"
            case .active: return "进行中"
            case .pending: return "待执行"
            case .failed: return "已熔断"
            }
        }
    }

    // MARK: - UI six-state

    enum AssetState: String, CaseIterable, Hashable {
        case loading
        case loaded
        case empty
        case error
        case extreme
        case debounce

        var chipTitle: String {
            switch self {
            case .loading: return "LOADING"
            case .loaded: return "LOADED"
            case .empty: return "EMPTY"
            case .error: return "ERROR"
            case .extreme: return "EXTREME"
            case .debounce: return "DEBOUNCE"
            }
        }

        var title: String {
            switch self {
            case .loading: return "Loading · 骨架屏"
            case .loaded: return "Loaded · 理想态"
            case .empty: return "Empty · 缺省态"
            case .error: return "Error & Retry · 失败重试"
            case .extreme: return "Boundary · 极端长文本"
            case .debounce: return "Debounce · 暴力狂点"
            }
        }

        var icon: String {
            switch self {
            case .loading: return "clock.arrow.circlepath"
            case .loaded: return "wallet.pass.fill"
            case .empty: return "tray"
            case .error: return "exclamationmark.triangle.fill"
            case .extreme: return "exclamationmark.shield.fill"
            case .debounce: return "hand.tap.fill"
            }
        }

        var accent: UIColor {
            switch self {
            case .loading: return LabUI.steel
            case .loaded: return LabUI.mint
            case .empty: return LabUI.amber
            case .error: return LabUI.coral
            case .extreme: return LabUI.amber
            case .debounce: return LabUI.cyan
            }
        }

        /// 机器级像素 Diff，容差 0.5%；极端长文本仍必须落在阈值内。
        var snapshotDiff: Double {
            switch self {
            case .loaded, .empty, .debounce: return 0.00
            case .loading: return 0.12
            case .error: return 0.08
            case .extreme: return 0.34
            }
        }
    }

    // MARK: - Single source of truth

    struct ViewState: Equatable {
        var reviewMode: ReviewMode = .rawNoise
        var convergenceStage: ConvergenceStage = .round1
        var assetState: AssetState = .loaded
        var acceptedRefreshCount = 0
        var shieldedRefreshCount = 0

        var reviewStatusText: String {
            switch reviewMode {
            case .rawNoise: return "RAW · 10 COMMENTS"
            case .filtered: return "FILTERED · 2 SIGNAL"
            case .converged:
                switch convergenceStage {
                case .round1: return "ROUND 1/3 · GLOBAL SCAN"
                case .round2: return "ROUND 2/3 · INCREMENTAL DIFF"
                case .round3: return "ROUND 3/3 · CONVERGED"
                case .circuitBreaker: return "CIRCUIT BREAKER · HUMAN"
                }
            }
        }

        var reviewStatusColor: UIColor {
            switch reviewMode {
            case .rawNoise: return LabUI.coral
            case .filtered: return LabUI.mint
            case .converged: return convergenceStage.accent
            }
        }

        var reviewSummary: String {
            switch reviewMode {
            case .rawNoise:
                return "8 条 Nit 排在最前，真正的 BLOCKER 被挤到列表末尾。"
            case .filtered:
                return "过滤 Hook 拦截 8 条噪音，只保留 1 条 BLOCKER 与 1 条 MAJOR。"
            case .converged:
                switch convergenceStage {
                case .round1: return "第 1 轮：全局依赖 + 同类问题一次性指出。"
                case .round2: return "第 2 轮：只读增量 Diff，不重复上一轮意见。"
                case .round3: return "第 3 轮：确认无新增问题，自动审查通过。"
                case .circuitBreaker: return "第 4 轮请求被守卫拦截：超过 3 轮强制人工仲裁。"
                }
            }
        }

        var reviewFootnote: String {
            switch reviewMode {
            case .rawNoise:
                return "SIGNAL 20% · 评审者注意力被格式建议消耗 · 真正的风险排在最后"
            case .filtered:
                return "SIGNAL 100% · 8 条 Nit 已被 Hook 静默归档 · BLOCKER 进入 Tier 3 审批"
            case .converged:
                return "熔断阈值 = 3 轮 · 第 4 轮自动暂停 · 人工仲裁拥有最终裁决权"
            }
        }

        var signalRatio: Double {
            switch reviewMode {
            case .rawNoise: return 0.20
            case .filtered: return 1.0
            case .converged:
                switch convergenceStage {
                case .round1: return 0.40
                case .round2: return 0.75
                case .round3: return 1.0
                case .circuitBreaker: return 0.0
                }
            }
        }

        var convergenceActionTitle: String {
            switch convergenceStage {
            case .round1: return "STEP → 第 2 轮 · 局部增量"
            case .round2: return "STEP → 第 3 轮 · 收敛裁决"
            case .round3: return "TRY 4TH ROUND → 触发熔断"
            case .circuitBreaker: return "RESET → 重新演练"
            }
        }

        var snapshotDiff: Double {
            assetState.snapshotDiff
        }

        var snapshotPass: Bool {
            snapshotDiff <= DeliveryGuardViewModel.snapshotTolerance
        }
    }

    // MARK: - State

    @Published private(set) var state = ViewState()

    private var retryToken = UUID()
    private var lastAcceptedRefresh: Date?

    // MARK: - Intents

    func selectReviewMode(_ mode: ReviewMode) {
        var next = state
        next.reviewMode = mode
        if mode == .converged {
            next.convergenceStage = .round1
        }
        state = next
    }

    func advanceConvergence() {
        guard state.reviewMode == .converged else { return }
        var next = state
        switch next.convergenceStage {
        case .round1: next.convergenceStage = .round2
        case .round2: next.convergenceStage = .round3
        case .round3: next.convergenceStage = .circuitBreaker
        case .circuitBreaker: next.convergenceStage = .round1
        }
        state = next
    }

    func selectAssetState(_ assetState: AssetState) {
        if assetState == .debounce {
            lastAcceptedRefresh = nil
            var next = state
            next.assetState = .debounce
            next.acceptedRefreshCount = 0
            next.shieldedRefreshCount = 0
            state = next
            return
        }
        updateAssetState(assetState)
    }

    func retryAsset() {
        guard state.assetState == .error else { return }
        let token = UUID()
        retryToken = token
        updateAssetState(.loading)
        // 留出 0.75s 让骨架屏可见，模拟真实网络往返。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self, self.retryToken == token else { return }
            self.updateAssetState(.loaded)
        }
    }

    func requestRefresh() {
        guard state.assetState == .debounce else { return }
        let now = Date()
        var next = state
        if let lastAcceptedRefresh, now.timeIntervalSince(lastAcceptedRefresh) < Self.refreshWindow {
            next.shieldedRefreshCount += 1
        } else {
            lastAcceptedRefresh = now
            next.acceptedRefreshCount += 1
        }
        state = next
    }

    private func updateAssetState(_ assetState: AssetState) {
        var next = state
        next.assetState = assetState
        state = next
    }
}
