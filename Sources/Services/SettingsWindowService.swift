import SwiftUI
import AppKit

/// Manages the Settings window lifecycle for a menu bar-only app.
/// The SwiftUI `Settings` scene doesn't work reliably with LSUIElement apps,
/// so we create and manage the NSWindow ourselves.
class SettingsWindowService {
    static let shared = SettingsWindowService()

    private var window: NSWindow?

    /// Show the settings window, creating it if needed. Brings it to front.
    func open(appSettings: AppSettings, terminalDetection: TerminalDetectionService) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(appSettings)
            .environmentObject(terminalDetection)

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Gemini CLI Opener Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 380, height: 240))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Log.settings.info("Settings window opened")
    }
}
