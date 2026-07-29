import XCTest
@testable import YDSKelimelerim

// ============================================================
// Oturum akışı
//
// Görünüm katmanı olmadan tüm oturum yaşam döngüsünü sınar:
// soru üretimi, cevap, yanlışların tekrar kuyruğa alınması, özet.
// ============================================================

@MainActor
final class QuizSessionTests: XCTestCase {

    private var fileURL: URL!
    private var store: ProgressStore!
    private var deck: Deck!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-test-\(UUID().uuidString).json")
        store = ProgressStore(fileURL: fileURL)
        deck = Self.makeDeck(count: 24)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    /// Çeldirici bulunabilmesi için hepsi aynı türden, farklı anlamlı.
    private static func makeDeck(count: Int) -> Deck {
        let cards = (0..<count).map { i in
            Card(id: "w\(i)", kind: .word, term: "term\(i)", pos: .verb,
                 meaning: "anlam\(i)", exampleEN: "They term\(i) it.",
                 exampleTR: "Onu yaparlar.", exampleEN2: "He term\(i)ed it.",
                 level: .basic)
        }
        return Deck(payload: DeckPayload(version: 1, generatedAt: "2026-07-29",
                                         wordCount: count, phrasalCount: 0,
                                         irregular: [:], cards: cards))
    }

    private func makeSession(length: Int = 5) -> QuizSession {
        QuizSession(deck: deck, store: store,
                    options: SessionOptions(deck: .mix, direction: .en2tr, length: length),
                    today: 20_000)
    }

    // ---------- Başlangıç ----------

    func testStartProducesFirstQuestion() {
        let session = makeSession()
        XCTAssertTrue(session.start())
        XCTAssertNotNil(session.current)
        XCTAssertEqual(session.total, 5)
    }

    func testEachQuestionHasFourOptions() {
        let session = makeSession()
        session.start()
        XCTAssertEqual(session.current?.options.count, 4)
    }

    func testCorrectAnswerIsAmongTheOptions() {
        let session = makeSession()
        session.start()
        let question = session.current!
        XCTAssertTrue(question.options.contains { $0.id == question.card.id })
    }

    func testStartReturnsFalseForEmptyDeck() {
        let empty = Deck(payload: DeckPayload(version: 1, generatedAt: "", wordCount: 0,
                                              phrasalCount: 0, irregular: [:], cards: []))
        let session = QuizSession(deck: empty, store: store,
                                  options: SessionOptions(), today: 20_000)
        XCTAssertFalse(session.start())
    }

    // ---------- Cevaplama ----------

    private func correctIndex(_ session: QuizSession) -> Int {
        let question = session.current!
        return question.options.firstIndex { $0.id == question.card.id }!
    }

    func testCorrectAnswerIncrementsStreak() {
        let session = makeSession()
        session.start()
        session.answer(index: correctIndex(session))

        XCTAssertEqual(session.streak, 1)
        XCTAssertEqual(session.outcome?.isCorrect, true)
    }

    func testWrongAnswerResetsStreak() {
        let session = makeSession()
        session.start()
        session.answer(index: correctIndex(session))
        session.advance()

        let wrong = (correctIndex(session) + 1) % 4
        session.answer(index: wrong)

        XCTAssertEqual(session.streak, 0)
        XCTAssertEqual(session.outcome?.isCorrect, false)
    }

    func testSecondAnswerIsIgnored() {
        let session = makeSession()
        session.start()
        let correct = correctIndex(session)
        session.answer(index: correct)
        let firstOutcome = session.outcome

        session.answer(index: (correct + 1) % 4)

        XCTAssertEqual(session.outcome?.pickedIndex, firstOutcome?.pickedIndex,
                       "cevap kilitlendikten sonra değişmemeli")
    }

    func testAdvanceRequiresAnAnswer() {
        let session = makeSession()
        session.start()
        let first = session.current?.card.id

        session.advance()

        XCTAssertEqual(session.current?.card.id, first, "cevapsız ilerlenmemeli")
    }

    // ---------- İpucu ----------

    func testHintIsRecordedAndCapsQuality() {
        let session = makeSession()
        session.start()
        session.revealHint()
        XCTAssertTrue(session.hintVisible)

        session.answer(index: correctIndex(session))
        XCTAssertEqual(session.outcome?.hintUsed, true)
        // İpucuyla verilen doğru cevapta aralık 1 günden fazla uzamaz.
        XCTAssertEqual(session.outcome?.nextIntervalDays, 1)
    }

    func testHintCannotBeUsedAfterAnswering() {
        let session = makeSession()
        session.start()
        session.answer(index: correctIndex(session))
        session.revealHint()
        XCTAssertEqual(session.outcome?.hintUsed, false)
    }

    // ---------- Yanlışların tekrarı ----------

    func testWrongCardsAreAskedAgainBeforeTheSessionEnds() {
        let session = makeSession(length: 3)
        session.start()

        // Hepsini yanlış cevapla.
        for _ in 0..<3 {
            session.answer(index: (correctIndex(session) + 1) % 4)
            session.advance()
        }

        XCTAssertNil(session.summary, "yanlışlar tekrar sorulmadan oturum bitmemeli")
        XCTAssertEqual(session.total, 6, "üç yanlış kuyruğun sonuna eklenmeli")
    }

    func testSessionFinishesWhenAllAnswersAreCorrect() {
        let session = makeSession(length: 3)
        session.start()

        for _ in 0..<3 {
            session.answer(index: correctIndex(session))
            session.advance()
        }

        let summary = session.summary
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.correct, 3)
        XCTAssertEqual(summary?.wrong, 0)
        XCTAssertEqual(summary?.percent, 100)
    }

    // ---------- Özet ----------

    func testSummaryListsEachMistakeOnce() {
        let session = makeSession(length: 2)
        session.start()

        // İki soruyu da yanlış, sonra tekrar turunda da yanlış.
        for _ in 0..<4 {
            guard session.current != nil else { break }
            session.answer(index: (correctIndex(session) + 1) % 4)
            session.advance()
        }

        // Tekrar turu da bittiğinde özet gelir; yanlış listesi
        // aynı kartı iki kez içermemeli.
        if let summary = session.summary {
            let ids = summary.mistakes.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count)
        }
    }

    func testQuitBeforeAnsweringProducesEmptySummary() {
        let session = makeSession()
        session.start()
        session.quit()

        XCTAssertEqual(session.summary?.total, 0)
    }

    func testQuitAfterAnsweringKeepsProgress() {
        let session = makeSession()
        session.start()
        session.answer(index: correctIndex(session))
        session.quit()

        XCTAssertEqual(session.summary?.correct, 1)
        XCTAssertEqual(store.snapshot.totalAns, 1, "verilen cevap kaydedilmiş olmalı")
    }

    // ---------- Yön ----------

    func testDirectionIsAppliedToThePrompt() {
        let session = QuizSession(deck: deck, store: store,
                                  options: SessionOptions(deck: .mix, direction: .tr2en, length: 3),
                                  today: 20_000)
        session.start()
        let question = session.current!

        XCTAssertEqual(question.prompt, question.card.meaning)
        XCTAssertFalse(question.promptIsEnglish)
        // Şıklar İngilizce olmalı.
        XCTAssertEqual(question.label(for: question.card), question.card.term)
    }
}
