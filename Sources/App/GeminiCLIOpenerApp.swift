import SwiftUI

/// Main app entry point - runs as a menu bar-only application (no dock icon).
/// Uses MenuBarExtra with .window style for rich multi-line session rows.
@main
struct GeminiCLIOpenerApp: App {
    @StateObject private var dataService = GeminiDataService()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var terminalDetection = TerminalDetectionService()

    /// File system watcher for live updates when sessions change
    @State private var fileWatcher: FileWatcherService?

    var body: some Scene {
        // Menu bar dropdown — .window style gives us full SwiftUI layout
        MenuBarExtra("Gemini CLI Opener", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(dataService)
                .environmentObject(appSettings)
                .environmentObject(terminalDetection)
                .onAppear {
                    startFileWatcher()
                }
        }
        .menuBarExtraStyle(.window)

        // Settings window (opened via menu item)
        Settings {
            SettingsView()
                .environmentObject(appSettings)
                .environmentObject(terminalDetection)
        }
    }

    /// Start watching ~/.gemini/tmp/ for session file changes
    private func startFileWatcher() {
        guard fileWatcher == nil else { return }
        let watcher = FileWatcherService { [dataService] in
            dataService.refresh()
        }
        watcher.start()
        fileWatcher = watcher
        Log.general.info("App started, file watcher active")
    }
}
