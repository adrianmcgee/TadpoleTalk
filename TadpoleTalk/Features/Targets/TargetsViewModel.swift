import SwiftUI
import SwiftData

/// Manages the target bank: grouping for display, toggling the weekly set, and adding or
/// editing words. The active-set rule (and the guard rails around it) live here so they're
/// testable and the views stay declarative.
@Observable
final class TargetsViewModel {
    /// Targets grouped by syllable shape, easiest first, words alphabetised within a shape.
    func grouped(_ targets: [WordTarget]) -> [(shape: SyllableShape, targets: [WordTarget])] {
        let byShape = Dictionary(grouping: targets, by: \.shape)
        return SyllableShape.allCases.compactMap { shape in
            guard let items = byShape[shape], !items.isEmpty else { return nil }
            return (shape, items.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending })
        }
    }

    func toggleActive(_ target: WordTarget, in context: ModelContext) {
        target.isActiveThisWeek.toggle()
        context.saveOrLog()
    }

    /// Create a new target for the child. Returns it so a caller can navigate if needed.
    /// `id` defaults to a fresh UUID but can be supplied so a clip recorded in the editor
    /// (keyed by that id) matches the saved target.
    @discardableResult
    func add(text: String, shape: SyllableShape, phonemeIDs: [String], notes: String,
             activeThisWeek: Bool, carrierPhrase: String? = nil, audioFilename: String? = nil,
             id: UUID = UUID(), to child: Child, in context: ModelContext) -> WordTarget {
        let target = WordTarget(text: text.trimmingCharacters(in: .whitespaces), shape: shape,
                                phonemeIDs: phonemeIDs, isActiveThisWeek: activeThisWeek, notes: notes,
                                carrierPhrase: carrierPhrase)
        target.id = id
        target.audioFilename = audioFilename
        target.child = child
        context.insert(target)
        context.saveOrLog()
        return target
    }

    func delete(_ target: WordTarget, in context: ModelContext) {
        context.delete(target)
        context.saveOrLog()
    }

    func save(in context: ModelContext) { context.saveOrLog() }
}
