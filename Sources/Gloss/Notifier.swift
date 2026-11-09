import Foundation
import UserNotifications

/// Local notifications. They work only when Gloss runs from its .app bundle.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let category = "gloss.nudge"
    var onOpen: () -> Void = {}

    /// UNUserNotificationCenter needs a bundle identifier; `swift run` has none.
    var available: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app" }

    func setUp() {
        guard available else { return }
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func post(due: Int, example: String?) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = "Gloss: \(due) card\(due == 1 ? "" : "s") to practise"
        content.body = example.map { "\($0) — click to start the quiz" } ?? "Click to start the quiz."
        content.categoryIdentifier = Self.category
        content.sound = nil
        let req = UNNotificationRequest(identifier: "gloss.nudge", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { self.onOpen() }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
