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
    var timestamp: Date = Date()

    var session: PracticeSession?

    init(targetText: String, targetID: UUID? = nil, rating: TrialRating, timestamp: Date = Date()) {
        self.targetText = targetText
        self.targetID = targetID
        self.ratingRaw = rating.rawValue
        self.timestamp = timestamp
    }

    var rating: TrialRating {
        get { TrialRating(rawValue: ratingRaw) ?? .tryAgain }
        set { ratingRaw = newValue.rawValue }
    }
}
