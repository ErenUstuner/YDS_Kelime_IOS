import XCTest
@testable import YDSKelimelerim

// ============================================================
// Veri bütünlüğü
//
// deck.json elle yazılmıyor, üretiliyor — ama üretim betiği bozulursa
// hata sessizce uygulamaya sızar. Bu testler paketteki veriyi her
// derlemede denetler.
// ============================================================

final class DeckIntegrityTests: XCTestCase {

    /// Deste bir kez yüklenir: 781 kartı her testte yeniden çözümlemek
    /// test süresini gereksiz uzatırdı.
    private static var loaded: Deck?

    override class func setUp() {
        super.setUp()
        loaded = try? DeckLoader.load(from: Bundle(for: DeckIntegrityTests.self))
    }

    private func deck() throws -> Deck {
        try XCTUnwrap(Self.loaded, "deck.json test paketinde bulunamadı")
    }

    // ---------- Yükleme ----------

    func testDeckLoads() throws {
        XCTAssertGreaterThan(try deck().cards.count, 700)
    }

    func testDeckHasBothKinds() throws {
        XCTAssertFalse(try deck().words.isEmpty)
        XCTAssertFalse(try deck().phrasals.isEmpty)
    }

    // ---------- Kimlikler ----------

    func testCardIDsAreUnique() throws {
        let ids = try deck().cards.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "yinelenen kart kimliği var")
    }

    func testCardIDsFollowWebNamingScheme() throws {
        // İlerleme dosyasının web ile uyumlu kalması buna bağlı.
        for card in try deck().cards {
            let prefix = card.kind == .word ? "w" : "p"
            XCTAssertTrue(card.id.hasPrefix(prefix), "beklenmeyen kimlik: \(card.id)")
            XCTAssertNotNil(Int(card.id.dropFirst()), "kimlik sayı ile bitmeli: \(card.id)")
        }
    }

    func testTermsAreUniqueCaseInsensitively() throws {
        let terms = try deck().cards.map { $0.term.lowercased() }
        XCTAssertEqual(Set(terms).count, terms.count, "aynı ifade iki kez var")
    }

    // ---------- Alan doğruluğu ----------

    func testNoEmptyFields() throws {
        for card in try deck().cards {
            XCTAssertFalse(card.term.trimmingCharacters(in: .whitespaces).isEmpty, card.id)
            XCTAssertFalse(card.meaning.trimmingCharacters(in: .whitespaces).isEmpty, card.id)
            XCTAssertFalse(card.exampleEN.trimmingCharacters(in: .whitespaces).isEmpty, card.id)
            XCTAssertFalse(card.exampleTR.trimmingCharacters(in: .whitespaces).isEmpty, card.id)
            XCTAssertFalse(card.exampleEN2.trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(card.term): ikinci örnek cümle eksik — ipucu kutusu boş kalır")
        }
    }

    func testSecondExampleDiffersFromFirst() throws {
        for card in try deck().cards {
            XCTAssertNotEqual(card.exampleEN.trimmingCharacters(in: .whitespaces),
                              card.exampleEN2.trimmingCharacters(in: .whitespaces),
                              "\(card.term): iki örnek cümle aynı")
        }
    }

    func testSentencesEndWithPunctuation() throws {
        for card in try deck().cards {
            for sentence in [card.exampleEN, card.exampleTR, card.exampleEN2] {
                let last = sentence.trimmingCharacters(in: .whitespaces).last
                XCTAssertTrue(last == "." || last == "!" || last == "?",
                              "\(card.term): cümle noktalama ile bitmiyor -> \(sentence)")
            }
        }
    }

    func testPhrasalCardsUsePhrasalPartOfSpeech() throws {
        for card in try deck().phrasals {
            XCTAssertEqual(card.pos, .phrasal, card.term)
        }
    }

    func testWordCardsDoNotUsePhrasalPartOfSpeech() throws {
        for card in try deck().words {
            XCTAssertNotEqual(card.pos, .phrasal, card.term)
        }
    }

    // ---------- Sınav yapılabilirliği ----------

    func testEveryCardHasEnoughDistractors() throws {
        // Dört şıklı soru için her kartın 3 çeldiriciye ihtiyacı var.
        // Bir kart yeterli çeldirici bulamazsa soru üç şıkla çizilir
        // ve kullanıcı bunu bir hata olarak görür.
        let loadedDeck = try deck()
        for card in loadedDeck.cards {
            for direction in [QuizDirection.en2tr, .tr2en] {
                let distractors = DistractorGenerator.make(for: card,
                                                           in: loadedDeck.cards,
                                                           direction: direction,
                                                           count: 3)
                XCTAssertEqual(distractors.count, 3,
                               "\(card.term) (\(direction.rawValue)): yeterli çeldirici yok")
            }
        }
    }

    func testDistractorsNeverRepeatTheAnswer() throws {
        let loadedDeck = try deck()
        for card in loadedDeck.cards.prefix(120) {
            let distractors = DistractorGenerator.make(for: card, in: loadedDeck.cards,
                                                       direction: .en2tr, count: 3)
            XCTAssertFalse(distractors.contains { $0.id == card.id })
            XCTAssertFalse(distractors.contains { $0.canonicalMeaning == card.canonicalMeaning },
                           "\(card.term): aynı anlama gelen çeldirici üretildi")
        }
    }

    // ---------- Örnek cümlelerde hedef kelime ----------

    func testExampleSentencesContainTheTargetTerm() throws {
        let loadedDeck = try deck()
        let matcher = SentenceMatcher(irregular: loadedDeck.irregular)
        var misses: [String] = []

        for card in loadedDeck.cards {
            // Kısa ifadeler (up, on) tesadüfi eşleşir; web tarafındaki
            // doğrulama da 3 harften kısa gövdeleri atlıyor.
            guard card.term.count > 3 else { continue }
            if matcher.matches(term: card.term, in: card.exampleEN).isEmpty {
                misses.append("\(card.term) -> \(card.exampleEN)")
            }
        }
        XCTAssertTrue(misses.isEmpty,
                      "hedef ifade örnek cümlede bulunamadı:\n" + misses.joined(separator: "\n"))
    }
}
