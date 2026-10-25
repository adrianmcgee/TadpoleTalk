import SwiftUI
import SwiftData
import Charts

/// The progress tab: a few honest figures, a fortnight of practice at a glance, how each
/// word is coming along, and a one-tap export the parent can show their SLP.
struct ProgressDashboardView: View {
    let child: Child
    @State private var vm = ProgressViewModel()
    @State private var share: ShareItems?

    private var bars: [ProgressViewModel.DayBar] { vm.dailyBars(child) }
    private var targets: [ProgressViewModel.TargetProgress] { vm.perTarget(child) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sp5) {
                    headlineRow
                    practiceChartCard
                    movementCard
                    perWordCard
                    exportButton
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(Theme.sp4)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Progress")
            .sheet(item: $share) { item in
                ActivityView(items: item.urls)
            }
        }
    }

    private var headlineRow: some View {
        HStack(spacing: Theme.sp3) {
            headline("\(vm.totalSessions(child))", "sessions", Theme.brand)
            headline("\(vm.totalSuccesses(child))", "great reps", Theme.correct)
            headline("\(vm.masteredCount(child))", "coming along", Theme.accent)
        }
    }

    private func headline(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Theme.label2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.sp3)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var practiceChartCard: some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            Text("Last two weeks").font(.headline).foregroundStyle(Theme.label)
            if vm.totalTrials(child) == 0 {
                emptyHint("Your practice will show up here once you've had a few goes.")
            } else {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Great reps", bar.successes)
                    )
                    .foregroundStyle(Theme.correct)
                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Other tries", bar.total - bar.successes)
                    )
                    .foregroundStyle(Theme.brand.opacity(0.35))
                }
                .chartLegend(.hidden)
                .frame(height: 180)
                .accessibilityLabel("Bar chart of practice attempts per day over the last two weeks")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.sp4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }

    private var perWordCard: some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            Text("How each word is going").font(.headline).foregroundStyle(Theme.label)
            if targets.isEmpty {
                emptyHint("Practise a few words and you'll see each one's progress here.")
            } else {
                ForEach(targets) { target in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(target.word).font(.subheadline.weight(.medium)).foregroundStyle(Theme.label)
                            if let movement = target.movement {
                                Text(movement.title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.brandInk)
                            }
                            Spacer()
                            Text("\(target.successes)/\(target.total)").font(.caption).foregroundStyle(Theme.label2)
                        }
                        ProgressView(value: target.rate)
                            .tint(target.rate >= 0.8 ? Theme.correct : Theme.brand)
                        if let prompting = promptingText(target) {
                            Text(prompting).font(.caption).foregroundStyle(Theme.label2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(target.word): \(target.successes) of \(target.total) good, "
                                        + "\(Int(target.rate * 100)) percent. \(promptingText(target) ?? "")")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.sp4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }

    /// "Best: mild prompting · Last: max prompting", or nil when no prompting was logged.
    private func promptingText(_ target: ProgressViewModel.TargetProgress) -> String? {
        var parts: [String] = []
        if let best = target.leastPromptForSuccess { parts.append("Best: \(best.summary)") }
        if let last = target.latestPrompt { parts.append("Last: \(last.summary)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Front → back vs back → front at a glance, shown once any movement word is practised.
    @ViewBuilder
    private var movementCard: some View {
        let movements = vm.perMovement(child)
        if !movements.isEmpty {
            VStack(alignment: .leading, spacing: Theme.sp3) {
                Text("Tongue movement").font(.headline).foregroundStyle(Theme.label)
                ForEach(movements) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.movement.title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.label)
                            Spacer()
                            Text("\(item.successes)/\(item.total)").font(.caption).foregroundStyle(Theme.label2)
                        }
                        ProgressView(value: item.rate)
                            .tint(item.rate >= 0.8 ? Theme.correct : Theme.brand)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.movement.title): \(item.successes) of \(item.total) good")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.sp4)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        }
    }

    private var exportButton: some View {
        Button {
            let exporter = ReportExporter()
            let urls = [exporter.writePDF(for: child), exporter.writeCSV(for: child)].compactMap { $0 }
            if !urls.isEmpty { share = ShareItems(urls: urls) }
        } label: {
            Label("Export for your therapist", systemImage: "square.and.arrow.up")
                .font(.headline).frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
        }
        .buttonStyle(.bordered)
        .disabled(vm.totalTrials(child) == 0)
        .accessibilityIdentifier(A11y.exportReport)
    }

    private func emptyHint(_ text: String) -> some View {
        HStack(spacing: Theme.sp3) {
            TadpoleMascot()
                .frame(width: 56, height: 56)
            Text(text).font(.subheadline).foregroundStyle(Theme.label2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Identifiable wrapper so a freshly generated set of files can drive a share sheet.
struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// Thin bridge to UIKit's share sheet for exporting the PDF/CSV.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
