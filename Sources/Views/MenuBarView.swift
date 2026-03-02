import SwiftUI

/// Main dropdown panel for the menu bar icon.
/// Uses .window style MenuBarExtra for rich multi-line session rows.
///
/// Each session row shows:
/// 1. Topic (first user message) — wraps to multiple lines
/// 2. Project path
/// 3. Relative time + message count
struct MenuBarView: View {
    @EnvironmentObject var dataService: GeminiDataService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var terminalDetection: TerminalDetectionService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Gemini Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { dataService.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Session list
            if dataService.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Divider()

            // Footer: Settings + Quit
            HStack {
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(dataService.sessions) { session in
                    SessionRowView(session: session) {
                        openSession(session)
                    }
                    if session.id != dataService.sessions.last?.id {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 420)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No Gemini CLI sessions found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Start a Gemini CLI session to see it here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    private func openSession(_ session: GeminiSession) {
        let terminal = terminalDetection.resolveTerminal(appSettings.selectedTerminal)
        TerminalLauncherService.openSession(session, terminal: terminal)
    }
}

// MARK: - Session Row

/// Individual session row with multi-line layout:
/// - Topic (first user message, wraps naturally)
/// - Project path
/// - Relative time + message count
struct SessionRowView: View {
    let session: GeminiSession
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                // Line 1: Topic — wraps to show full context
                Text(session.displayTopic)
                    .font(.body)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.primary)

                // Line 2: Project path
                Text(session.shortPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Line 3: Relative time + message count
                HStack(spacing: 6) {
                    Label(session.relativeTimeString, systemImage: "clock")
                    Text("·")
                    Label(
                        "\(session.messageCount) message\(session.messageCount == 1 ? "" : "s")",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
