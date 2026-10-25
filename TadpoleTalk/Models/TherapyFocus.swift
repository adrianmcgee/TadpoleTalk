import Foundation

/// The direction the tongue travels between a word's consonants. Therapists often target
/// a *movement* rather than a single sound: front sounds (d, t) are made with the tongue
/// tip, back sounds (g, k) with the back of the tongue, and switching between them inside
/// a word ("digger", "cat") is the skill being practised.
enum MovementPattern: String, Codable, CaseIterable, Identifiable {
    case frontToBack
    case backToFront

    var id: String { rawValue }

    /// Stored in `WordTarget.movementRaw` when the parent says a word has no front/back
    /// movement, as distinct from empty ("guess from the spelling").
    static let storedNone = "none"

    var title: String {
        switch self {
        case .frontToBack: return "Front → back"
        case .backToFront: return "Back → front"
        }
    }

    var detail: String {
        switch self {
        case .frontToBack: return "Tongue tip first (d, t), then the back (g, k), as in digger, dark."
        case .backToFront: return "Back of the tongue first (g, k), then the tip (d, t), as in cat, kid."
        }
    }

    /// Where a consonant is made, for the purposes of front/back movement.
    private enum Place { case front, back }

    /// A best guess from the spelling: the first tongue-tip or tongue-back consonant, then
    /// the first later consonant made at the other end. Nil when the word doesn't switch
    /// ("cake", "cup"). Only a starting point — the parent can always override it.
    static func guess(for word: String) -> MovementPattern? {
        let letters = Array(word.lowercased())
        var places: [Place] = []
        var i = 0
        while i < letters.count {
            let letter = letters[i]
            let next: Character? = i + 1 < letters.count ? letters[i + 1] : nil
            switch letter {
            case "d", "t":
                // "th" is a different sound, not a tongue-tip stop.
                if next != "h" { places.append(.front) }
            case "n":
                // "ng" is made at the back; a plain "n" is tongue tip.
                if next == "g" || next == "k" { places.append(.back); i += 1 } else { places.append(.front) }
            case "k", "g", "q":
                places.append(.back)
            case "c":
                // A soft c ("city") is an s sound, not a k.
                if next.map({ "eiy".contains($0) }) != true { places.append(.back) }
            default:
                break
            }
            i += 1
        }
        guard let first = places.first,
              places.dropFirst().contains(where: { $0 != first }) else { return nil }
        return first == .front ? .frontToBack : .backToFront
    }
}

/// How much prompting the child needed on an attempt, in the words therapists use in their
/// notes ("achieved with mild prompting"). Logged per attempt so the parent and their
/// speech pathologist can see help fade over time.
enum PromptLevel: String, Codable, CaseIterable, Identifiable {
    // Not `none`, which would be easy to confuse with `Optional.none`.
    case unprompted = "none"
    case mild
    case max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unprompted: return "None"
        case .mild: return "Mild"
        case .max: return "Max"
        }
    }

    /// Phrase used in progress and reports, e.g. "mild prompting".
    var summary: String {
        switch self {
        case .unprompted: return "no prompting"
        case .mild: return "mild prompting"
        case .max: return "max prompting"
        }
    }

    /// Fewer prompts sort later, so "best so far" reads naturally.
    var order: Int {
        switch self {
        case .max: return 0
        case .mild: return 1
        case .unprompted: return 2
        }
    }
}

extension PracticeSupportLevel {
    /// The prompting level a modelling step usually corresponds to — used as the default
    /// so the parent only has to change it when their judgement differs.
    var promptLevel: PromptLevel {
        switch self {
        case .together: return .max
        case .immediate, .delayed: return .mild
        case .independent: return .unprompted
        }
    }
}

/// Voicing swaps — d for t, g for k and back — are often accepted while a child is still
/// learning the movement between sounds. These helpers find a word's swappable sound so the
/// practice screen can show a concrete example ("gat" for "cat") of what still counts.
enum VoicingSwap {
    private static let pairs: [Character: Character] = [
        "d": "t", "t": "d", "g": "k", "k": "g", "c": "g"
    ]

    /// The word with its first voicing-swappable sound swapped, or nil if it has none.
    static func example(for word: String) -> String? {
        var letters = Array(word.lowercased())
        for (i, letter) in letters.enumerated() {
            let next: Character? = i + 1 < letters.count ? letters[i + 1] : nil
            if letter == "t", next == "h" { continue }
            if letter == "c", let next, "eiyh".contains(next) { continue }
            guard let swap = pairs[letter] else { continue }
            letters[i] = swap
            return String(letters)
        }
        return nil
    }
}
