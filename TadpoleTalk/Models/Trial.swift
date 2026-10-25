import Foundation
import SwiftData

/// A single practice attempt: which word, how it went, when. The grain the SLP report and
/// progress charts are built from.
@Model
final class Trial {
    var targetText: String = ""
    /// The `WordTarget.id` this attempt was at, so history stays together when the word is
    /// renamed. Optional so lightweight migration can add it; older rows are backfilled by
    /// `LaunchMaintenance`, and any it can't match fall back to `targetText`.
    var targetID: UUID?
    var ratingRaw: String = TrialRating.correct.rawValue
    /// How much prompting this attempt needed, as a `PromptLevel` raw value. Optional so
    /// lightweight migration can add it; attempts logged before it existed have none.
    var promptRaw: String?
    var timestamp: Date = Date()

    var session: PracticeSession?

    init(targetText: String, targetID: UUID? = nil, rating: TrialRating,
         prompt: PromptLevel? = nil, timestamp: Date = Date()) {
        self.targetText = targetText
        self.targetID = targetID
        self.ratingRaw = rating.rawValue
        self.promptRaw = prompt?.rawValue
        self.timestamp = timestamp
    }

    var rating: TrialRating {
        get { TrialRating(rawValue: ratingRaw) ?? .tryAgain }
        set { ratingRaw = newValue.rawValue }
    }

    var prompt: PromptLevel? {
        get { promptRaw.flatMap(PromptLevel.init(rawValue:)) }
        set { promptRaw = newValue?.rawValue }
    }
}
