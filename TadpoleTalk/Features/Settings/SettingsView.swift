import SwiftUI

/// A small settings surface: practice reminders, the child's profile, and a pointer to the
/// privacy promise. Reached from the gear on Today.
struct SettingsView: View {
    let child: Child
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("remindersPerDay") private var remindersPerDay = 3
    /// First reminder time, stored as minutes since midnight. Default 9:00 AM.
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60

    private let reminders = PracticeReminders()

    /// Bridges the stored minutes-since-midnight to a `Date` for the picker.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderMinutes / 60,
                    minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily practice reminders", isOn: $remindersEnabled)
                        .accessibilityIdentifier("settings.remindersToggle")
                    if remindersEnabled {
                        DatePicker("First reminder at",
                                   selection: reminderTime,
                                   displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("settings.reminderTime")
                        Stepper("\(remindersPerDay) a day", value: $remindersPerDay, in: 1...4)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Short, spread-out nudges — because a few minutes several times a day helps far more than one long session.")
                }

                Section("Child") {
                    LabeledContent("Name", value: child.name)
                    LabeledContent("Age", value: ageText)
                }

                Section {
                    NavigationLink {
                        privacyDetail
                    } label: {
                        Label("Your privacy", systemImage: "lock.fill")
                    }
                } footer: {
                    Text("Everything stays on this device. No account, no tracking, nothing uploaded.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .onChange(of: remindersEnabled) { _, on in applyReminders(enabled: on) }
            .onChange(of: remindersPerDay) { _, _ in if remindersEnabled { applyReminders(enabled: true) } }
            .onChange(of: reminderMinutes) { _, _ in if remindersEnabled { applyReminders(enabled: true) } }
        }
    }

    private var ageText: String {
        let years = child.ageMonths / 12, months = child.ageMonths % 12
        if years == 0 { return "\(months) months" }
        return months == 0 ? "\(years)y" : "\(years)y \(months)m"
    }

    private var privacyDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sp4) {
                Text("Private by design").font(.title2.bold()).foregroundStyle(Theme.label)
                Text("Tadpole Talk keeps your child's profile, targets, and practice history only on this device. "
                    + "There is no account to create, no analytics, and nothing is sent to any server. "
                    + "When you export a report, you choose exactly where it goes.")
                    .font(.body).foregroundStyle(Theme.label2)
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.sp4)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func applyReminders(enabled: Bool) {
        Task {
            if enabled {
                let granted = await reminders.requestAuthorization()
                if granted {
                    await reminders.schedule(timesPerDay: remindersPerDay,
                                             startHour: reminderMinutes / 60,
                                             startMinute: reminderMinutes % 60)
                } else {
                    remindersEnabled = false   // permission denied — reflect reality
                }
            } else {
                await reminders.disable()
            }
        }
    }
}
