import SwiftUI

/// Main dropdown panel for the menu bar icon.
/// Uses .window style MenuBarExtra for rich multi-line session rows.
struct MenuBarView: View {
    @EnvironmentObject var dataService: GeminiDataService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var terminalDetection: TerminalDetectionService
    @EnvironmentObject var quotaService: QuotaService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Gemini Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { newSession() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("New Gemini session")

                Button(action: { dataService.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Quota section
            QuotaView()
                .environmentObject(quotaService)

            Divider()

            // Session list
            if dataService.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Divider()

            // Footer
            HStack(spacing: 8) {
                Button(action: {
                    SettingsWindowService.shared.open(
                        appSettings: appSettings,
                        terminalDetection: terminalDetection
                    )
                }) {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(dataService.sessions) { session in
                    SessionRowView(session: session) {
                        openSession(session)
                    }
                }
            }
            .padding(.vertical, 4)
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

    private func newSession() {
        let terminal = terminalDetection.resolveTerminal(appSettings.selectedTerminal)
        TerminalLauncherService.openNewSession(terminal: terminal)
    }
}

// MARK: - Session Row

/// Individual session row styled as a clickable card.
struct SessionRowView: View {
    let session: GeminiSession
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Topic
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var backgroundColor: Color {
        if isPressed {
            return Color.accentColor.opacity(0.2)
        } else if isHovering {
            return Color.primary.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}
