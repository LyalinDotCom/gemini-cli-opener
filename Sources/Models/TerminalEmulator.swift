import Foundation

/// Supported terminal emulators for launching Gemini CLI sessions.
/// Each case knows its app name, bundle path, and how to launch commands.
enum TerminalEmulator: String, Codable, CaseIterable, Identifiable {
    case ghostty
    case iterm2
    case terminal   // macOS built-in Terminal.app
    case warp
    case kitty
    case alacritty

    var id: String { rawValue }

    /// Display name shown in the UI
    var displayName: String {
        switch self {
        case .ghostty:    return "Ghostty"
        case .iterm2:     return "iTerm2"
        case .terminal:   return "Terminal"
        case .warp:       return "Warp"
        case .kitty:      return "Kitty"
        case .alacritty:  return "Alacritty"
        }
    }

    /// Path to the .app bundle for detection
    var appPath: String {
        switch self {
        case .ghostty:    return "/Applications/Ghostty.app"
        case .iterm2:     return "/Applications/iTerm.app"
        case .terminal:   return "/System/Applications/Utilities/Terminal.app"
        case .warp:       return "/Applications/Warp.app"
        case .kitty:      return "/Applications/kitty.app"
        case .alacritty:  return "/Applications/Alacritty.app"
        }
    }
}
