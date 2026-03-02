import SwiftUI

/// Settings window for configuring terminal preference and launch-at-login.
/// Opened via the "Settings..." menu item.
struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var terminalDetection: TerminalDetectionService

    var body: some View {
        Form {
            // Terminal selection
            Section("Terminal") {
                Picker("Open sessions in:", selection: $appSettings.selectedTerminal) {
                    ForEach(terminalDetection.installedTerminals) { terminal in
                        Text(terminal.displayName).tag(terminal)
                    }
                }
                .pickerStyle(.menu)

                if !terminalDetection.isInstalled(appSettings.selectedTerminal) {
                    Label(
                        "\(appSettings.selectedTerminal.displayName) not found. Will use Terminal.app as fallback.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundColor(.orange)
                    .font(.caption)
                }
            }

            // General settings
            Section("General") {
                Toggle("Launch at login", isOn: $appSettings.launchAtLogin)
            }

            // About
            Section("About") {
                HStack {
                    Text("Gemini CLI Opener")
                    Spacer()
                    Text("v1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 220)
        .fixedSize()
    }
}
