import XCTest
@testable import XClientLab

@MainActor
final class DeliveryGuardViewModelTests: XCTestCase {
    func testInitialStateShowsLoadedAssetInRawNoiseMode() {
        let viewModel = DeliveryGuardViewModel()

        XCTAssertEqual(viewModel.state.reviewMode, .rawNoise)
        XCTAssertEqual(viewModel.state.assetState, .loaded)
        XCTAssertEqual(viewModel.state.convergenceStage, .round1)
        XCTAssertEqual(viewModel.state.acceptedRefreshCount, 0)
        XCTAssertEqual(viewModel.state.shieldedRefreshCount, 0)
        XCTAssertTrue(viewModel.state.snapshotPass)
        XCTAssertEqual(viewModel.state.snapshotDiff, 0, accuracy: 0.0001)
    }

    func testFilteredModeKeepsOnlySignalComments() {
        let raw = DeliveryGuardViewModel.comments(for: .rawNoise)
        XCTAssertEqual(raw.count, 10)
        XCTAssertEqual(raw.filter { $0.severity == .nit }.count, 8)
        XCTAssertEqual(raw.filter { $0.severity == .blocker }.count, 1)

        let filtered = DeliveryGuardViewModel.comments(for: .filtered)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertFalse(filtered.contains { $0.severity == .nit })
        XCTAssertEqual(filtered.first?.severity, .blocker)
        XCTAssertTrue(filtered.contains { $0.severity == .major })
    }

    func testConvergenceStateMachineConvergesThenBreaksTheLoop() {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectReviewMode(.converged)
        XCTAssertEqual(viewModel.state.convergenceStage, .round1)

        viewModel.advanceConvergence()
        XCTAssertEqual(viewModel.state.convergenceStage, .round2)
        viewModel.advanceConvergence()
        XCTAssertEqual(viewModel.state.convergenceStage, .round3)
        viewModel.advanceConvergence()
        XCTAssertEqual(viewModel.state.convergenceStage, .circuitBreaker)

        // 第 4 轮不继续无限循环，而是回到第 1 轮等待人工重新裁决。
        viewModel.advanceConvergence()
        XCTAssertEqual(viewModel.state.convergenceStage, .round1)
    }

    func testAdvanceConvergenceIsIgnoredOutsideConvergedMode() {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectReviewMode(.filtered)

        viewModel.advanceConvergence()

        XCTAssertEqual(viewModel.state.convergenceStage, .round1)
    }

    func testDebounceAcceptsFirstRefreshAndShieldsBurst() {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectAssetState(.debounce)

        viewModel.requestRefresh()
        XCTAssertEqual(viewModel.state.acceptedRefreshCount, 1)
        XCTAssertEqual(viewModel.state.shieldedRefreshCount, 0)

        viewModel.requestRefresh()
        viewModel.requestRefresh()
        XCTAssertEqual(viewModel.state.acceptedRefreshCount, 1)
        XCTAssertEqual(viewModel.state.shieldedRefreshCount, 2)
    }

    func testReselectingDebounceResetsCounters() {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectAssetState(.debounce)
        viewModel.requestRefresh()
        viewModel.requestRefresh()

        viewModel.selectAssetState(.debounce)

        XCTAssertEqual(viewModel.state.acceptedRefreshCount, 0)
        XCTAssertEqual(viewModel.state.shieldedRefreshCount, 0)
    }

    func testDebounceWindowReopensAfterRefreshWindow() async throws {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectAssetState(.debounce)
        viewModel.requestRefresh()

        try await Task.sleep(nanoseconds: UInt64((DeliveryGuardViewModel.refreshWindow + 0.15) * 1_000_000_000))
        viewModel.requestRefresh()

        XCTAssertEqual(viewModel.state.acceptedRefreshCount, 2)
        XCTAssertEqual(viewModel.state.shieldedRefreshCount, 0)
    }

    func testRetryMovesFromErrorThroughLoadingBackToLoaded() async throws {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectAssetState(.error)
        XCTAssertEqual(viewModel.state.assetState, .error)

        viewModel.retryAsset()
        XCTAssertEqual(viewModel.state.assetState, .loading)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(viewModel.state.assetState, .loaded)
    }

    func testSelectingErrorWithoutRetryKeepsErrorState() {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectAssetState(.error)
        viewModel.selectAssetState(.extreme)

        XCTAssertEqual(viewModel.state.assetState, .extreme)
        XCTAssertEqual(viewModel.state.assetState.snapshotDiff, 0.34, accuracy: 0.0001)
    }

    func testSelectingAnotherStateDuringRetryCancelsPendingTransition() async throws {
        let viewModel = DeliveryGuardViewModel()
        viewModel.selectAssetState(.error)
        viewModel.retryAsset()
        XCTAssertEqual(viewModel.state.assetState, .loading)

        // 在 retry 的 0.75s 窗口内切换状态，旧回调不得把界面回退到 loaded。
        viewModel.selectAssetState(.extreme)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(viewModel.state.assetState, .extreme)
    }
}
