import Foundation
import UserNotifications

// ============================================================
// Bildirim servisi
//
// Tek bir günlük hatırlatma. Kasıtlı olarak sade:
//
//   * Tekrar edilecek kart yoksa bildirim planlanmaz. Boş bir
//     "çalışmayı unutma" mesajı kullanıcıyı bildirimleri tamamen
//     kapatmaya iter — o noktadan geri dönüş yok.
//   * Aynı anda tek bildirim tutulur; birikip yığılmaz.
//   * Metin, vadesi gelen kart sayısını içerir: somut bir sayı
//     görmek genel bir hatırlatmadan çok daha etkili.
// ============================================================

actor NotificationService {

    private let center = UNUserNotificationCenter.current()
    private let identifier = "yds.daily-reminder"
    private var preferredHour = 20

    func setPreferredHour(_ hour: Int) {
        preferredHour = min(max(hour, 0), 23)
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationGranted() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Günlük hatırlatmayı yeniden kurar.
    func rescheduleDailyReminder(dueCount: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard await authorizationGranted() else { return }
        guard dueCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tekrar zamanı"
        content.body = dueCount == 1
            ? "1 kelimenin tekrarı geldi. Bir dakikanı alır."
            : "\(dueCount) kelimenin tekrarı geldi. Kısa bir oturum yeterli."
        content.sound = .default
        content.badge = NSNumber(value: dueCount)

        var components = DateComponents()
        components.hour = preferredHour
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        try? await center.setBadgeCount(0)
    }
}
