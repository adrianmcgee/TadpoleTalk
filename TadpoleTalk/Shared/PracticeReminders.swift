import Foundation
import UserNotifications

/// Schedules one gentle "time for a quick go" nudge a day at the parent's chosen time.
/// Local only; nothing leaves the device.
struct PracticeReminders {
    static let categoryID = "practice.reminder"
    static let requestID = "\(categoryID).daily"
    /// Identifiers used when the app scheduled up to four reminders a day. Cleared on every
    /// reschedule so an upgrade doesn't leave the old extra nudges behind.
    static let legacyRequestIDs = (0..<4).map { "\(categoryID).\($0)" }

    private static let message = "A few minutes of practice? Little and often is what helps."

    /// Ask for permission. Returns whether it was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replace any existing reminders with a single daily repeating one at `hour:minute`.
    func schedule(hour: Int, minute: Int) async {
        await disable()
        try? await UNUserNotificationCenter.current().add(Self.makeRequest(hour: hour, minute: minute))
    }

    /// The daily reminder request, separated out so the trigger time is unit-testable.
    static func makeRequest(hour: Int, minute: Int) -> UNNotificationRequest {
        var components = DateComponents()
        components.hour = min(max(hour, 0), 23)
        components.minute = min(max(minute, 0), 59)
        let content = UNMutableNotificationContent()
        content.title = "Tadpole Talk"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = categoryID
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
    }

    /// Remove all scheduled practice reminders, including any left from older versions.
    func disable() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.requestID] + Self.legacyRequestIDs)
    }
}
