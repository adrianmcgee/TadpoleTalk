import SwiftUI
import SwiftData

/// Ready-made sets of words that practise moving the tongue between front sounds (d, t)
/// and back sounds (g, k), grouped by shape. One tap puts a whole set — or a single word —
/// into this week's practice, adding any words the child doesn't have yet.
struct WordSetsView: View {
    let child: Child
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var vm = TargetsViewModel()

    private let sets = ContentStore.shared.movementSets

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Front sounds (d, t) use the tongue tip; back sounds (g, k) use the back of the tongue. "
                         + "These words practise switching between them.")
                        .font(.footnote).foregroundStyle(Theme.label2)
                        .listRowBackground(Color.clear)
                }
                ForEach(sets) { set in
                    Section {
                        ForEach(set.targets) { starter in
                            row(starter)
                        }
                        Button {
                            vm.addToThisWeek(set.targets, to: child, in: context)
                        } label: {
                            Label("Practise all this week", systemImage: "star.fill")
                        }
                        .disabled(set.targets.allSatisfy(isActive))
                    } header: {
                        Text("\(set.shape.code) · \(set.movement.title)")
                    } footer: {
                        Text(set.movement.detail)
                    }
                }
            }
            .navigationTitle("Movement words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    private func isActive(_ starter: StarterTarget) -> Bool {
        vm.existingTarget(matching: starter.text, in: child)?.isActiveThisWeek == true
    }

    private func row(_ starter: StarterTarget) -> some View {
        let active = isActive(starter)
        return Button {
            if let existing = vm.existingTarget(matching: starter.text, in: child), active {
                vm.toggleActive(existing, in: context)
            } else {
                vm.addToThisWeek([starter], to: child, in: context)
            }
        } label: {
            HStack {
                Text(starter.text).foregroundStyle(Theme.label)
                Spacer()
                Image(systemName: active ? "star.fill" : "star")
                    .foregroundStyle(active ? Theme.accent : Theme.label3)
            }
        }
        .accessibilityLabel(active ? "Remove \(starter.text) from this week" : "Add \(starter.text) to this week")
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
