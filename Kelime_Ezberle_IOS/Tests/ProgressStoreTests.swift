import XCTest
@testable import YDSKelimelerim

// ============================================================
// İlerleme deposu
//
// Her test kendi geçici dosyasıyla çalışır: testler birbirinin
// verisini görmez ve gerçek kullanıcı ilerlemesine dokunulmaz.
// ============================================================

@MainActor
final class ProgressStoreTests: XCTestCase {

    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func makeStore() -> ProgressStore { ProgressStore(fileURL: fileURL) }

    private var sampleCard: Card {
        Card(id: "w0", kind: .word, term: "abandon", pos: .verb,
             meaning: "terk etmek", exampleEN: "They abandon it.",
             exampleTR: "Onu terk ederler.", exampleEN2: "He abandoned it.", level: .basic)
    }

    // ---------- Temel davranış ----------

    func testStartsEmpty() {
        let store = makeStore()
        XCTAssertTrue(store.snapshot.rec.isEmpty)
        XCTAssertNil(store.accuracyPercent)
    }

    func testCorrectAnswerUpdatesCounters() {
        let store = makeStore()
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 100)

        let record = store.record(for: "w0")
        XCTAssertEqual(record.seen, 1)
        XCTAssertEqual(record.ok, 1)
        XCTAssertEqual(record.bad, 0)
        XCTAssertEqual(store.snapshot.totalAns, 1)
        XCTAssertEqual(store.snapshot.totalOk, 1)
        XCTAssertEqual(store.accuracyPercent, 100)
    }

    func testWrongAnswerUpdatesCounters() {
        let store = makeStore()
        store.apply(answerFor: sampleCard, correct: false, seconds: 8, hintUsed: false, today: 100)

        let record = store.record(for: "w0")
        XCTAssertEqual(record.bad, 1)
        XCTAssertEqual(record.iv, 0, "yanlış cevapta kart aynı oturumda tekrar sorulur")
        XCTAssertEqual(store.accuracyPercent, 0)
    }

    func testStudiedDaysAreRecordedOncePerDay() {
        let store = makeStore()
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 100)
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 100)
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 101)

        XCTAssertEqual(store.snapshot.days, [100, 101])
    }

    func testBestStreakOnlyGrows() {
        let store = makeStore()
        store.registerStreak(7)
        store.registerStreak(3)
        XCTAssertEqual(store.snapshot.streakBest, 7)
    }

    func testResetClearsEverything() {
        let store = makeStore()
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 100)
        store.registerCompletedSession()
        store.reset()

        XCTAssertTrue(store.snapshot.rec.isEmpty)
        XCTAssertEqual(store.snapshot.totalAns, 0)
        XCTAssertEqual(store.snapshot.sessions, 0)
    }

    // ---------- Kalıcılık ----------

    func testProgressSurvivesRestart() {
        let store = makeStore()
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 100)

        // Yazma arka planda; dosyanın oluşmasını bekle.
        let expectation = expectation(description: "diske yazıldı")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)

        let reopened = ProgressStore(fileURL: fileURL)
        XCTAssertEqual(reopened.record(for: "w0").seen, 1)
    }

    // ---------- İçe / dışa aktarma ----------

    func testExportImportRoundTrip() throws {
        let store = makeStore()
        store.apply(answerFor: sampleCard, correct: true, seconds: 2, hintUsed: false, today: 100)
        store.registerStreak(5)
        let data = try store.exportData()

        let fresh = ProgressStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-fresh-\(UUID().uuidString).json"))
        try fresh.importData(data)

        XCTAssertEqual(fresh.record(for: "w0").seen, 1)
        XCTAssertEqual(fresh.snapshot.streakBest, 5)
        XCTAssertEqual(fresh.snapshot.totalAns, 1)
    }

    func testImportsWebExportFormat() throws {
        // Sitedeki "İlerlemeyi dışa aktar" düğmesinin ürettiği biçim.
        let json = """
        {"v":1,"saved":"2026-01-01T00:00:00Z",
         "data":{"w0":{"ef":2.4,"iv":6,"n":3,"due":19999,"seen":5,"ok":4,"bad":1,"last":19993}}}
        """
        let store = makeStore()
        try store.importData(Data(json.utf8))

        let record = store.record(for: "w0")
        XCTAssertEqual(record.seen, 5)
        XCTAssertEqual(record.iv, 6)
        XCTAssertEqual(record.ef, 2.4, accuracy: 0.001)
    }

    func testImportsBareRecordDictionary() throws {
        let json = #"{"w0":{"ef":2.5,"iv":1,"n":1,"due":20001,"seen":1,"ok":1,"bad":0,"last":20000}}"#
        let store = makeStore()
        try store.importData(Data(json.utf8))
        XCTAssertEqual(store.record(for: "w0").iv, 1)
    }

    func testImportRejectsGarbage() {
        let store = makeStore()
        XCTAssertThrowsError(try store.importData(Data("bu bir yedek değil".utf8)))
    }

    func testMissingFieldsFallBackToDefaults() throws {
        // Eski sürümden gelen eksik alanlı kayıt uygulamayı çökertmemeli.
        let json = #"{"w0":{"ef":2.2,"seen":3}}"#
        let store = makeStore()
        try store.importData(Data(json.utf8))

        let record = store.record(for: "w0")
        XCTAssertEqual(record.seen, 3)
        XCTAssertEqual(record.iv, 0)
        XCTAssertEqual(record.n, 0)
    }
}
