import XCTest
@testable import YDSKelimelerim

// ============================================================
// Cümlede hedef ifadeyi bulma
//
// Bu sınıf hem vurgulamayı hem TR→EN yönündeki boşluk doldurmayı
// besliyor. Yanlış eşleşme, cevabı ele veren bir ipucu demek —
// o yüzden hem bulması hem BULMAMASI gerekenler test ediliyor.
// ============================================================

final class SentenceMatcherTests: XCTestCase {

    private let matcher = SentenceMatcher(irregular: [
        "arise": ["arose", "arisen"],
        "bear": ["bore", "borne"],
        "give": ["gave", "given"],
    ])

    private func matchedText(_ term: String, _ sentence: String) -> [String] {
        matcher.matches(term: term, in: sentence).map { String(sentence[$0]) }
    }

    // ---------- Düzenli çekimler ----------

    func testMatchesBaseForm() {
        XCTAssertEqual(matchedText("abandon", "They abandon the plan."), ["abandon"])
    }

    func testMatchesPastTense() {
        XCTAssertEqual(matchedText("abandon", "The crew abandoned the ship."), ["abandoned"])
    }

    func testMatchesProgressiveForm() {
        XCTAssertEqual(matchedText("abandon", "They are abandoning the project."), ["abandoning"])
    }

    func testMatchesConsonantPlusYVerbs() {
        // apply -> applies / applied
        XCTAssertEqual(matchedText("apply", "The rule applies to everyone."), ["applies"])
        XCTAssertEqual(matchedText("apply", "She applied last week."), ["applied"])
    }

    func testMatchesSilentEVerbs() {
        // advocate -> advocated / advocating
        XCTAssertEqual(matchedText("advocate", "Economists advocated a slower pace."), ["advocated"])
    }

    // ---------- Düzensiz fiiller ----------

    func testMatchesIrregularPastForm() {
        XCTAssertEqual(matchedText("arise", "A problem arose during the test."), ["arose"])
    }

    func testMatchesIrregularParticiple() {
        XCTAssertEqual(matchedText("give", "The prize was given to her."), ["given"])
    }

    // ---------- Phrasal verb'ler ----------

    func testMatchesPhrasalVerbWrittenTogether() {
        XCTAssertEqual(matchedText("account for",
                                   "Renewables account for a third of output."),
                       ["account for"])
    }

    func testMatchesPhrasalVerbWithObjectInBetween() {
        let found = matchedText("put off", "They put the meeting off until Friday.")
        XCTAssertEqual(found.count, 1)
        XCTAssertTrue(found[0].contains("put"))
        XCTAssertTrue(found[0].contains("off"))
    }

    func testParticleIsNotInflected() {
        // "on" edatı; "onto" ya da "online" ile eşleşmemeli.
        XCTAssertTrue(matchedText("carry on", "They carry online surveys.").isEmpty)
    }

    // ---------- Yanlış eşleşme olmamalı ----------

    func testDoesNotMatchUnrelatedWord() {
        XCTAssertTrue(matchedText("abandon", "The band played all night.").isEmpty)
    }

    func testRespectsWordBoundaries() {
        // "act" ararken "contract" içindeki act yakalanmamalı.
        XCTAssertTrue(matchedText("act", "They signed the contract.").isEmpty)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(matchedText("abandon", "Abandoned buildings line the street."),
                       ["Abandoned"])
    }

    // ---------- Boşluk doldurma ----------

    func testClozeReplacesTargetWithBlank() {
        let result = matcher.cloze(term: "abandon", in: "The crew abandoned the ship.")
        XCTAssertEqual(result, "The crew ______ the ship.")
    }

    func testClozeReturnsOriginalWhenNoMatch() {
        let sentence = "Nothing to see here."
        XCTAssertEqual(matcher.cloze(term: "abandon", in: sentence), sentence)
    }

    func testClozeHandlesMultipleOccurrences() {
        let result = matcher.cloze(term: "abandon",
                                   in: "They abandon it, then abandoned it again.")
        XCTAssertEqual(result, "They ______ it, then ______ it again.")
    }

    func testClozeNeverLeavesTheAnswerVisible() {
        // TR→EN yönünün tüm anlamı bu: cevap cümlede görünmemeli.
        let sentence = "The government decided to abolish the outdated tax law."
        let result = matcher.cloze(term: "abolish", in: sentence)
        XCTAssertFalse(result.lowercased().contains("abolish"))
    }

    // ---------- Dayanıklılık ----------

    func testHandlesRegexSpecialCharactersInTerm() {
        // Desen kaçırma yapılmazsa burada çalışma zamanı hatası olurdu.
        XCTAssertNoThrow(matcher.matches(term: "a (b)", in: "Some sentence."))
    }

    func testHandlesEmptyTerm() {
        XCTAssertTrue(matcher.matches(term: "", in: "Some sentence.").isEmpty)
    }
}
