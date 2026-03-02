import Foundation
import SwiftUI

/// Detects which terminal emulators are installed on the system.
/// Scans standard app locations for each supported terminal.
class TerminalDetectionService: ObservableObject {
    @Published var installedTerminals: [TerminalEmulator] = []

    init() {
        detectInstalledTerminals()
    }

    /// Scan for installed terminals in /Applications/ and /System/Applications/
    func detectInstalledTerminals() {
        let fm = FileManager.default
        var found: [TerminalEmulator] = []

        for terminal in TerminalEmulator.allCases {
            if fm.fileExists(atPath: terminal.appPath) {
                found.append(terminal)
                Log.terminal.debug("Found terminal: \(terminal.displayName) at \(terminal.appPath)")
            }
        }

        installedTerminals = found
        Log.terminal.info("Detected \(found.count) installed terminals")
    }

    /// Check if a specific terminal is available
    func isInstalled(_ terminal: TerminalEmulator) -> Bool {
        installedTerminals.contains(terminal)
    }

    /// Get the best available terminal: user's choice if installed, otherwise Terminal.app
    func resolveTerminal(_ preferred: TerminalEmulator) -> TerminalEmulator {
        if isInstalled(preferred) { return preferred }
        Log.terminal.warning("\(preferred.displayName) not found, falling back to Terminal.app")
        return .terminal
    }
}
