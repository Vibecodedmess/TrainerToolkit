import SwiftUI
import UIKit

/// The tabs for looks with their own tab bar (Floating dock, Terminal, Alien signal): the five tab
/// screens with `bar` at the bottom instead of the system tab bar.
///
/// All five screens stay alive (only the selected one is shown), so each keeps its place and
/// navigation when you switch, like a normal tab bar. A custom container is used instead of hiding
/// the system tab bar, because a hidden tab bar comes back on pushed screens.
///
/// The bar sits *below* the screens, not over them: a bottom safe-area inset doesn't reach lists
/// inside a NavigationStack, so on build #32 the bar covered the bottom of every list.
struct CustomTabView<Bar: View>: View {
    @Binding var selection: AppTab
    @ViewBuilder var bar: Bar
    @State private var keyboardShown = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    let active = tab == selection
                    tab.root
                        .opacity(active ? 1 : 0)
                        .allowsHitTesting(active)
                        .accessibilityHidden(!active)
                        .environment(\.isActiveTab, active)
                }
            }
            // Hidden while typing, so it doesn't ride up on top of the keyboard.
            if !keyboardShown {
                bar.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardShown = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardShown = false }
        }
    }
}

private struct IsActiveTabKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False while `CustomTabView` keeps a tab's screen alive but hidden (for pausing animations).
    var isActiveTab: Bool {
        get { self[IsActiveTabKey.self] }
        set { self[IsActiveTabKey.self] = newValue }
    }
}

/// The floating tab capsule: icons, with the selected tab shown as an accent pill with its name.
struct FloatingDock: View {
    @Binding var selection: AppTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                button(for: tab)
            }
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
        // The strip the capsule floats on, down to the bottom edge; matches grouped lists.
        .background(Color(.systemGroupedBackground))
        // Big enough to read, small enough that five tabs still fit in one row.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private func button(for tab: AppTab) -> some View {
        let active = tab == selection
        return Button {
            withAnimation(.snappy(duration: 0.25)) { selection = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.body.weight(.semibold))
                if active {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(active ? Color.white : Color.secondary)
            .padding(.horizontal, active ? 14 : 8)
            .frame(maxWidth: active ? nil : .infinity, minHeight: 42)
            .background {
                if active {
                    Capsule()
                        .fill(AppTheme.accent)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview {
    CustomTabView(selection: .constant(.home)) {
        FloatingDock(selection: .constant(.home))
    }
    .environment(DataCenter())
}
