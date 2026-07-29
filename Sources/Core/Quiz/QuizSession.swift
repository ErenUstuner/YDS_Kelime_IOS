import Foundation
import Combine

// ============================================================
// Oturum motoru
//
// Görünümden bağımsız oturum durumu. SwiftUI'yi hiç bilmez; testte
// doğrudan kullanılabilir. Görünüm katmanı yalnızca @Published
// alanları okur ve `answer` / `advance` çağırır.
// ============================================================

/// Oturum ayarları — ana ekrandaki üç segment.
struct SessionOptions: Equatable, Sendable {
    var deck: DeckFilter = .mix
    var direction: QuizDirection = .en2tr
    var length: Int = 20

    static let lengthChoices = [10, 20, 40]
}

/// Ekranda gösterilen tek bir soru.
struct QuizQuestion: Identifiable, Sendable {
    let id: String
    let card: Card
    /// Bu sorunun yönü. Ayar "Karışık" ise kart başına rastgele belirlenir.
    let direction: QuizDirection
    let options: [Card]
    /// Kartın daha önce kaç kez arka arkaya doğru bilindiği (rozet metni için).
    let repetition: Int
    let isNew: Bool

    var prompt: String { direction == .en2tr ? card.term : card.meaning }
    var promptIsEnglish: Bool { direction == .en2tr }

    func label(for option: Card) -> String {
        direction == .en2tr ? option.meaning : option.term
    }
}

/// Verilen cevabın sonucu.
struct AnswerOutcome: Sendable {
    let question: QuizQuestion
    let pickedIndex: Int
    let correctIndex: Int
    let isCorrect: Bool
    /// Bu cevaptan sonraki tekrar aralığı (gün). 0 ise aynı oturumda tekrar gelir.
    let nextIntervalDays: Int
    let easinessFactor: Double
    let hintUsed: Bool
}

/// Oturum sonunda gösterilen özet.
struct SessionSummary: Sendable {
    let correct: Int
    let wrong: Int
    let bestStreak: Int
    let mistakes: [Card]

    var total: Int { correct + wrong }
    var percent: Int { total > 0 ? Int((Double(correct) / Double(total) * 100).rounded()) : 0 }

    var title: String {
        if percent >= 90 { return "Mükemmel!" }
        if percent >= 70 { return "İyi gidiyorsun" }
        return "Tekrar şart"
    }

    var subtitle: String {
        wrong > 0
            ? "\(wrong) kelime yanlış işaretlendi, yakında tekrar sorulacak."
            : "Hepsi doğru — bu kartlar daha uzun aralıklarla gelecek."
    }
}

@MainActor
final class QuizSession: ObservableObject, Identifiable {

    /// `fullScreenCover(item:)` için kimlik. Her oturum ayrı bir nesnedir,
    /// böylece "Tekrar dene" yeni bir sunum başlatır.
    nonisolated let id = UUID()

    // ---------- Yayımlanan durum ----------
    @Published private(set) var current: QuizQuestion?
    @Published private(set) var outcome: AnswerOutcome?
    @Published private(set) var position: Int = 0
    @Published private(set) var total: Int = 0
    @Published private(set) var streak: Int = 0
    @Published private(set) var hintVisible = false
    @Published private(set) var summary: SessionSummary?

    var progress: Double { total > 0 ? Double(position) / Double(total) : 0 }

    // ---------- İç durum ----------
    private let deck: Deck
    private let store: ProgressStore
    private let options: SessionOptions
    private let today: Int

    private var queue: [Card] = []
    private var index = 0
    /// Yanlış bilinen kartlar oturumun sonuna eklenir — SM-2'nin
    /// "aynı oturumda tekrar gör" kuralının uygulaması.
    private var relearn: [Card] = []
    private var mistakes: [Card] = []
    private var seenMistakeIDs: Set<String> = []

    private var correctCount = 0
    private var wrongCount = 0
    private var bestStreak = 0
    private var hintUsedForCurrent = false
    private var questionStartedAt = Date()

    init(deck: Deck, store: ProgressStore, options: SessionOptions,
         today: Int = SM2Scheduler.dayIndex()) {
        self.deck = deck
        self.store = store
        self.options = options
        self.today = today
    }

    // ------------------------------------------------------------
    // Akış
    // ------------------------------------------------------------

