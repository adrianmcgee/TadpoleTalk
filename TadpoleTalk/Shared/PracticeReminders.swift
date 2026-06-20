import Foundation
import UserNotifications

/// Schedules gentle "time for a quick go" nudges. The whole app is built on the evidence
/// that *a few minutes, several times a day* beats one long block — so reminders are
/// spread across the day rather than fired once. Local only; nothing leaves the device.
struct PracticeReminders {
    static let categoryID = "practice.reminder"

    /// Up to four reminders a day; identifiers reserved so we can always clear them.
    static let maxPerDay = 4

    /// Hours between successive reminders when more than one a day is chosen.
    private static let spacingHours = 3

    private static let messages = [
        "A few minutes of practice? Little and often is what helps.",
        "Quick practice break — three good goes is plenty.",
        "Time for a short, fun practice with your little one.",
        "A tiny bit of practice now keeps those words growing."
    ]

    /// Ask for permission. Returns whether it was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replace any existing reminders with `count` daily repeating ones, the first at
    /// `hour:minute` and the rest spaced `spacingHours` apart (wrapping within the day).
    func schedule(timesPerDay count: Int, startHour hour: Int, startMinute minute: Int) async {
        let center = UNUserNotificationCenter.current()
        await disable()
        let n = max(1, min(count, Self.maxPerDay))
        for i in 0..<n {
            let total = (hour * 60 + minute + i * Self.spacingHours * 60) % (24 * 60)
            var components = DateComponents()
            components.hour = total / 60
            components.minute = total % 60

            let content = UNMutableNotificationContent()
            content.title = "Tadpole Talk"
            content.body = Self.messages[i % Self.messages.count]
            content.sound = .default
            content.categoryIdentifier = Self.categoryID

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "\(Self.categoryID).\(i)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Remove all scheduled practice reminders.
    func disable() async {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<Self.maxPerDay).map { "\(Self.categoryID).\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
