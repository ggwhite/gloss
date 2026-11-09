import CoreServices
import Foundation

/// Calls `onChange` when files under a folder change (FSEvents), coalesced over one second.
final class VaultWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) { self.onChange = onChange }

    func watch(_ url: URL) {
        stop()
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let me = Unmanaged<VaultWatcher>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { me.onChange() }
        }
        guard let s = FSEventStreamCreate(kCFAllocatorDefault, cb, &ctx, [url.path] as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0,
                                          FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer))
        else { return }
        FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
        FSEventStreamStart(s)
        stream = s
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}