    /// Oturumu kurar. Deste boşsa `false` döner.
    @discardableResult
    func start() -> Bool {
        queue = QueueBuilder.build(cards: deck.cards,
                                   records: store.snapshot.rec,
                                   filter: options.deck,
                                   size: options.length,
                                   today: today)
        guard !queue.isEmpty else { return false }
        index = 0
        total = queue.count
        position = 0
        correctCount = 0; wrongCount = 0; bestStreak = 0; streak = 0
        relearn = []; mistakes = []; seenMistakeIDs = []
        summary = nil
        presentCurrent()
        return true
    }

    /// Cevabı işler. İkinci kez çağrılırsa yok sayılır.
    func answer(index pickedIndex: Int) {
        guard let question = current, outcome == nil,
              question.options.indices.contains(pickedIndex) else { return }

        let picked = question.options[pickedIndex]
        let isCorrect = picked.id == question.card.id
        let elapsed = Date().timeIntervalSince(questionStartedAt)

        store.apply(answerFor: question.card,
                    correct: isCorrect,
                    seconds: elapsed,
                    hintUsed: hintUsedForCurrent,
                    today: today)

        if isCorrect {
            correctCount += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            store.registerStreak(streak)
        } else {
            wrongCount += 1
            streak = 0
            if seenMistakeIDs.insert(question.card.id).inserted {
                mistakes.append(question.card)
                relearn.append(question.card)
            }
        }

        let updated = store.record(for: question.card.id)
        let correctIndex = question.options.firstIndex { $0.id == question.card.id } ?? 0

        outcome = AnswerOutcome(question: question,
                                pickedIndex: pickedIndex,
                                correctIndex: correctIndex,
                                isCorrect: isCorrect,
                                nextIntervalDays: updated.iv,
                                easinessFactor: updated.ef,
                                hintUsed: hintUsedForCurrent)

        // Cevaptan sonra ikinci örnek cümle her hâlükârda görünür:
        // ipucu kullanılmadıysa öğrenme fırsatı, kullanıldıysa zaten açıktı.
        hintVisible = true
    }

    /// Sonraki karta geçer; kuyruk bittiyse oturumu kapatır.
    func advance() {
        guard outcome != nil else { return }
        index += 1
        position = min(index, total)
        presentCurrent()
    }

    /// Kullanıcı oturumu erken bitirirse.
    func quit() {
        if correctCount + wrongCount > 0 {
            finish()
        } else {
            summary = SessionSummary(correct: 0, wrong: 0, bestStreak: 0, mistakes: [])
        }
    }

    func revealHint() {
        guard outcome == nil, !hintUsedForCurrent else { return }
        hintUsedForCurrent = true
        hintVisible = true
    }

    /// İpucu bu soruda kullanıldı mı? (Cevap kartındaki not için.)
    var hintWasUsed: Bool { hintUsedForCurrent }

    // ------------------------------------------------------------
    // İç yardımcılar
    // ------------------------------------------------------------

    private func presentCurrent() {
        if index >= queue.count {
            if relearn.isEmpty {
                finish()
                return
            }
            // Yanlışları oturumun sonuna ekle ve devam et.
            queue += relearn.shuffled()
            relearn = []
            total = queue.count
        }

        let card = queue[index]
        let record = store.snapshot.rec[card.id]
        let direction: QuizDirection = options.direction == .both
            ? (Bool.random() ? .en2tr : .tr2en)
            : options.direction

        let distractors = DistractorGenerator.make(for: card,
                                                   in: deck.cards,
                                                   direction: direction,
                                                   count: 3)
        let options = ([card] + distractors).shuffled()

        current = QuizQuestion(id: "\(card.id)-\(index)",
                               card: card,
                               direction: direction,
                               options: options,
                               repetition: record?.n ?? 0,
                               isNew: (record?.seen ?? 0) == 0)
        outcome = nil
        hintUsedForCurrent = false
        hintVisible = false
        questionStartedAt = Date()
        position = min(index, max(total - 1, 0))
    }

    private func finish() {
        store.registerCompletedSession()
        current = nil
        summary = SessionSummary(correct: correctCount,
                                 wrong: wrongCount,
                                 bestStreak: bestStreak,
                                 mistakes: mistakes)
    }
}
