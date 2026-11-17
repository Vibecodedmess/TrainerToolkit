import SwiftUI
import UIKit

extension View {
    /// Gives a screen the current look's background (black, or the alien scene). Put it on every
    /// screen, next to its `.navigationTitle`. Fonts, colours and the navigation bar are set for
    /// the whole app in `RootTabView`.
    func lookScreen() -> some View {
        modifier(LookScreenModifier())
    }
}

private struct LookScreenModifier: ViewModifier {
    @AppStorage(AppLook.storageKey) private var look: AppLook = .standard

    @ViewBuilder
    func body(content: Content) -> some View {
        switch look {
        case .terminal:
            content
                .scrollContentBackground(.hidden)
                .background { Color.black.ignoresSafeArea() }
        case .alien:
            content
                .scrollContentBackground(.hidden)
                .background { AlienBackground() }
        case .alienTerminal:
            content
                .scrollContentBackground(.hidden)
                .background { AlienBackground(dimmed: true) }
        case .standard, .dock, .widgets, .timeline:
            content
        }
    }
}

/// The navigation bar for each look. SwiftUI has no app-wide way to set the bar's title font, so
/// this sets UIKit's appearance. Bars made afterwards use it; `RootTabView` rebuilds the tabs
/// when the look changes, so every bar picks it up.
@MainActor
enum LookAppearance {
    static func apply(_ look: AppLook) {
        let proxy = UINavigationBar.appearance()
        let bar = UINavigationBarAppearance()
        switch look {
        case .terminal, .alienTerminal:
            let green = UIColor(TerminalStyle.green)
            bar.configureWithOpaqueBackground()
            bar.backgroundColor = look == .terminal ? .black : UIColor.black.withAlphaComponent(0.85)
            bar.shadowColor = green.withAlphaComponent(0.3)
            bar.titleTextAttributes = [.foregroundColor: green,
                                       .font: scaled(UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold), .headline)]
            bar.largeTitleTextAttributes = [.foregroundColor: green,
                                            .font: scaled(UIFont.monospacedSystemFont(ofSize: 30, weight: .bold), .largeTitle)]
        case .alien:
            let ink = UIColor(Chunky.ink)
            bar.configureWithOpaqueBackground()
            bar.backgroundColor = UIColor(Chunky.lime)
            bar.shadowColor = ink
            bar.titleTextAttributes = [.foregroundColor: ink, .font: scaled(rounded(17, .heavy), .headline)]
            bar.largeTitleTextAttributes = [.foregroundColor: ink, .font: scaled(rounded(34, .black), .largeTitle)]
        case .standard, .dock, .widgets, .timeline:
            // The system's own bar: default background, see-through at the top of a list.
            bar.configureWithDefaultBackground()
            proxy.standardAppearance = bar
            proxy.compactAppearance = nil
            proxy.scrollEdgeAppearance = nil
            return
        }
        proxy.standardAppearance = bar
        proxy.compactAppearance = bar
        proxy.scrollEdgeAppearance = bar
    }

    /// Follows Dynamic Type like the system's own title fonts.
    private static func scaled(_ font: UIFont, _ style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }

    private static func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
