import Foundation
import SwiftData

/// A word (or syllable) the family is practising. Seeded from a starter bank organised by
/// syllable shape, then fully editable — the SLP typically gives a handful of targets per
/// week and the parent marks those active.
@Model
final class WordTarget {
    /// Stable identity, used as the key for any parent-recorded model audio file so the
    /// clip survives edits to the word text. Defaulted so SwiftData lightweight migration
    /// can add it to existing rows.
    var id: UUID = UUID()
    var text: String = ""
    /// Stored as the enum raw value so SwiftData stays happy; accessed via `shape`.
    var shapeRaw: String = SyllableShape.cv.rawValue
    /// IDs into the bundled phoneme reference, so a target can link to its sounds.
    var phonemeIDs: [String] = []
    /// Whether this is part of the current week's focus set.
    var isActiveThisWeek: Bool = false
    var notes: String = ""
    /// Optional carrier-phrase template using a `___` placeholder for the word, e.g.
    /// "more ___". Lets a session step the child up from the word to a short phrase.
    var carrierPhrase: String?
    /// Filename (within `AudioStore`'s recordings directory) of a parent-recorded model of
    /// this word, if any. Absent for most targets — TTS is the default model.
    var audioFilename: String?
    var createdAt: Date = Date()

    var child: Child?

    init(text: String,
         shape: SyllableShape,
         phonemeIDs: [String] = [],
         isActiveThisWeek: Bool = false,
         notes: String = "",
         carrierPhrase: String? = nil) {
        self.id = UUID()
        self.text = text
        self.shapeRaw = shape.rawValue
        self.phonemeIDs = phonemeIDs
        self.isActiveThisWeek = isActiveThisWeek
        self.notes = notes
        self.carrierPhrase = carrierPhrase
        self.createdAt = Date()
    }

    var shape: SyllableShape {
        get { SyllableShape(rawValue: shapeRaw) ?? .other }
        set { shapeRaw = newValue.rawValue }
    }

    /// True when the parent has attached their own recorded model for this word.
    var hasParentAudio: Bool {
        guard let name = audioFilename else { return false }
        return !name.isEmpty
    }

    /// The text to show and speak: the carrier phrase with `___` filled in by the word,
    /// or just the word when there's no phrase. Trimmed so a stray template still reads well.
    var phraseText: String {
        guard let template = carrierPhrase?.trimmingCharacters(in: .whitespacesAndNewlines),
              !template.isEmpty else { return text }
        return template.contains("___")
            ? template.replacingOccurrences(of: "___", with: text)
            : "\(template) \(text)"
    }
}
