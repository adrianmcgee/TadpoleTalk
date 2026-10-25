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

    /// Put a ready-made set of words into this week's practice: words the child already has
    /// (matched ignoring case) are starred, the rest are added. Returns how many were new.
    @discardableResult
    func addToThisWeek(_ starters: [StarterTarget], to child: Child, in context: ModelContext) -> Int {
        var added = 0
        for starter in starters {
            if let existing = existingTarget(matching: starter.text, in: child) {
                existing.isActiveThisWeek = true
            } else {
                let target = WordTarget(text: starter.text, shape: starter.shape,
                                        phonemeIDs: starter.phonemeIDs, isActiveThisWeek: true)
                target.child = child
                context.insert(target)
                added += 1
            }
        }
        context.saveOrLog()
        return added
    }

    /// The child's word with this text, ignoring case and surrounding spaces.
    func existingTarget(matching text: String, in child: Child) -> WordTarget? {
        let wanted = text.trimmingCharacters(in: .whitespaces)
        return child.targets.first {
            $0.text.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(wanted) == .orderedSame
        }
    }

    func delete(_ target: WordTarget, in context: ModelContext) {
        AudioStore.shared.delete(target.audioFilename)
        context.delete(target)
        context.saveOrLog()
    }

    func save(in context: ModelContext) { context.saveOrLog() }
}
