import os

/// Centralized logging using Apple's os.Logger framework.
/// Categories allow filtering in Console.app for debugging.
enum Log {
    static let data = Logger(subsystem: "com.gemini-cli-opener", category: "data")
    static let terminal = Logger(subsystem: "com.gemini-cli-opener", category: "terminal")
    static let fileWatcher = Logger(subsystem: "com.gemini-cli-opener", category: "filewatcher")
    static let settings = Logger(subsystem: "com.gemini-cli-opener", category: "settings")
    static let general = Logger(subsystem: "com.gemini-cli-opener", category: "general")
}
