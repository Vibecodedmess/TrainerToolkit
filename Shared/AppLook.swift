import Foundation

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

    static let storageKey = "app.look"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: "Standard"
        case .dock: "Floating dock"
        case .widgets: "Widget board"
        case .timeline: "Timeline"
        }
    }

    var summary: String {
        switch self {
        case .standard: "The list-style Home and the usual tab bar."
        case .dock: "A greeting, a big Community Day countdown, round quick buttons and a floating tab bar."
        case .widgets: "Home as widgets in mixed sizes, like an iPhone home screen."
        case .timeline: "Home as one timeline of what's on now and next, with a button to add from screenshots."
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "list.bullet.rectangle"
        case .dock: "dock.rectangle"
        case .widgets: "square.grid.2x2"
        case .timeline: "timeline.selection"
        }
    }
}
