import Darwin
import Foundation

/// Deliberate crash primitives used by Module 2.
///
/// These functions are *supposed* to terminate the process. They exist so an
/// interviewer can watch a real `EXC_BAD_ACCESS` arrive in Xcode, then compare
/// the "system-library-only" stack with the source-level explanation.
///
/// Safety: nothing here runs at launch; it only fires after an explicit,
/// confirmed tap on a scenario screen.
enum CrashProbe {
    /// A stable UAF-shaped crash.
    ///
    /// A timer callback owns a dangling pointer and writes through it with
    /// `memcpy`. Using `0x1d` as the fault address makes the exception
    /// subcode deterministic (`KERN_INVALID_ADDRESS at 0x...1d`) instead of
    /// depending on whatever the allocator happened to reuse. The crash still
    /// lands inside libsystem/libdispatch, so the debugger stack looks like the
    /// classic black-box system crash.
    static func armSystemStackUseAfterFree() -> DispatchSourceTimer {
        let source = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        source.schedule(deadline: .now() + 0.5, leeway: .milliseconds(40))

        source.setEventHandler {
            // The "released" object's address survived in a callback context.
            // 0x1d is never a valid user-space mapping on iOS.
            let dangling = UnsafeMutableRawPointer(bitPattern: 0x1d)!
            let payload = [UInt8](repeating: 0x41, count: 64)
            payload.withUnsafeBytes { buffer in
                _ = memcpy(dangling, buffer.baseAddress, buffer.count)
            }
        }

        source.resume()
        return source
    }

    /// Concurrent wild-pointer stomp. Several global-queue workers keep
    /// writing into a region after it has been unmapped. The first store after
    /// `munmap` traps; the others make the timing feel "intermittent".
    static func triggerConcurrentStomp() {
        let bytes = 16_384
        guard let region = mmap(nil, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0) else {
            return
        }
        memset(region, 0x41, bytes)
        munmap(region, bytes)

        for worker in 0..<8 {
            DispatchQueue.global(qos: .userInitiated).async {
                for step in 0..<1_000_000 {
                    region.storeBytes(
                        of: UInt64(step &+ worker),
                        toByteOffset: (step & 0x3F) * 8,
                        as: UInt64.self
                    )
                }
            }
        }
    }

    /// The crash report an MCP-driven debugger session typically normalizes
    /// down to. This is illustrative text, not a parsed real report.
    static let expectedSystemStackReport = """
    Incident Identifier:  DEMO-2.1-UAF
    Exception Type:      EXC_BAD_ACCESS (SIGSEGV)
    Exception Codes:     KERN_INVALID_ADDRESS at 0x000000000000001d
    Exception Subcode:   0x000000000000001d
    Termination Reason:  Namespace SIGNAL, Code 11 Segmentation fault: 11
    Crashed Thread:      3  com.apple.root.user-initiated-qos

    Thread 3 Crashed:
    0   libsystem_platform.dylib   _platform_memmove + 176
    1   libsystem_platform.dylib   _platform_memmove
    2   libdispatch.dylib          _dispatch_client_callout + 16
    3   libdispatch.dylib          _dispatch_source_invoke + 1620
    4   libdispatch.dylib          _dispatch_lane_serial_drain + 740
    5   libdispatch.dylib          _dispatch_lane_invoke + 420
    6   libdispatch.dylib          _dispatch_root_queue_drain + 392
    7   libdispatch.dylib          _dispatch_worker_thread2 + 156
    8   libsystem_pthread.dylib    _pthread_wqthread + 228

    Filters: (system frames dominate; the closure appears only after
    "Hide System Libraries" is turned OFF)
    """
}
