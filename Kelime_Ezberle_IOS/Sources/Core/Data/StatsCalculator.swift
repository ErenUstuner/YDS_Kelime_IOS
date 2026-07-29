import Foundation

// ============================================================
// İstatistik hesaplayıcı
//
// Saf fonksiyonlar: aynı girdi, aynı çıktı. İstatistik ekranı ve
// widget aynı hesabı kullanır, iki yerde farklı sayı görünmez.
// ============================================================

struct StudyStats: Sendable {
    var stateCounts: [CardState: Int]
    var totalCards: Int
    var studiedCards: Int
    var dueToday: Int
    var totalAnswers: Int
    var accuracyPercent: Int?
    var bestStreak: Int
    var sessions: Int
    var studiedDays: Int
    /// Son 30 günün çalışıldı/çalışılmadı dizisi (grafiği besler).
    var recentDays: [Bool]

    func share(of state: CardState) -> Double {
        guard totalCards > 0 else { return 0 }
        return Double(stateCounts[state] ?? 0) / Double(totalCards)
    }
}

enum StatsCalculator {

    static func compute(deck: Deck,
                        snapshot: ProgressSnapshot,
                        today: Int = SM2Scheduler.dayIndex()) -> StudyStats {

        var counts: [CardState: Int] = [:]
        var dueToday = 0

        for card in deck.cards {
            let record = snapshot.rec[card.id]
            counts[CardState.of(record), default: 0] += 1
            if let r = record, r.seen > 0, r.due <= today { dueToday += 1 }
        }

        let newCount = counts[.new] ?? 0
        let accuracy = snapshot.totalAns > 0
            ? Int((Double(snapshot.totalOk) / Double(snapshot.totalAns) * 100).rounded())
            : nil

        let studiedSet = Set(snapshot.days)
        let recent = (0..<30).reversed().map { studiedSet.contains(today - $0) }

        return StudyStats(stateCounts: counts,
                          totalCards: deck.cards.count,
                          studiedCards: deck.cards.count - newCount,
                          dueToday: dueToday,
                          totalAnswers: snapshot.totalAns,
                          accuracyPercent: accuracy,
                          bestStreak: snapshot.streakBest,
                          sessions: snapshot.sessions,
                          studiedDays: snapshot.days.count,
                          recentDays: recent)
    }

    /// En çok zorlanılan kartlar. Önce en çok yanlış yapılan, eşitlikte
    /// kolaylık katsayısı düşük olan (yani daha çok emek isteyen) önde.
    static func hardestCards(deck: Deck, snapshot: ProgressSnapshot, limit: Int = 12) -> [(Card, ReviewRecord)] {
        deck.cards
            .compactMap { card -> (Card, ReviewRecord)? in
                guard let r = snapshot.rec[card.id], r.bad > 0 else { return nil }
                return (card, r)
            }
            .sorted { a, b in
                if a.1.bad != b.1.bad { return a.1.bad > b.1.bad }
                return a.1.ef < b.1.ef
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Kesintisiz çalışma serisi (bugünden geriye).
    static func currentDayStreak(days: [Int], today: Int) -> Int {
        let set = Set(days)
        // Bugün henüz çalışılmadıysa seriyi dünden saymaya başla —
        // sabah uygulamayı açan kullanıcı serisini sıfırlanmış görmesin.
        var cursor = set.contains(today) ? today : today - 1
        guard set.contains(cursor) else { return 0 }
        var streak = 0
        while set.contains(cursor) {
            streak += 1
            cursor -= 1
        }
        return streak
    }
}
