import SwiftUI

/// Small, non-blocking warning strip (for example "Raid bosses couldn't update").
struct WarningBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
    }
}

#Preview {
    WarningBanner(text: "Raid bosses couldn't update. Using the last saved copy.")
}
