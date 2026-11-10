import SwiftUI
import SwiftData
import GameMath

struct PlannerView: View {
    @Query(sort: \PowerUpGoal.createdAt, order: .reverse) private var goals: [PowerUpGoal]
    @Environment(\.modelContext) private var modelContext
    @Environment(DataCenter.self) private var dataCenter
    @State private var showingNewGoal = false

    var body: some View {
        Group {
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("No goals yet", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Plan a power-up: see the stardust, Candy and XL Candy it needs, the CP you'll get, and roughly when you'll have enough.")
                } actions: {
                    Button("New goal") { showingNewGoal = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(goals) { goal in
                        NavigationLink {
                            GoalEditorView(goal: goal)
                        } label: {
                            GoalRow(goal: goal)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(goals[index]) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("Planner")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewGoal = true
                } label: {
                    Label("New goal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewGoal) {
            NavigationStack {
                GoalEditorView(goal: nil)
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
    }
}

private struct GoalRow: View {
    let goal: PowerUpGoal

    var body: some View {
        let draft = GoalDraft(goal: goal, types: [])
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.speciesName)
                    .font(.headline)
                Spacer()
                Text("L\(draft.current.description) → L\(draft.target.description)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !flags.isEmpty {
                Text(flags.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let tables = PlannerMath.tables {
                let cost = draft.cost(tables)
                ProgressView(value: GoalEstimator.progress(cost: cost, have: draft.owned))
                    .accessibilityLabel("Candy collected")
                Text("\(cost.stardust.formatted()) stardust · \(cost.candy.formatted()) Candy · \(cost.xlCandy.formatted()) XL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(eta(cost: cost, draft: draft))
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    private var flags: [String] {
        var list: [String] = []
        if goal.isShadow { list.append("Shadow") }
        if goal.isPurified { list.append("Purified") }
        if goal.isLucky { list.append("Lucky") }
        if goal.isBestBuddy { list.append("Best Buddy") }
        return list
    }

    private func eta(cost: PowerUpCost, draft: GoalDraft) -> String {
        guard let days = GoalEstimator.daysNeeded(cost: cost, have: draft.owned, income: draft.dailyIncome) else {
            return "Add income to estimate"
        }
        if days == 0 { return "Ready now" }
        let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        return "Ready around \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}

#Preview {
    NavigationStack { PlannerView() }
        .environment(DataCenter())
        .modelContainer(for: [PowerUpGoal.self], inMemory: true)
}
