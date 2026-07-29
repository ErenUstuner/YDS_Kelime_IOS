import Foundation

// ============================================================
// Tekrar kaydı
//
// Web'deki defaultRec() ile alan alan aynı. Kısa anahtar adları
// (ef, iv, n, due...) bilerek korundu: web'den dışa aktarılan
// ilerleme dosyası uygulamaya olduğu gibi aktarılabilsin diye.
// ============================================================

/// Bir kartın SM-2 durumu.
struct ReviewRecord: Codable, Hashable, Sendable {
    /// Kolaylık katsayısı (easiness factor). 1.3 taban değer.
    var ef: Double
    /// Geçerli tekrar aralığı, gün.
    var iv: Int
    /// Üst üste doğru bilinme sayısı. Yanlışta sıfırlanır.
    var n: Int
    /// Tekrarın geldiği gün (1970'ten bu yana gün sayısı).
    var due: Int
    /// Kaç kez soruldu.
    var seen: Int
    /// Kaç kez doğru bilindi.
    var ok: Int
    /// Kaç kez yanlış bilindi.
    var bad: Int
    /// Son görülme günü.
    var last: Int

    static let empty = ReviewRecord(ef: 2.5, iv: 0, n: 0, due: 0, seen: 0, ok: 0, bad: 0, last: 0)

    /// Eski veya eksik alanlı dosyalar da okunabilsin diye hepsi varsayılanlı.
    init(ef: Double = 2.5, iv: Int = 0, n: Int = 0, due: Int = 0,
         seen: Int = 0, ok: Int = 0, bad: Int = 0, last: Int = 0) {
        self.ef = ef; self.iv = iv; self.n = n; self.due = due
        self.seen = seen; self.ok = ok; self.bad = bad; self.last = last
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ef = try c.decodeIfPresent(Double.self, forKey: .ef) ?? 2.5
        iv = try c.decodeIfPresent(Int.self, forKey: .iv) ?? 0
        n = try c.decodeIfPresent(Int.self, forKey: .n) ?? 0
        due = try c.decodeIfPresent(Int.self, forKey: .due) ?? 0
        seen = try c.decodeIfPresent(Int.self, forKey: .seen) ?? 0
        ok = try c.decodeIfPresent(Int.self, forKey: .ok) ?? 0
        bad = try c.decodeIfPresent(Int.self, forKey: .bad) ?? 0
        last = try c.decodeIfPresent(Int.self, forKey: .last) ?? 0
    }
}

/// Kartın öğrenme aşaması. İstatistik ekranındaki renkli şeridi besler.
enum CardState: String, CaseIterable, Sendable {
    case new        // hiç sorulmadı
    case hard       // sık yanlış yapılıyor
    case learning   // öğreniliyor
    case known      // uzun aralığa geçti

    var turkishLabel: String {
        switch self {
        case .new: return "yeni"
        case .hard: return "zorlanılan"
        case .learning: return "öğreniliyor"
        case .known: return "biliniyor"
        }
    }

    /// Web'deki stateOf() ile aynı eşikler.
    static func of(_ record: ReviewRecord?) -> CardState {
        guard let r = record, r.seen > 0 else { return .new }
        if r.ef < 2.0 || (r.bad >= 2 && r.n <= 1) { return .hard }
        if r.n >= 3 && r.iv >= 14 { return .known }
        return .learning
    }
}
