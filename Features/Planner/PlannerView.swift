import SwiftUI

struct PlannerView: View {
    var body: some View {
        PlaceholderView(
            title: "Candy & Stardust Planner",
            systemImage: "chart.line.uptrend.xyaxis",
            message: "Plan power-ups: stardust, candy and XL candy needed, CP at the target level, and how long it will take."
        )
        .navigationTitle("Planner")
    }
}

#Preview {
    NavigationStack { PlannerView() }
}
