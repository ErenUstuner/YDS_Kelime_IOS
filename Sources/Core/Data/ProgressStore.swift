import Foundation
import Combine

// ============================================================
// İlerleme deposu
//
// Web sürümü localStorage kullanıyordu; burada App Group içindeki
// tek bir JSON dosyası var. Şema web'inkiyle aynı tutuldu, böylece
// sitede biriken ilerleme dosyası uygulamaya doğrudan aktarılabiliyor.
//
// Neden Core Data / SwiftData değil: veri 781 kayıtlık düz bir sözlük,
// ilişkisel sorgu ihtiyacı yok, tamamı bellekte rahat duruyor. Bir
// veritabanı katmanı burada yalnızca karmaşıklık eklerdi.
// ============================================================

/// Diske yazılan yapı. Alan adları web sürümüyle birebir aynı.
struct ProgressSnapshot: Codable, Sendable {
    var rec: [String: ReviewRecord]
    var streakBest: Int
    var sessions: Int
    var totalAns: Int
    var totalOk: Int
    /// Çalışılan günlerin gün indeksleri. Son 400 gün saklanır.
    var days: [Int]

    static let empty = ProgressSnapshot(rec: [:], streakBest: 0, sessions: 0,
                                        totalAns: 0, totalOk: 0, days: [])

    init(rec: [String: ReviewRecord] = [:], streakBest: Int = 0, sessions: Int = 0,
         totalAns: Int = 0, totalOk: Int = 0, days: [Int] = []) {
        self.rec = rec; self.streakBest = streakBest; self.sessions = sessions
        self.totalAns = totalAns; self.totalOk = totalOk; self.days = days
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rec = try c.decodeIfPresent([String: ReviewRecord].self, forKey: .rec) ?? [:]
        streakBest = try c.decodeIfPresent(Int.self, forKey: .streakBest) ?? 0
        sessions = try c.decodeIfPresent(Int.self, forKey: .sessions) ?? 0
        totalAns = try c.decodeIfPresent(Int.self, forKey: .totalAns) ?? 0
        totalOk = try c.decodeIfPresent(Int.self, forKey: .totalOk) ?? 0
        days = try c.decodeIfPresent([Int].self, forKey: .days) ?? []
    }
}

/// Web'in "Dışa aktar" düğmesinin ürettiği dosya biçimi.
/// `data` alanı doğrudan kayıt sözlüğüdür.
private struct WebExportEnvelope: Decodable {
    let v: Int?
    let saved: String?
    let data: [String: ReviewRecord]
}

@MainActor
final class ProgressStore: ObservableObject {

    @Published private(set) var snapshot: ProgressSnapshot

    private let fileURL: URL
    /// Yazma işlemleri ana iş parçacığını bloklamasın diye ayrı kuyruk.
    private let ioQueue = DispatchQueue(label: "com.ustuner.ydskelimelerim.progress-io",
                                        qos: .utility)

    init(fileURL: URL = SharedContainer.progressURL) {
        self.fileURL = fileURL
        self.snapshot = ProgressStore.read(from: fileURL) ?? .empty
    }

    // ------------------------------------------------------------
    // Okuma
    // ------------------------------------------------------------

    func record(for id: String) -> ReviewRecord {
        snapshot.rec[id] ?? .empty
    }

    var accuracyPercent: Int? {
        guard snapshot.totalAns > 0 else { return nil }
        return Int((Double(snapshot.totalOk) / Double(snapshot.totalAns) * 100).rounded())
    }

    // ------------------------------------------------------------
    // Yazma
    // ------------------------------------------------------------

    /// Tek bir cevabı işler ve diske yazar.
    func apply(answerFor card: Card, correct: Bool, seconds: Double, hintUsed: Bool,
               today: Int = SM2Scheduler.dayIndex()) {
        var record = snapshot.rec[card.id] ?? .empty
        record.seen += 1
        if correct { record.ok += 1 } else { record.bad += 1 }

        let q = SM2Scheduler.quality(correct: correct, seconds: seconds, hintUsed: hintUsed)
        record = SM2Scheduler.apply(record, quality: q, today: today)

        snapshot.rec[card.id] = record
        snapshot.totalAns += 1
        if correct { snapshot.totalOk += 1 }
        markStudied(today: today)
        persist()
    }

    func registerStreak(_ streak: Int) {
        guard streak > snapshot.streakBest else { return }
        snapshot.streakBest = streak
        persist()
    }

    func registerCompletedSession() {
        snapshot.sessions += 1
        persist()
    }

    private func markStudied(today: Int) {
        guard !snapshot.days.contains(today) else { return }
        snapshot.days.append(today)
        if snapshot.days.count > 400 {
            snapshot.days.removeFirst(snapshot.days.count - 400)
        }
    }

    func reset() {
        snapshot = .empty
        persist()
    }

    // ------------------------------------------------------------
    // İçe / dışa aktarma
    // ------------------------------------------------------------

    /// Paylaşılabilir yedek dosyası üretir (web'in ürettiğiyle aynı biçim).
    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let envelope = ExportEnvelope(v: 1,
                                      saved: ISO8601DateFormatter().string(from: Date()),
                                      data: snapshot.rec,
                                      meta: ExportMeta(streakBest: snapshot.streakBest,
                                                       sessions: snapshot.sessions,
                                                       totalAns: snapshot.totalAns,
                                                       totalOk: snapshot.totalOk,
                                                       days: snapshot.days))
        return try encoder.encode(envelope)
    }

    private struct ExportMeta: Codable {
        let streakBest: Int, sessions: Int, totalAns: Int, totalOk: Int, days: [Int]
    }
    private struct ExportEnvelope: Codable {
        let v: Int, saved: String
        let data: [String: ReviewRecord]
        let meta: ExportMeta?
    }

    /// Yedek dosyasını geri yükler.
    ///
    /// Hem uygulamanın kendi biçimini hem web'in ürettiği daha sade biçimi
    /// kabul eder. `meta` yoksa yalnızca kart kayıtları geri gelir —
    /// toplam sayaçlar sıfırdan başlar, kayıp yalnızca istatistik olur.
    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(ExportEnvelope.self, from: data) {
            snapshot.rec = envelope.data
            if let meta = envelope.meta {
                snapshot.streakBest = meta.streakBest
                snapshot.sessions = meta.sessions
                snapshot.totalAns = meta.totalAns
                snapshot.totalOk = meta.totalOk
                snapshot.days = meta.days
            }
            persist()
            return
        }
        if let web = try? decoder.decode(WebExportEnvelope.self, from: data) {
            snapshot.rec = web.data
            persist()
            return
        }
        // Son çare: dosyanın kökü doğrudan kayıt sözlüğü olabilir.
        let bare = try decoder.decode([String: ReviewRecord].self, from: data)
        snapshot.rec = bare
        persist()
    }

    // ------------------------------------------------------------
    // Disk
    // ------------------------------------------------------------

    private static func read(from url: URL) -> ProgressSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
    }

    /// Diske atomik yazar.
    ///
    /// Atomik olması önemli: kullanıcı cevap verdiği anda uygulamayı
    /// kapatırsa yarım yazılmış dosya tüm ilerlemeyi okunamaz hâle getirirdi.
    private func persist() {
        let current = snapshot
        let url = fileURL
        ioQueue.async {
            guard let data = try? JSONEncoder().encode(current) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
