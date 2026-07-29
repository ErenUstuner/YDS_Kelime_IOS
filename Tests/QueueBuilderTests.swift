import XCTest
@testable import YDSKelimelerim

// ============================================================
// Oturum kuyruğu
//
// Kuyruk sırası aralıklı tekrarın işe yaramasını belirleyen tek şey.
// Karıştırma testlerde devre dışı bırakılıyor (birim işlev veriliyor)
// ki sıra deterministik doğrulanabilsin.
// ============================================================

final class QueueBuilderTests: XCTestCase {

    private let today = 20_000
    private let noShuffle: ([Card]) -> [Card] = { $0 }

    // ---------- Yardımcılar ----------

    private func card(_ id: String,
                      kind: CardKind = .word,
                      level: WordLevel = .basic,
                      pos: PartOfSpeech = .verb) -> Card {
        Card(id: id, kind: kind, term: "term-\(id)", pos: pos,
             meaning: "anlam-\(id)", exampleEN: "Example \(id).",
             exampleTR: "Örnek \(id).", exampleEN2: "Second \(id).", level: level)
    }

    private func seen(due: Int, ef: Double = 2.5) -> ReviewRecord {
        ReviewRecord(ef: ef, iv: 3, n: 2, due: due, seen: 4, ok: 3, bad: 1, last: due - 3)
    }

    // ---------- Öncelik ----------

    func testDueCardsComeBeforeNewCards() {
        let cards = [card("w0"), card("w1"), card("w2")]
        let records = ["w2": seen(due: today - 5)]

        let queue = QueueBuilder.build(cards: cards, records: records, filter: .mix,
                                       size: 3, today: today, shuffler: noShuffle)

        XCTAssertEqual(queue.first?.id, "w2", "vadesi gelen kart önce sorulmalı")
    }

    func testMostOverdueCardComesFirst() {
        let cards = [card("w0"), card("w1"), card("w2")]
        let records = [
            "w0": seen(due: today - 1),
            "w1": seen(due: today - 30),
            "w2": seen(due: today - 10),
        ]

        let queue = QueueBuilder.build(cards: cards, records: records, filter: .mix,
                                       size: 3, today: today, shuffler: noShuffle)

        XCTAssertEqual(queue.map(\.id), ["w1", "w2", "w0"])
    }

    func testTiedDueDatesAreOrderedByEasinessFactor() {
        let cards = [card("w0"), card("w1")]
        let records = [
            "w0": seen(due: today - 2, ef: 2.6),
            "w1": seen(due: today - 2, ef: 1.6),
        ]

        let queue = QueueBuilder.build(cards: cards, records: records, filter: .mix,
                                       size: 2, today: today, shuffler: noShuffle)

        XCTAssertEqual(queue.first?.id, "w1", "daha zorlanılan kart önce gelmeli")
    }

    func testFutureCardsAreNotIncludedWhenOthersAreAvailable() {
        let cards = [card("w0"), card("w1")]
        let records = [
            "w0": seen(due: today + 10),      // ileri tarihli
            "w1": seen(due: today - 1),       // vadesi gelmiş
        ]

        let queue = QueueBuilder.build(cards: cards, records: records, filter: .mix,
                                       size: 5, today: today, shuffler: noShuffle)

        XCTAssertEqual(queue.map(\.id), ["w1"])
    }

    // ---------- Yeni kart sıralaması ----------

    func testNewCardsAreOrderedEasiestFirst() {
        let cards = [card("w0", level: .advanced),
                     card("w1", level: .basic),
                     card("w2", level: .intermediate)]

        let queue = QueueBuilder.build(cards: cards, records: [:], filter: .mix,
                                       size: 3, today: today, shuffler: noShuffle)

        XCTAssertEqual(queue.map(\.id), ["w1", "w2", "w0"])
    }

    // ---------- Süzgeç ----------

    func testDeckFilterExcludesOtherKinds() {
        let cards = [card("w0"), card("p0", kind: .phrasal, pos: .phrasal)]

        let words = QueueBuilder.build(cards: cards, records: [:], filter: .word,
                                       size: 10, today: today, shuffler: noShuffle)
        let phrasals = QueueBuilder.build(cards: cards, records: [:], filter: .phrasal,
                                          size: 10, today: today, shuffler: noShuffle)

        XCTAssertEqual(words.map(\.id), ["w0"])
        XCTAssertEqual(phrasals.map(\.id), ["p0"])
    }

    func testEmptyPoolReturnsEmptyQueue() {
        let queue = QueueBuilder.build(cards: [], records: [:], filter: .mix,
                                       size: 10, today: today, shuffler: noShuffle)
        XCTAssertTrue(queue.isEmpty)
    }

    // ---------- Sınırlar ----------

    func testQueueNeverExceedsRequestedSize() {
        let cards = (0..<50).map { card("w\($0)") }
        let queue = QueueBuilder.build(cards: cards, records: [:], filter: .mix,
                                       size: 20, today: today, shuffler: noShuffle)
        XCTAssertEqual(queue.count, 20)
    }

    func testAllCardsScheduledAheadStillProduceASession() {
        // Kullanıcı günü bitirmişse bile "çalış" düğmesi boş dönmemeli.
        let cards = (0..<5).map { card("w\($0)") }
        let records = Dictionary(uniqueKeysWithValues: cards.map {
            ($0.id, seen(due: today + 7))
        })

        let queue = QueueBuilder.build(cards: cards, records: records, filter: .mix,
                                       size: 3, today: today, shuffler: noShuffle)

        XCTAssertEqual(queue.count, 3, "erken tekrar oturumu açılmalı")
    }

    // ---------- Sayaçlar ----------

    func testCountsSplitDueNewAndStudied() {
        let cards = [card("w0"), card("w1"), card("w2")]
        let records = [
            "w0": seen(due: today - 1),
            "w1": seen(due: today + 5),
        ]

        let counts = QueueBuilder.counts(cards: cards, records: records, today: today)

        XCTAssertEqual(counts.due, 1)
        XCTAssertEqual(counts.fresh, 1)
        XCTAssertEqual(counts.studied, 2)
    }
}
