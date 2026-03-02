import Foundation

/// Watches ~/.gemini/tmp/ for file system changes using FSEvents.
/// Debounces rapid changes (1 second) before triggering a refresh callback.
class FileWatcherService {
    private var stream: FSEventStreamRef?
    private let callback: () -> Void
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 1.0

    /// Initialize with a callback that will be called when changes are detected
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    deinit {
        stop()
    }

    /// Start watching ~/.gemini/tmp/ for changes
    func start() {
        let watchPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/tmp")
            .path

        guard FileManager.default.fileExists(atPath: watchPath) else {
            Log.fileWatcher.warning("Watch path does not exist: \(watchPath)")
            return
        }

        let pathsToWatch = [watchPath] as CFArray

        // Context to pass self reference into the C callback
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // Latency in seconds
            flags
        ) else {
            Log.fileWatcher.error("Failed to create FSEvent stream")
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        Log.fileWatcher.info("File watcher started on \(watchPath)")
    }

    /// Stop watching for changes
    func stop() {
        debounceTimer?.invalidate()
        debounceTimer = nil

        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            Log.fileWatcher.info("File watcher stopped")
        }
    }

    /// Called when FSEvents detects changes; debounces before triggering callback
    fileprivate func handleEvent() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debounceTimer?.invalidate()
            self.debounceTimer = Timer.scheduledTimer(
                withTimeInterval: self.debounceInterval,
                repeats: false
            ) { [weak self] _ in
                Log.fileWatcher.debug("Debounce fired, triggering refresh")
                self?.callback()
            }
        }
    }
}

/// FSEvents C callback - bridges to the Swift method
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()
    watcher.handleEvent()
}
