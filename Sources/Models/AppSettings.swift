import Foundation
import SwiftUI
import ServiceManagement

/// Manages persistent app settings stored in ~/.gemini-opener/config.json.
/// Published properties drive UI updates via SwiftUI observation.
class AppSettings: ObservableObject {
    @Published var selectedTerminal: TerminalEmulator {
        didSet { save() }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            updateLaunchAtLogin()
            save()
        }
    }

    private static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".gemini-opener")
    private static let configFile = configDir.appendingPathComponent("config.json")

    init() {
        // Load saved settings or use defaults
        let loaded = AppSettings.loadFromDisk()
        self.selectedTerminal = loaded.terminal
        self.launchAtLogin = loaded.launchAtLogin
        Log.settings.info("Settings loaded: terminal=\(loaded.terminal.rawValue), launchAtLogin=\(loaded.launchAtLogin)")
    }

    // MARK: - Persistence

    private struct StoredSettings: Codable {
        var selectedTerminal: TerminalEmulator
        var launchAtLogin: Bool
    }

    private func save() {
        let stored = StoredSettings(
            selectedTerminal: selectedTerminal,
            launchAtLogin: launchAtLogin
        )
        do {
            try FileManager.default.createDirectory(
                at: AppSettings.configDir,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(stored)
            try data.write(to: AppSettings.configFile)
            Log.settings.debug("Settings saved")
        } catch {
            Log.settings.error("Failed to save settings: \(error.localizedDescription)")
        }
    }

    private static func loadFromDisk() -> (terminal: TerminalEmulator, launchAtLogin: Bool) {
        guard let data = try? Data(contentsOf: configFile),
              let stored = try? JSONDecoder().decode(StoredSettings.self, from: data) else {
            return (.ghostty, false)
        }
        return (stored.selectedTerminal, stored.launchAtLogin)
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                    Log.settings.info("Registered for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    Log.settings.info("Unregistered from launch at login")
                }
            } catch {
                Log.settings.error("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }
}
