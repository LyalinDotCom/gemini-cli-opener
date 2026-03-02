# Gemini CLI Opener

A lightweight macOS menu bar app that gives you one-click access to your recent Gemini CLI sessions. No more opening terminals and typing `gemini --resume latest` — just click a session in your menu bar.

## Features

- **Session-centric menu** — Shows recent sessions by topic (what you were asking about), not just folder names
- **One-click resume** — Click a session to open your terminal at the project dir and run `gemini --resume latest`
- **Live updates** — Watches `~/.gemini/tmp/` via FSEvents and updates the menu automatically
- **Multi-terminal support** — Ghostty, iTerm2, Terminal.app, Warp, Kitty, Alacritty
- **No dock icon** — Runs as a lightweight menu bar-only app (LSUIElement)
- **Launch at login** — Optional auto-start via macOS SMAppService

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+ / Xcode 15+
- Gemini CLI installed with existing sessions

## Build & Run

```bash
cd gemini-cli-opener
swift build
swift run

# Or run the built binary directly
.build/debug/GeminiCLIOpener
```

### Release Build

```bash
swift build -c release
# Binary at: .build/release/GeminiCLIOpener
```

## How It Works

The app reads data Gemini CLI already stores on disk — no modifications needed:

| File | Purpose |
|------|---------|
| `~/.gemini/projects.json` | Maps project paths to slugs |
| `~/.gemini/tmp/<slug>/chats/session-*.json` | Session files with timestamps and messages |
| `~/.gemini/tmp/<slug>/.project_root` | Confirms absolute project path |

The menu shows **individual sessions** sorted by recency. Each row displays:
- **Topic** — First user message from the session (the most descriptive content)
- **Project name** + shortened path + relative time as context

Timestamps are extracted from filenames for fast sorting. Only sessions with actual content (>1 message) are shown. Capped at 5 sessions per project, 20 total.

## Configuration

Settings stored in `~/.gemini-opener/config.json`:

- **Terminal** — Which terminal emulator opens sessions (default: Ghostty)
- **Launch at login** — Auto-start when you log in

Access via menu bar dropdown → "Settings..."

## Supported Terminals

| Terminal | Launch Method |
|----------|--------------|
| Ghostty | `open -na Ghostty.app --args --working-directory=...` |
| iTerm2 | AppleScript (create window + write text) |
| Terminal.app | AppleScript (do script) |
| Warp | AppleScript via System Events |
| Kitty | Direct binary with `--directory` flag |
| Alacritty | Direct binary with `--working-directory` flag |

Falls back to Terminal.app if the selected terminal isn't installed.

## Project Structure

```
Sources/
  App/
    GeminiCLIOpenerApp.swift         # @main, MenuBarExtra + Settings scene + FileWatcher
  Models/
    GeminiProject.swift              # GeminiSession model (topic, project, timestamp)
    TerminalEmulator.swift           # Supported terminal enum with app paths
    AppSettings.swift                # Persistent settings in ~/.gemini-opener/config.json
  Services/
    GeminiDataService.swift          # Reads ~/.gemini/ data, builds flat session list
    TerminalLauncherService.swift    # Opens terminal with cd + gemini --resume latest
    TerminalDetectionService.swift   # Scans /Applications/ for installed terminals
    FileWatcherService.swift         # FSEvents watcher with 1s debounce
  Views/
    MenuBarView.swift                # Dropdown: session list + settings/quit
    SettingsView.swift               # Terminal picker, launch-at-login toggle
  Utilities/
    Logger.swift                     # os.Logger wrapper (subsystem: com.gemini-cli-opener)
```

## Debugging

View logs in Console.app — filter for subsystem `com.gemini-cli-opener`. Categories:
- `data` — Session loading and parsing
- `terminal` — Terminal launch commands
- `filewatcher` — File system change detection
- `settings` — Settings load/save
