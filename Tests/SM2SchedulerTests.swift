import XCTest
@testable import YDSKelimelerim

// ============================================================
// SM-2 motoru
//
// Beklenen değerler web sürümündeki motordan alındı. Bu testlerin
// amacı iki platformun aynı takvimi üretmesini garanti altına almak:
// kullanıcı ilerlemesini taşıdığında tekrar günleri kaymamalı.
// ============================================================

final class SM2SchedulerTests: XCTestCase {

    private let today = 20_000

    // ---------- Aralık ilerlemesi ----------

    func testFirstCorrectAnswerSchedulesNextDay() {
        let result = SM2Scheduler.apply(.empty, quality: 5, today: today)
        XCTAssertEqual(result.iv, 1)
        XCTAssertEqual(result.n, 1)
        XCTAssertEqual(result.due, today + 1)
    }

    func testSecondCorrectAnswerSchedulesThreeDaysLater() {
        var record = SM2Scheduler.apply(.empty, quality: 5, today: today)
        record = SM2Scheduler.apply(record, quality: 5, today: today + 1)
        XCTAssertEqual(record.iv, 3)
        XCTAssertEqual(record.n, 2)
    }

    func testThirdAnswerMultipliesByEasinessFactor() {
        var record = ReviewRecord.empty
        for step in 0..<3 {
            record = SM2Scheduler.apply(record, quality: 5, today: today + step)
        }
        // n=2 iken iv=3; üçüncü doğruda iv = round(3 * ef)
        // ef her 5'te 0.1 artar: 2.5 -> 2.6 -> 2.7
        XCTAssertEqual(record.n, 3)
        XCTAssertEqual(record.iv, Int((3.0 * 2.7).rounded()))
    }

    // ---------- Yanlış cevap ----------

    func testWrongAnswerResetsIntervalButKeepsHistory() {
        var record = ReviewRecord.empty
        for step in 0..<3 {
            record = SM2Scheduler.apply(record, quality: 5, today: today + step)
        }
        let beforeEF = record.ef

        record = SM2Scheduler.apply(record, quality: 1, today: today + 10)

        XCTAssertEqual(record.n, 0, "yanlış cevapta üst üste doğru sayacı sıfırlanır")
        XCTAssertEqual(record.iv, 0, "kart aynı oturumda tekrar sorulmalı")
        XCTAssertEqual(record.due, today + 10)
        XCTAssertLessThan(record.ef, beforeEF, "kolaylık katsayısı düşmeli")
    }

    func testEasinessFactorNeverDropsBelowFloor() {
        var record = ReviewRecord.empty
        // Arka arkaya 30 yanlış: taban değerin altına inmemeli.
        for step in 0..<30 {
            record = SM2Scheduler.apply(record, quality: 0, today: today + step)
        }
        XCTAssertGreaterThanOrEqual(record.ef, 1.3)
    }

    func testPerfectAnswersIncreaseEasinessFactor() {
        var record = ReviewRecord.empty
        for step in 0..<5 {
            record = SM2Scheduler.apply(record, quality: 5, today: today + step)
        }
        XCTAssertGreaterThan(record.ef, 2.5)
    }

    // ---------- Kalite notu türetme ----------

    func testFastCorrectAnswerScoresFive() {
        XCTAssertEqual(SM2Scheduler.quality(correct: true, seconds: 2.1, hintUsed: false), 5)
    }

    func testSlowCorrectAnswerScoresThree() {
        XCTAssertEqual(SM2Scheduler.quality(correct: true, seconds: 15, hintUsed: false), 3)
    }

    func testHintCapsQualityAtThree() {
        // İpucuyla verilen hızlı cevap bile tam hatırlama sayılmaz.
        XCTAssertEqual(SM2Scheduler.quality(correct: true, seconds: 1.0, hintUsed: true), 3)
    }

    func testWrongAnswerScoresBelowThree() {
        XCTAssertLessThan(SM2Scheduler.quality(correct: false, seconds: 2, hintUsed: false), 3)
        XCTAssertLessThan(SM2Scheduler.quality(correct: false, seconds: 20, hintUsed: false), 3)
    }

    func testHintedCorrectAnswerGrowsIntervalLessThanUnaided() {
        var aided = ReviewRecord.empty
        var unaided = ReviewRecord.empty
        for step in 0..<4 {
            aided = SM2Scheduler.apply(aided,
                                       quality: SM2Scheduler.quality(correct: true, seconds: 2, hintUsed: true),
                                       today: today + step)
            unaided = SM2Scheduler.apply(unaided,
                                         quality: SM2Scheduler.quality(correct: true, seconds: 2, hintUsed: false),
                                         today: today + step)
        }
        XCTAssertLessThan(aided.iv, unaided.iv,
                          "ipucu kullanılan kart daha sık sorulmaya devam etmeli")
    }

    // ---------- Gün indeksi ----------

    func testDayIndexMatchesWebFormula() {
        // Web: Math.floor(Date.now() / 864e5)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(SM2Scheduler.dayIndex(date), Int(floor(1_700_000_000.0 / 86_400)))
    }

    func testDayIndexIncrementsOncePerDay() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(SM2Scheduler.dayIndex(base.addingTimeInterval(86_400)),
                       SM2Scheduler.dayIndex(base) + 1)
    }

    // ---------- Kart aşaması ----------

    func testNewCardState() {
        XCTAssertEqual(CardState.of(nil), .new)
        XCTAssertEqual(CardState.of(.empty), .new)
    }

    func testHardCardState() {
        let record = ReviewRecord(ef: 1.8, iv: 1, n: 1, due: 0, seen: 4, ok: 1, bad: 3, last: 0)
        XCTAssertEqual(CardState.of(record), .hard)
    }

    func testKnownCardState() {
        let record = ReviewRecord(ef: 2.6, iv: 21, n: 4, due: 0, seen: 5, ok: 5, bad: 0, last: 0)
        XCTAssertEqual(CardState.of(record), .known)
    }

    func testLearningCardState() {
        let record = ReviewRecord(ef: 2.5, iv: 3, n: 2, due: 0, seen: 2, ok: 2, bad: 0, last: 0)
        XCTAssertEqual(CardState.of(record), .learning)
    }
}
