import SwiftUI

/// More > Looks: pick how the app looks. Only the presentation changes, never the data.
struct LooksView: View {
    @AppStorage(AppLook.storageKey) private var look: AppLook = .standard

    var body: some View {
        Form {
            Section {
                ForEach(AppLook.allCases) { option in
                    Button {
                        withAnimation { look = option }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.systemImage)
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.name).foregroundStyle(.primary)
                                Text(option.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            if option == look {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.accent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == look ? .isSelected : [])
                }
            } footer: {
                Text("A look changes the Home screen, and Floating dock also changes the tab bar. Your collection, goals and settings stay the same.")
            }
        }
        .navigationTitle("Looks")
    }
}

#Preview {
    NavigationStack { LooksView() }
}
