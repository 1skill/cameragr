import Foundation
import UserNotifications

/// The day's theme, a nudge once a day (S6, user 11/25): a local notification
/// on this iPhone, never from a server. Offered once one has posted; asked for
/// only when chosen. It says "look at today's theme", never a theme's name
/// (the next ones may not be known yet).
@MainActor
final class DailyReminder: ObservableObject {
    static let shared = DailyReminder()
    private static let id = "koco.daily-theme"
    private let center = UNUserNotificationCenter.current()

    /// On (chosen, and allowed by the system).
    @Published private(set) var isOn = UserDefaults.standard.bool(forKey: "dailyReminderOn")
    /// The offer stays until it's been answered once.
    @Published private(set) var offered = UserDefaults.standard.bool(forKey: "dailyReminderOffered")
    /// One has posted at least once on this iPhone: the offer can show.
    @Published private(set) var hasPosted = UserDefaults.standard.bool(forKey: "clubPostedOnce")
    /// The system said no: the switch points to Settings instead.
    @Published private(set) var denied = false
    /// The last turning-on could not set the nudge: shown, to try again.
    @Published private(set) var failed = false

    /// At 19:00 in whatever time zone the phone is in (a calendar trigger
    /// follows the phone's zone when it moves).
    static let hour = 19

    func notePosted() {
        guard !hasPosted else { return }
        hasPosted = true
        UserDefaults.standard.set(true, forKey: "clubPostedOnce")
    }

    /// Bumped by every turn on or off: an older turning-on that ends late does nothing.
    private var turn = 0

    /// Chosen: ask the system (once), then set the daily nudge. Only once one
    /// has posted (S6: never asked before).
    func turnOn() async {
        guard hasPosted else { return }
        turn += 1
        let mine = turn
        offered = true
        UserDefaults.standard.set(true, forKey: "dailyReminderOffered")
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard mine == turn else { return }
        guard granted else { denied = true; set(false); return }
        denied = false
        center.removePendingNotificationRequests(withIdentifiers: [Self.id])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Koco")
        content.body = String(localized: "Look at today's theme.")
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: Self.hour, minute: 0), repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: Self.id, content: content, trigger: trigger))
            guard mine == turn else { center.removePendingNotificationRequests(withIdentifiers: [Self.id]); return }
            failed = false
            set(true)
        } catch { if mine == turn { failed = true; set(false) } }
    }

    /// Not wanted (now, or from the offer): nothing scheduled.
    func turnOff(declined: Bool = false) {
        turn += 1
        if declined { offered = true; UserDefaults.standard.set(true, forKey: "dailyReminderOffered") }
        center.removePendingNotificationRequests(withIdentifiers: [Self.id])
        set(false)
    }

    /// The switch follows the system: turned off in Settings, it shows off.
    /// Both ways: turned off in Settings shows off; allowed again clears the note.
    func refresh() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied: denied = true; if isOn { turnOff() }
        case .authorized, .provisional, .ephemeral:
            denied = false
            if isOn {
                let pending = await center.pendingNotificationRequests()
                if !pending.contains(where: { $0.identifier == Self.id }) { set(false) }   // gone: say so
            }
        default: break
        }
    }

    private func set(_ on: Bool) {
        isOn = on
        UserDefaults.standard.set(on, forKey: "dailyReminderOn")
    }
}
