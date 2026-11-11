import Foundation
import QuartzCore
import UIKit

/// Watches the main run loop with a CADisplayLink and reports frame gaps.
///
/// Why not a timer? A display link is the same cadence the render server uses,
/// so `timestamp` deltas are a credible proxy for dropped frames. The monitor
/// deliberately publishes only hitch-sized gaps to avoid flooding SwiftUI.
@MainActor
final class HitchMonitor: NSObject, ObservableObject {
    @Published private(set) var worstHitchMs: Double = 0
    @Published private(set) var hitchCount: Int = 0
    @Published private(set) var estimatedDroppedFrames: Int = 0
    @Published private(set) var lastGapMs: Double = 0
    @Published private(set) var samples: [Double] = []

    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval?
    private let hitchThresholdMs: Double = 34

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
        previousTimestamp = nil
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        previousTimestamp = nil
    }

    func reset() {
        worstHitchMs = 0
        hitchCount = 0
        estimatedDroppedFrames = 0
        lastGapMs = 0
        samples = []
    }

    @objc
    private func step(_ link: CADisplayLink) {
        defer { previousTimestamp = link.timestamp }
        guard let previous = previousTimestamp else { return }
        let gapMs = (link.timestamp - previous) * 1000
        guard gapMs >= hitchThresholdMs else { return }

        lastGapMs = gapMs
        worstHitchMs = max(worstHitchMs, gapMs)
        hitchCount += 1
        // A 60Hz frame budget is 16.67ms. This is an estimate, clearly labelled
        // as such in the UI rather than pretending to be an exact Instruments
        // frame-drop count.
        estimatedDroppedFrames += max(1, Int(gapMs / 16.67) - 1)
        samples.append(gapMs)
        if samples.count > 64 {
            samples.removeFirst(samples.count - 64)
        }
    }
}
