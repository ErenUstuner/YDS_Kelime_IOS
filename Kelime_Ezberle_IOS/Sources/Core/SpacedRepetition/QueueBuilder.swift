import Foundation

// ============================================================
// Oturum kuyruğu
//
// Hangi kartların, hangi sırayla sorulacağına karar verir.
// Kural sırası önemli: önce vadesi gelmiş tekrarlar, sonra yeni kartlar.
// Tersi yapılırsa kullanıcı sürekli yeni kelime görür ve eskiler unutulur —
// aralıklı tekrarın tüm faydası kaybolur.
// ============================================================

/// Hangi destenin çalışılacağı.
enum DeckFilter: String, CaseIterable, Identifiable, Sendable {
    case mix
    case word
    case phrasal

    var id: String { rawValue }

    var turkishLabel: String {
        switch self {
        case .mix: return "Karışık"
        case .word: return "Kelimeler"
        case .phrasal: return "Phrasal verb"
        }
    }
}

enum QueueBuilder {

    /// Oturumda sorulacak kartları seçer ve karıştırır.
    ///
    /// - Parameters:
    ///   - cards: tüm deste
    ///   - records: kart kimliği -> tekrar kaydı
    ///   - filter: deste süzgeci
    ///   - size: oturum uzunluğu
    ///   - today: gün indeksi (test edilebilirlik için dışarıdan verilir)
    ///   - shuffler: karıştırma işlevi (testte deterministik yapılabilir)
    static func build(cards: [Card],
                      records: [String: ReviewRecord],
                      filter: DeckFilter,
                      size: Int,
                      today: Int,
                      shuffler: ([Card]) -> [Card] = { $0.shuffled() }) -> [Card] {

        let pool = cards.filter { filter == .mix || $0.kind.rawValue == filter.rawValue }
        guard !pool.isEmpty else { return [] }

        var due: [Card] = []
        var fresh: [Card] = []

        for card in pool {
            guard let r = records[card.id], r.seen > 0 else {
                fresh.append(card)
                continue
            }
            if r.due <= today { due.append(card) }
        }

        // Vadesi en çok geçmiş, en zorlanılan kart önce.
        due.sort { a, b in
            let ra = records[a.id] ?? .empty
            let rb = records[b.id] ?? .empty
            if ra.due != rb.due { return ra.due < rb.due }
            return ra.ef < rb.ef
        }

        // Yeni kartlar kolaydan zora. Aynı seviyedekiler arasında sıra
        // rastgele: kullanıcı her oturumda alfabetik aynı diziyi görmesin.
        fresh = shuffler(fresh).sorted { $0.level < $1.level }

        var queue = Array(due.prefix(size))
        if queue.count < size {
            queue += fresh.prefix(size - queue.count)
        }

        // Her şey ileri tarihliyse (kullanıcı günü bitirmişse) yine de
        // çalışabilsin: vadesi en yakın kartlarla erken tekrar oturumu aç.
        if queue.isEmpty {
            queue = Array(pool
                .sorted { (records[$0.id]?.due ?? 0) < (records[$1.id]?.due ?? 0) }
                .prefix(size))
        }

        return shuffler(queue)
    }

    /// Ana ekran ve widget için özet sayaçlar.
    static func counts(cards: [Card],
                       records: [String: ReviewRecord],
                       today: Int) -> (due: Int, fresh: Int, studied: Int) {
        var due = 0, fresh = 0
        for card in cards {
            guard let r = records[card.id], r.seen > 0 else {
                fresh += 1
                continue
            }
            if r.due <= today { due += 1 }
        }
        return (due, fresh, cards.count - fresh)
    }
}
