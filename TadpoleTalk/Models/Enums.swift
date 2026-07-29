import SwiftUI

/// The shape of a word by consonant (C) / vowel (V) structure. In CAS therapy targets
/// are selected and sequenced by syllable shape and movement complexity — not by
/// phoneme alone — so this is a first-class property of every target.
enum SyllableShape: String, Codable, CaseIterable, Identifiable {
    case cv      // "bee", "go"
    case vc      // "up", "egg"
    case cvc     // "cat", "dog"
    case cvcv    // "baby", "mama"
    case cvcvc   // "banana"-ish chunks, "rabbit"
    case other   // clusters, longer words

    var id: String { rawValue }

    /// Short label as therapists write it.
    var code: String {
        switch self {
        case .cv: return "CV"
        case .vc: return "VC"
        case .cvc: return "CVC"
        case .cvcv: return "CVCV"
        case .cvcvc: return "CVCVC"
        case .other: return "Other"
        }
    }

    var title: String {
        switch self {
        case .cv: return "Consonant + vowel"
        case .vc: return "Vowel + consonant"
        case .cvc: return "Consonant + vowel + consonant"
        case .cvcv: return "Two simple syllables"
        case .cvcvc: return "Longer / multisyllable"
        case .other: return "Clusters & longer words"
        }
    }

    var example: String {
        switch self {
        case .cv: return "bee, go, more"
        case .vc: return "up, egg, on"
        case .cvc: return "cat, dog, cup"
        case .cvcv: return "mama, baby, water"
        case .cvcvc: return "rabbit, banana"
        case .other: return "stop, spoon, elephant"
        }
    }

    /// Rough difficulty order, easiest first — used to sort the target bank.
    var order: Int {
        switch self {
        case .cv: return 0
        case .vc: return 1
        case .cvc: return 2
        case .cvcv: return 3
        case .cvcvc: return 4
        case .other: return 5
        }
    }
}

/// How a single practice attempt (a "trial") went. CAS practice prizes successful
/// repetitions over volume, so the model is deliberately three simple buckets a parent
/// can tap without judgement, not a fine-grained score.
enum TrialRating: String, Codable, CaseIterable, Identifiable {
    case correct   // said it well
    case approx    // close — a good attempt
    case tryAgain  // not yet — move on, stay positive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .correct: return "Got it!"
        case .approx: return "Close"
        case .tryAgain: return "Try again"
        }
    }

    var symbol: String {
        switch self {
        case .correct: return "star.fill"
        case .approx: return "hand.thumbsup.fill"
        case .tryAgain: return "arrow.clockwise"
        }
    }

    var color: Color {
        switch self {
        case .correct: return Theme.correct
        case .approx: return Theme.approx
        case .tryAgain: return Theme.tryAgain
        }
    }

    /// Counts toward "successful reps" — the number that actually drives motor learning.
    var isSuccess: Bool { self == .correct }
}

/// How a practice session sequences its words. Motor learning favours *blocked* practice
/// while a movement is being acquired, then *random* (interleaved) practice to help it
/// generalise — so the parent can pick which suits where their child is at.
enum PracticeOrder: String, Codable, CaseIterable, Identifiable {
    case blocked   // drill one word to its goal, then the next
    case random    // mix the words up between attempts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blocked: return "Build up a word"
        case .random:  return "Mix it up"
        }
    }

    var detail: String {
        switch self {
        case .blocked: return "Practise one word until it's solid, then move on."
        case .random:  return "Jump between words to help them stick."
        }
    }
}

/// The amount of modelling support used for the current practice attempt. This is
/// deliberately session-only: it helps a caregiver pace practice without turning the app
/// into an assessment tool or storing a clinical judgement.
enum PracticeSupportLevel: Int, CaseIterable, Identifiable {
    case together
    case immediate
    case delayed
    case independent

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .together: return "Together"
        case .immediate: return "Right after me"
        case .delayed: return "After a pause"
        case .independent: return "On their own"
        }
    }

    var detail: String {
        switch self {
        case .together: return "Say it slowly at the same time."
        case .immediate: return "Model it, then let them try straight away."
        case .delayed: return "Model it, wait a moment, then invite a try."
        case .independent: return "Let them try without a model first."
        }
    }

    /// One step toward more help, stopping at simultaneous production.
    var moreSupported: PracticeSupportLevel {
        PracticeSupportLevel(rawValue: max(PracticeSupportLevel.together.rawValue, rawValue - 1))
            ?? .together
    }
}

/// Toddler-friendly carrier-phrase templates a parent can attach to a target with one tap.
/// `___` marks where the target word drops in. "Custom" lets the parent type their own.
enum CarrierPhrasePreset: String, CaseIterable, Identifiable {
    case none      = ""
    case more      = "more ___"
    case iWant     = "I want ___"
    case please    = "___ please"
    case big       = "big ___"
    case my        = "my ___"
    case custom    = "custom"

    var id: String { rawValue }

    /// The label shown in the picker.
    var title: String {
        switch self {
        case .none:   return "No phrase (just the word)"
        case .custom: return "Custom…"
        default:      return template.replacingOccurrences(of: "___", with: "word")
        }
    }

    /// The template stored on the target. Empty for `.none`/`.custom` (custom text is
    /// entered separately).
    var template: String {
        switch self {
        case .none, .custom: return ""
        default:             return rawValue
        }
    }

    /// The preset matching a stored template, falling back to `.custom` for anything
    /// non-empty that isn't a known preset, and `.none` for empty/nil.
    static func matching(_ stored: String?) -> CarrierPhrasePreset {
        guard let stored, !stored.isEmpty else { return .none }
        return allCases.first { $0.rawValue == stored && $0 != .custom } ?? .custom
    }
}
