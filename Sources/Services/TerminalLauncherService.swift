import Foundation
import AppKit

/// Launches Gemini CLI sessions in the user's chosen terminal emulator.
/// Each terminal has its own launch mechanism (direct launch, AppleScript, etc).
///
/// Important: All launchers use login shells (`zsh -l`) so the user's PATH
/// is loaded (e.g. /opt/homebrew/bin where gemini is typically installed).
enum TerminalLauncherService {

    /// Open a session's project in the specified terminal and run gemini --resume latest
    static func openSession(_ session: GeminiSession, terminal: TerminalEmulator) {
        let command = "gemini --resume latest"
        Log.terminal.info("Resuming '\(session.displayTopic)' in \(terminal.displayName) at \(session.projectRoot)")
        launch(path: session.projectRoot, command: command, terminal: terminal)
    }

    /// Open a fresh gemini session in the user's home directory (or a given path)
    static func openNewSession(path: String? = nil, terminal: TerminalEmulator) {
        let dir = path ?? FileManager.default.homeDirectoryForCurrentUser.path
        let command = "gemini"
        Log.terminal.info("New session in \(terminal.displayName) at \(dir)")
        launch(path: dir, command: command, terminal: terminal)
    }

    /// Core launch: open terminal at path, run command
    private static func launch(path: String, command: String, terminal: TerminalEmulator) {
        switch terminal {
        case .ghostty:    launchGhostty(path: path, command: command)
        case .iterm2:     launchITerm2(path: path, command: command)
        case .terminal:   launchTerminalApp(path: path, command: command)
        case .warp:       launchWarp(path: path, command: command)
        case .kitty:      launchKitty(path: path, command: command)
        case .alacritty:  launchAlacritty(path: path, command: command)
        }
    }

    // MARK: - Terminal-Specific Launchers

    /// Ghostty: use `open -na` with --working-directory and --command config keys.
    private static func launchGhostty(path: String, command: String) {
        runProcess("/usr/bin/open", arguments: [
            "-na", "Ghostty.app", "--args",
            "--working-directory=\(path)",
            "--command=zsh -lc '\(command); exec zsh'"
        ])
    }

    /// iTerm2: AppleScript to create a new window and run the command
    private static func launchITerm2(path: String, command: String) {
        let escaped = escapePath(path)
        let script = """
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "cd '\(escaped)' && \(command)"
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Terminal.app: AppleScript to open a new window with the command
    private static func launchTerminalApp(path: String, command: String) {
        let escaped = escapePath(path)
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escaped)' && \(command)"
        end tell
        """
        runAppleScript(script)
    }

    /// Warp: AppleScript via System Events to type the command
    private static func launchWarp(path: String, command: String) {
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
                keystroke "cd '\(escaped)' && \(command)"
                key code 36
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Kitty: direct binary launch with --directory flag
    private static func launchKitty(path: String, command: String) {
        runProcess("/Applications/kitty.app/Contents/MacOS/kitty", arguments: [
            "--directory", path,
            "zsh", "-lc", "\(command); exec zsh"
        ])
    }

    /// Alacritty: direct binary launch with --working-directory flag
    private static func launchAlacritty(path: String, command: String) {
        runProcess("/Applications/Alacritty.app/Contents/MacOS/alacritty", arguments: [
            "--working-directory", path,
            "-e", "zsh", "-lc", "\(command); exec zsh"
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
