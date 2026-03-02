import Foundation
import AppKit

/// Launches Gemini CLI sessions in the user's chosen terminal emulator.
/// Each terminal has its own launch mechanism (direct launch, AppleScript, etc).
///
/// Important: All launchers use login shells (`zsh -l`) so the user's PATH
/// is loaded (e.g. /opt/homebrew/bin where gemini is typically installed).
enum TerminalLauncherService {

    /// The command to resume the latest Gemini CLI session
    private static let geminiCommand = "gemini --resume latest"

    /// Open a session's project in the specified terminal and run gemini --resume latest
    static func openSession(_ session: GeminiSession, terminal: TerminalEmulator) {
        let path = session.projectRoot
        Log.terminal.info("Launching '\(session.displayTopic)' in \(terminal.displayName) at \(path)")

        switch terminal {
        case .ghostty:    launchGhostty(path: path)
        case .iterm2:     launchITerm2(path: path)
        case .terminal:   launchTerminalApp(path: path)
        case .warp:       launchWarp(path: path)
        case .kitty:      launchKitty(path: path)
        case .alacritty:  launchAlacritty(path: path)
        }
    }

    // MARK: - Terminal-Specific Launchers

    /// Ghostty: use `open -na` with --working-directory and --command config keys.
    /// The -e flag doesn't work through `open`, so we use --command instead.
    private static func launchGhostty(path: String) {
        runProcess("/usr/bin/open", arguments: [
            "-na", "Ghostty.app", "--args",
            "--working-directory=\(path)",
            "--command=zsh -lc '\(geminiCommand); exec zsh'"
        ])
    }

    /// iTerm2: AppleScript to create a new window and run the command
    private static func launchITerm2(path: String) {
        let escaped = escapePath(path)
        let script = """
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "cd '\(escaped)' && \(geminiCommand)"
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Terminal.app: AppleScript to open a new window with the command
    private static func launchTerminalApp(path: String) {
        let escaped = escapePath(path)
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escaped)' && \(geminiCommand)"
        end tell
        """
        runAppleScript(script)
    }

    /// Warp: AppleScript via System Events to type the command
    private static func launchWarp(path: String) {
        let escaped = escapePath(path)
        let script = """
        tell application "Warp"
            activate
        end tell
        delay 0.5
        tell application "System Events"
            tell process "Warp"
                keystroke "t" using command down
                delay 0.3
                keystroke "cd '\(escaped)' && \(geminiCommand)"
                key code 36
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Kitty: direct binary launch with --directory flag
    private static func launchKitty(path: String) {
        runProcess("/Applications/kitty.app/Contents/MacOS/kitty", arguments: [
            "--directory", path,
            "zsh", "-lc", "\(geminiCommand); exec zsh"
        ])
    }

    /// Alacritty: direct binary launch with --working-directory flag
    private static func launchAlacritty(path: String) {
        runProcess("/Applications/Alacritty.app/Contents/MacOS/alacritty", arguments: [
            "--working-directory", path,
            "-e", "zsh", "-lc", "\(geminiCommand); exec zsh"
        ])
    }

    // MARK: - Helpers

    /// Escape single quotes in paths for shell/AppleScript embedding
    private static func escapePath(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    /// Run an external process asynchronously
    private static func runProcess(_ launchPath: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        // Capture stderr so we can log failures
        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
            Log.terminal.debug("Launched: \(launchPath) \(arguments.joined(separator: " "))")

            // Log any stderr output asynchronously
            DispatchQueue.global().async {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
                    Log.terminal.warning("Process stderr: \(errorStr)")
                }
            }
        } catch {
            Log.terminal.error("Failed to launch: \(error.localizedDescription)")
        }
    }

    /// Run an AppleScript string
    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else {
            Log.terminal.error("Failed to create AppleScript")
            return
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            Log.terminal.error("AppleScript error: \(error)")
        }
    }
}
