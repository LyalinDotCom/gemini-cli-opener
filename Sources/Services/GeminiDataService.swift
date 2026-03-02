import Foundation
import SwiftUI

/// Reads Gemini CLI session data from ~/.gemini/ and builds a flat, time-sorted list of sessions.
///
/// Data flow:
/// 1. Parse ~/.gemini/projects.json for project path → slug mappings
/// 2. For each slug, scan ~/.gemini/tmp/<slug>/chats/ for session files
/// 3. Parse each session to extract the topic (first user message)
/// 4. Return all sessions sorted by timestamp, newest first
///
/// Sessions are the primary items — not projects. Each row in the menu represents
/// a conversation you had, identified by what you asked about.
class GeminiDataService: ObservableObject {
    @Published var sessions: [GeminiSession] = []

    private let geminiDir: URL
    private let tmpDir: URL

    /// Max number of sessions to show per project (avoids flooding the menu)
    private let maxSessionsPerProject = 5

    /// Max total sessions in the menu
    private let maxTotalSessions = 20

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.geminiDir = home.appendingPathComponent(".gemini")
        self.tmpDir = geminiDir.appendingPathComponent("tmp")
        refresh()
    }

    /// Reload all session data from disk
    func refresh() {
        Log.data.info("Refreshing session data...")
        let newSessions = loadAllSessions()
        DispatchQueue.main.async {
            self.sessions = newSessions
            Log.data.info("Loaded \(newSessions.count) sessions")
        }
    }

    // MARK: - Data Loading

    /// Load sessions from all known projects, sorted by time
    private func loadAllSessions() -> [GeminiSession] {
        let projectMappings = loadProjectMappings()
        if projectMappings.isEmpty {
            Log.data.warning("No project mappings found in projects.json")
            return []
        }

        var allSessions: [GeminiSession] = []

        for (path, slug) in projectMappings {
            let projectRoot = resolveProjectRoot(slug: slug, fallback: path)
            let sessions = loadSessionsForProject(slug: slug, projectRoot: projectRoot)
            allSessions.append(contentsOf: sessions)
        }

        // Sort all sessions by timestamp (newest first) and cap total count
        allSessions.sort { $0.timestamp > $1.timestamp }
        return Array(allSessions.prefix(maxTotalSessions))
    }

    /// Parse ~/.gemini/projects.json → [(path, slug)]
    private func loadProjectMappings() -> [(path: String, slug: String)] {
        let projectsFile = geminiDir.appendingPathComponent("projects.json")

        guard let data = try? Data(contentsOf: projectsFile) else {
            Log.data.error("Cannot read projects.json")
            return []
        }

        // Structure: {"projects": {"/path": "slug"}}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: String] else {
            Log.data.error("Invalid projects.json format")
            return []
        }

        return projects.map { (path: $0.key, slug: $0.value) }
    }

    /// Load individual sessions for a project, up to maxSessionsPerProject
    private func loadSessionsForProject(slug: String, projectRoot: String) -> [GeminiSession] {
        let chatsDir = tmpDir.appendingPathComponent(slug).appendingPathComponent("chats")
        let sessionFiles = findSessionFiles(in: chatsDir)

        var results: [GeminiSession] = []
        for (url, date) in sessionFiles.prefix(maxSessionsPerProject) {
            let (topic, messageCount) = extractSessionInfo(from: url)

            // Skip sessions with no real content (e.g. just an info message)
            if messageCount < 2 && topic == nil { continue }

            let session = GeminiSession(
                id: "\(slug)/\(url.lastPathComponent)",
                slug: slug,
                projectRoot: projectRoot,
                timestamp: date,
                topic: topic,
                messageCount: messageCount
            )
            results.append(session)
        }

        return results
    }

    /// Find session files sorted by timestamp (newest first).
    /// Extracts date from filename for fast sorting without parsing JSON.
    private func findSessionFiles(in chatsDir: URL) -> [(url: URL, date: Date)] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: chatsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        var sessions: [(url: URL, date: Date)] = []
        for file in files where file.lastPathComponent.hasPrefix("session-") {
            if let date = extractDateFromFilename(file.lastPathComponent) {
                sessions.append((url: file, date: date))
            } else if let attrs = try? fm.attributesOfItem(atPath: file.path),
                      let modDate = attrs[.modificationDate] as? Date {
                sessions.append((url: file, date: modDate))
            }
        }

        sessions.sort { $0.date > $1.date }
        return sessions
    }

    /// Extract date from filename like "session-2026-03-02T00-47-1b144551.json"
    private func extractDateFromFilename(_ filename: String) -> Date? {
        let stripped = filename
            .replacingOccurrences(of: "session-", with: "")
            .replacingOccurrences(of: ".json", with: "")

        // Expected: "2026-03-02T00-47-1b144551"
        // Date part: first 16 chars → "2026-03-02T00-47"
        guard stripped.count >= 16 else { return nil }
        let dateStr = String(stripped.prefix(16))

        // Convert "2026-03-02T00-47" → "2026-03-02T00:47:00Z"
        let colonIndex = dateStr.index(dateStr.startIndex, offsetBy: 13)
        let nextIndex = dateStr.index(after: colonIndex)
        let isoStr = String(dateStr[dateStr.startIndex..<colonIndex]) + ":"
            + String(dateStr[nextIndex...]) + ":00Z"

        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoStr)
    }

    /// Read .project_root file to resolve the absolute project path
    private func resolveProjectRoot(slug: String, fallback: String) -> String {
        let rootFile = tmpDir.appendingPathComponent(slug).appendingPathComponent(".project_root")
        if let content = try? String(contentsOf: rootFile, encoding: .utf8) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return fallback
    }

    /// Extract the topic (first user message) and message count from a session file
    private func extractSessionInfo(from sessionURL: URL) -> (topic: String?, messageCount: Int) {
        guard let data = try? Data(contentsOf: sessionURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return (nil, 0)
        }

        // Find first user message as the topic
        var topic: String?
        for message in messages {
            if message["type"] as? String == "user",
               let content = message["content"] as? String {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                topic = trimmed.count > 120 ? String(trimmed.prefix(120)) + "..." : trimmed
                break
            }
        }

        return (topic, messages.count)
    }
}
