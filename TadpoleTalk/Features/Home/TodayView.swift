import SwiftUI
import SwiftData

/// The home screen. Greets the family, shows today's encouraging numbers, lists this
/// week's active targets, and offers the one button that matters: start a short practice.
struct TodayView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @State private var vm = HomeViewModel()
    @State private var showingPractice = false
    @State private var showingSettings = false

    // Practice settings, set in Settings and handed to each session.
    @AppStorage("repGoalPerWord") private var repGoalPerWord = 5
    @AppStorage("practiceOrderRaw") private var practiceOrderRaw = PracticeOrder.blocked.rawValue
    @AppStorage("autoAdvance") private var autoAdvance = false
    @AppStorage("autoPlayModel") private var autoPlayModel = true

    private var activeTargets: [WordTarget] { child.activeTargets }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sp5) {
                    header
                    statsRow
                    startCard
                    activeTargetsCard
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(Theme.sp4)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("home.settings")
                }
            }
            .fullScreenCover(isPresented: $showingPractice) {
                PracticeSessionView(
                    child: child,
                    targets: activeTargets,
                    order: PracticeOrder(rawValue: practiceOrderRaw) ?? .blocked,
                    repGoal: repGoalPerWord,
                    autoAdvance: autoAdvance,
                    autoPlayModel: autoPlayModel
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(child: child) { showingSettings = false }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.sp3) {
            Image(systemName: child.avatarSymbol)
                .font(.system(size: 34))
                .foregroundStyle(Theme.brand)
                .frame(width: 56, height: 56)
                .background(Theme.brand.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi \(child.name)!").font(.title2.bold()).foregroundStyle(Theme.label)
                Text(vm.encouragement(child)).font(.subheadline).foregroundStyle(Theme.label2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        HStack(spacing: Theme.sp3) {
            stat("\(vm.sessionsToday(child))", "practices\ntoday", "checkmark.circle.fill", Theme.brand)
            stat("\(vm.successesToday(child))", "great\nreps", "star.fill", Theme.correct)
            stat("\(vm.streak(child))", "day\nstreak", "flame.fill", Theme.accent)
        }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: Theme.sp1) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
            Text(value).font(.title.bold()).foregroundStyle(Theme.label)
            Text(label).font(.caption).multilineTextAlignment(.center).foregroundStyle(Theme.label2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.sp3)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label.replacingOccurrences(of: "\n", with: " "))")
    }

    private var startCard: some View {
        VStack(spacing: Theme.sp3) {
            Button {
                showingPractice = true
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill").font(.title2)
                    Text(activeTargets.isEmpty ? "Add some targets first" : "Start practice")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
            }
            .buttonStyle(.borderedProminent)
            .disabled(activeTargets.isEmpty)
            .accessibilityIdentifier(A11y.startPractice)

            if !activeTargets.isEmpty {
                Text("\(activeTargets.count) word\(activeTargets.count == 1 ? "" : "s") in this week's set")
                    .font(.caption).foregroundStyle(Theme.label3)
            }
        }
    }

    private var activeTargetsCard: some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            Text("This week's words").font(.headline).foregroundStyle(Theme.label)
            if activeTargets.isEmpty {
                HStack(spacing: Theme.sp3) {
                    TadpoleMascot()
                        .frame(width: 56, height: 56)
                    Text("Mark a few words as “this week” in Targets and they'll appear here.")
                        .font(.subheadline).foregroundStyle(Theme.label2)
                    Spacer(minLength: 0)
                }
            } else {
                ForEach(activeTargets) { target in
                    HStack {
                        Text(target.text).font(.body.weight(.medium)).foregroundStyle(Theme.label)
                        Spacer()
                        Text(target.shape.code)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, Theme.sp2).padding(.vertical, 4)
                            .background(Theme.brand.opacity(0.14), in: Capsule())
                            .foregroundStyle(Theme.brandInk)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.sp4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }
}
