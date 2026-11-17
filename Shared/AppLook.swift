import SwiftUI

/// The app's look, picked in More > Looks. A display preference, so it isn't in backups.
enum AppLook: String, CaseIterable, Identifiable {
    /// The list-style Home and the system tab bar (Phase 16).
    case standard
    /// Greeting, big Community Day countdown, round quick buttons and a floating tab capsule.
    case dock
    /// Home as mixed-size widgets.
    case widgets
    /// Home as one "what's next" timeline with a scan button.
    case timeline
    /// Home as a command line, a terminal tab bar, dark mode and green highlights.
    case terminal
    /// Chunky game-style Home over a moving alien space scene.
    case alien
    /// The terminal over the moving alien scene.
    case alienTerminal

    static let storageKey = "app.look"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: "Standard"
        case .dock: "Floating dock"
        case .widgets: "Widget board"
        case .timeline: "Timeline"
        case .terminal: "Terminal"
        case .alien: "Alien signal"
        case .alienTerminal: "Terminal, alien edition"
        }
    }

    var summary: String {
        switch self {
        case .standard: "The list-style Home and the usual tab bar."
        case .dock: "A greeting, a big Community Day countdown, round quick buttons and a floating tab bar on every screen."
        case .widgets: "Home as widgets in mixed sizes, like an iPhone home screen, and rounded text throughout."
        case .timeline: "Home as one timeline of what's on now and next, with a button to add from screenshots."
        case .terminal: "Every screen in black and green with monospaced text, Home as a command line and a terminal tab bar."
        case .alien: "Every screen over a moving alien space scene, with chunky rounded text, a lime title bar and a game-style Home."
        case .alienTerminal: "The terminal look over the moving alien scene, on every screen."
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "list.bullet.rectangle"
        case .dock: "dock.rectangle"
        case .widgets: "square.grid.2x2"
        case .timeline: "timeline.selection"
        case .terminal: "apple.terminal"
        case .alien: "atom"
        case .alienTerminal: "apple.terminal.fill"
        }
    }

    /// Terminal looks: monospaced Home, terminal tab bar, dark mode, green tint.
    var isTerminal: Bool { self == .terminal || self == .alienTerminal }

    // MARK: - App-wide style (applied in RootTabView; backgrounds per screen with `lookScreen()`)

    /// The app-wide tint.
    var tint: Color {
        switch self {
        case .terminal, .alienTerminal: TerminalStyle.green
        case .alien: Chunky.forest
        case .standard, .dock, .widgets, .timeline: AppTheme.accent
        }
    }

    /// Forced appearance, or nil to follow the phone's setting. Alien is light, so lists read as
    /// white stickers over the green scene.
    var colorScheme: ColorScheme? {
        switch self {
        case .terminal, .alienTerminal: .dark
        case .alien: .light
        case .standard, .dock, .widgets, .timeline: nil
        }
    }

    /// The app-wide font design, or nil for the system default.
    var fontDesign: Font.Design? {
        switch self {
        case .terminal, .alienTerminal: .monospaced
        case .alien, .widgets: .rounded
        case .standard, .dock, .timeline: nil
        }
    }

    /// The app-wide font weight, or nil for each text's own weight.
    var fontWeight: Font.Weight? { self == .alien ? .semibold : nil }
}
