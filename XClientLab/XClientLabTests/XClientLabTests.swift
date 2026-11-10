import XCTest
@testable import XClientLab

final class XClientLabCoreTests: XCTestCase {

    // MARK: - 3.2 Order book

    func testBookFactoryProducesTwelveSortedLevelsPerSide() {
        let snapshot = BookFactory.make(sequence: 17, mid: 42_000)

        XCTAssertEqual(snapshot.bids.count, 12)
        XCTAssertEqual(snapshot.asks.count, 12)
        XCTAssertGreaterThan(snapshot.bestAsk, snapshot.bestBid)
        XCTAssertGreaterThan(snapshot.spread, 0)

        let bidPrices = snapshot.bids.map(\.price)
        XCTAssertEqual(bidPrices, bidPrices.sorted(by: >), "Bids must be best-first (descending)")
        let askPrices = snapshot.asks.map(\.price)
        XCTAssertEqual(askPrices, askPrices.sorted(by: <), "Asks must be best-first (ascending)")
    }

    func testPipelineCoalescesBurstToOnePendingSnapshot() {
        let pipeline = OrderBookPipeline()

        for sequence in 1...200 {
            pipeline.submit(BookFactory.make(sequence: sequence, mid: 42_000))
        }

        let stats = pipeline.stats()
        XCTAssertEqual(stats.submitted, 200)
        XCTAssertEqual(stats.coalesced, 199)

        let latest = pipeline.take()
        XCTAssertEqual(latest?.sequence, 200, "Only the newest full snapshot should survive")
        XCTAssertNil(pipeline.take(), "The slot must be empty after one frame consumes it")
    }

    // MARK: - 3.1 Reconnect policy

    @MainActor
    func testReconnectPolicyConstantsAreBounded() {
        let viewModel = ReconnectViewModel()

        XCTAssertEqual(viewModel.maxRetries, 6)
        XCTAssertEqual(viewModel.baseDelay, 0.5, accuracy: 0.0001)
        XCTAssertEqual(viewModel.maxDelay, 8.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.state, .offline)

        // Mirrors the formula in scheduleRetry: min(8, 0.5 * 2^(n - 1)).
        let expected = (1...6).map { min(8, 0.5 * pow(2, Double($0 - 1))) }
        XCTAssertEqual(expected, [0.5, 1, 2, 4, 8, 8])
    }

    // MARK: - 1.x Payload fixtures

    func testCPUStallPayloadIsValidJSONAndHasExpectedRecordCount() throws {
        let data = CPUStallPayload.makeData(records: 6_000)
        let object = try JSONSerialization.jsonObject(with: data)
        let dictionary = try XCTUnwrap(object as? [String: Any])
        let records = try XCTUnwrap(dictionary["records"] as? [[String: Any]])

        XCTAssertEqual(records.count, 6_000)
        XCTAssertGreaterThan(data.count, 500_000, "Fixture must be large enough to produce a visible stall")
    }

    func testAllocationStormFeedAndChecksumAreDeterministic() {
        let feed = MarketRow.makeFeed(count: 5_000)
        XCTAssertEqual(feed.count, 5_000)
        XCTAssertEqual(feed.first?.id, 0)
        XCTAssertEqual(feed.last?.id, 4_999)
        XCTAssertEqual(AllocationStormEngine.rowChecksum(42), AllocationStormEngine.rowChecksum(42))
    }

    // MARK: - 4.1 Markdown skill parser

    func testMarkdownLiteParserHandlesHeadingsBulletsAndCode() {
        let markdown = """
        # Title

        Intro paragraph.

        ## Steps

        - first
        - second

        ```lldb
        process status
        ```
        """

        let blocks = MarkdownLiteParser.parse(markdown)

        guard case .heading(1, "Title") = blocks.first else {
            return XCTFail("Expected h1 first, got \(String(describing: blocks.first))")
        }
        XCTAssertTrue(blocks.contains { block in
            if case .bullet("first") = block { return true }
            return false
        })
        XCTAssertTrue(blocks.contains { block in
            if case .code("process status") = block { return true }
            return false
        })
    }
}
