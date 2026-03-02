import Foundation

/// Represents a single Gemini CLI session — the primary item shown in the menu.
/// Each session has a topic (first user message), a project it belongs to, and a timestamp.
struct GeminiSession: Identifiable, Equatable {
    let id: String           // Unique: slug + session filename
    let slug: String         // Project slug (directory name under ~/.gemini/tmp/)
    let projectRoot: String  // Absolute path to the project directory
    let timestamp: Date      // When this session started/was last active
    let topic: String?       // First user message — the most descriptive content we have
    let messageCount: Int    // Number of messages (indicates how substantial the session was)

    /// Folder name extracted from the project path (e.g. "my-project")
    var projectName: String {
        let name = (projectRoot as NSString).lastPathComponent
        // Home directory shows as "~" instead of the username
        if projectRoot == FileManager.default.homeDirectoryForCurrentUser.path {
            return "~"
        }
        return name
    }

    /// Shortened path for display, replacing home directory with ~
    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if projectRoot == home { return "~" }
        if projectRoot.hasPrefix(home) {
            return "~" + projectRoot.dropFirst(home.count)
        }
        return projectRoot
    }

    /// Human-readable relative time (e.g. "2h ago", "3d ago")
    var relativeTimeString: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }
        if seconds < 2592000 { return "\(seconds / 604800)w ago" }
        return "\(seconds / 2592000)mo ago"
    }

    /// Display-ready topic: the first user message, or a fallback
    var displayTopic: String {
        if let topic = topic, !topic.isEmpty {
            return topic
        }
        return "Session in \(projectName)"
    }

    static func == (lhs: GeminiSession, rhs: GeminiSession) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }
}
