import SwiftUI
import SwiftData

/// The target bank, grouped by syllable shape. The parent marks which words are this
/// week's focus (a star) and can add or edit words their SLP has set.
struct TargetListView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @State private var vm = TargetsViewModel()
    @State private var editing: WordTarget?
    @State private var addingNew = false
    @State private var addingSet = false

    private var groups: [(shape: SyllableShape, targets: [WordTarget])] {
        vm.grouped(child.targets)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tap the star to add a word to this week's practice set. Words are grouped by sound shape, easiest first. "
                         + "Use the ••• menu for ready-made front ↔ back movement sets.")
                        .font(.footnote).foregroundStyle(Theme.label2)
                        .listRowBackground(Color.clear)
                }
                ForEach(groups, id: \.shape) { group in
                    Section {
                        ForEach(group.targets) { target in
                            row(target)
                        }
                        .onDelete { offsets in
                            offsets.map { group.targets[$0] }.forEach { vm.delete($0, in: context) }
                        }
                    } header: {
                        Text("\(group.shape.code) · \(group.shape.title)")
                    }
                }
            }
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button { addingSet = true } label: {
                        Label("Movement word sets", systemImage: "arrow.left.arrow.right")
                    }
                    .accessibilityIdentifier(A11y.addWordSet)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { addingNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a word")
                        .accessibilityIdentifier(A11y.addTarget)
                }
            }
            .sheet(isPresented: $addingNew) {
                TargetEditorView(child: child) { addingNew = false }
            }
            .sheet(isPresented: $addingSet) {
                WordSetsView(child: child) { addingSet = false }
            }
            .sheet(item: $editing) { target in
                TargetEditorView(child: child, existing: target) { editing = nil }
            }
        }
    }

    private func row(_ target: WordTarget) -> some View {
        HStack(spacing: Theme.sp3) {
            Button {
                vm.toggleActive(target, in: context)
            } label: {
                Image(systemName: target.isActiveThisWeek ? "star.fill" : "star")
                    .foregroundStyle(target.isActiveThisWeek ? Theme.accent : Theme.label3)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(target.isActiveThisWeek ? "Remove \(target.text) from this week" : "Add \(target.text) to this week")
            .accessibilityAddTraits(target.isActiveThisWeek ? [.isSelected] : [])

            VStack(alignment: .leading, spacing: 2) {
                Text(target.text).font(.body.weight(.medium)).foregroundStyle(Theme.label)
                if let movement = target.movement {
                    Text(movement.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.brandInk)
                }
                if !target.notes.isEmpty {
                    Text(target.notes).font(.caption).foregroundStyle(Theme.label2)
                }
            }
            Spacer()
            Button { editing = target } label: {
                Image(systemName: "pencil").foregroundStyle(Theme.label3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(target.text)")
        }
        .accessibilityIdentifier(A11y.targetRow(target.text))
    }
}
