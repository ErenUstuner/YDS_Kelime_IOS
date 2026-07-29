import Foundation
import SwiftUI
import WidgetKit

// ============================================================
// Uygulama ortamı
//
// Tek bir yerde kurulan ve tüm ekranlara @EnvironmentObject olarak
// verilen bağımlılıklar. Singleton kullanmıyoruz: testte sahte bir
// ortam kurmak singleton'la mümkün olmazdı.
// ============================================================

@MainActor
final class AppEnvironment: ObservableObject {

    /// Deste yüklenemezse uygulamayı çökertmek yerine bu hatayı gösteririz.
    @Published private(set) var loadError: String?
    @Published var options = SessionOptions() {
        didSet { persistOptions() }
    }

    let store: ProgressStore
    let deck: Deck
    let matcher: SentenceMatcher
    let ads: AdsManager
    let notifications: NotificationService

    private let defaults = UserDefaults.standard

    init() {
        let store = ProgressStore()
        self.store = store

        do {
            let deck = try DeckLoader.load()
            self.deck = deck
            self.matcher = SentenceMatcher(irregular: deck.irregular)
            self.loadError = nil
        } catch {
            // Boş deste ile devam et; RootView hata ekranını gösterir.
            self.deck = Deck(payload: DeckPayload(version: 0, generatedAt: "", wordCount: 0,
                                                  phrasalCount: 0, irregular: [:], cards: []))
            self.matcher = SentenceMatcher(irregular: [:])
            self.loadError = error.localizedDescription
        }

        self.ads = AdsManager()
        self.notifications = NotificationService()
        restoreOptions()
    }

    // ------------------------------------------------------------
    // Ana ekran sayaçları
    // ------------------------------------------------------------

    var counts: (due: Int, fresh: Int, studied: Int) {
        QueueBuilder.counts(cards: deck.cards,
                            records: store.snapshot.rec,
                            today: SM2Scheduler.dayIndex())
    }

    var stats: StudyStats {
        StatsCalculator.compute(deck: deck, snapshot: store.snapshot)
    }

    var dayStreak: Int {
        StatsCalculator.currentDayStreak(days: store.snapshot.days,
                                         today: SM2Scheduler.dayIndex())
    }

    // ------------------------------------------------------------
    // Oturum
    // ------------------------------------------------------------

    func makeSession() -> QuizSession {
        QuizSession(deck: deck, store: store, options: options)
    }

    /// Seçili destede sorulabilecek kart var mı?
    func canStartSession() -> Bool {
        !QueueBuilder.build(cards: deck.cards,
                            records: store.snapshot.rec,
                            filter: options.deck,
                            size: 1,
                            today: SM2Scheduler.dayIndex()).isEmpty
    }

    /// Oturum bittiğinde widget'ı ve bildirim planını tazeler.
    ///
    /// Widget'ı her cevapta değil oturum sonunda güncelliyoruz: WidgetKit
    /// yenileme bütçesini sınırlıyor, her cevapta çağırmak bütçeyi tüketip
    /// widget'ın günlerce donmasına yol açardı.
    func sessionDidFinish() {
        refreshWidget()
        Task { await notifications.rescheduleDailyReminder(dueCount: counts.due) }
    }

    func refreshWidget() {
        let c = counts
        let today = SM2Scheduler.dayIndex()
        SharedContainer.writeSnapshot(.init(due: c.due,
                                            newCards: c.fresh,
                                            studiedToday: store.snapshot.days.contains(today),
                                            streakBest: store.snapshot.streakBest,
                                            accuracy: store.accuracyPercent,
                                            updatedAt: Date()))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // ------------------------------------------------------------
    // Ayar kalıcılığı
    // ------------------------------------------------------------

    private enum Keys {
        static let deck = "options.deck"
        static let direction = "options.direction"
        static let length = "options.length"
    }

    private func restoreOptions() {
        var restored = SessionOptions()
        if let raw = defaults.string(forKey: Keys.deck), let value = DeckFilter(rawValue: raw) {
            restored.deck = value
        }
        if let raw = defaults.string(forKey: Keys.direction), let value = QuizDirection(rawValue: raw) {
            restored.direction = value
        }
        let length = defaults.integer(forKey: Keys.length)
        if SessionOptions.lengthChoices.contains(length) { restored.length = length }
        options = restored
    }

    private func persistOptions() {
        defaults.set(options.deck.rawValue, forKey: Keys.deck)
        defaults.set(options.direction.rawValue, forKey: Keys.direction)
        defaults.set(options.length, forKey: Keys.length)
    }
}
