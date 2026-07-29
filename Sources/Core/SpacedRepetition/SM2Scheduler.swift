import Foundation

// ============================================================
// SM-2 aralıklı tekrar motoru
//
// SuperMemo-2 algoritmasının web sürümüyle birebir aynı uygulaması.
// Saf fonksiyon: girdi kaydı ve kalite notu, çıktı yeni kayıt.
// Yan etkisi yok, bu yüzden testi doğrudan yazılabilir.
// ============================================================

enum SM2Scheduler {

    /// Bir günün saniye cinsinden uzunluğu değil, epoch'tan bu yana gün sayısı.
    /// Web'deki `Math.floor(Date.now() / 864e5)` ile aynı değeri üretir; iki
    /// platformda üretilen ilerleme dosyaları aynı takvimi paylaşır.
    static func dayIndex(_ date: Date = Date()) -> Int {
        Int(floor(date.timeIntervalSince1970 / 86_400))
    }

    /// SM-2 çekirdeği: kalite notu (0-5) -> yeni aralık ve kolaylık katsayısı.
    ///
    /// - q >= 3 doğru cevap sayılır ve aralık uzar.
    /// - q < 3 yanlış sayılır: aralık sıfırlanır, kart aynı oturumda tekrar sorulur.
    ///
    /// Kolaylık katsayısı her cevapta güncellenir ve 1.3'ün altına inemez;
    /// bu alt sınır olmadan zor kartlar sonsuz kısalan aralıkla kilitlenir.
    static func apply(_ record: ReviewRecord, quality q: Int, today: Int) -> ReviewRecord {
        var r = record

        if q >= 3 {
            switch r.n {
            case 0: r.iv = 1
            case 1: r.iv = 3
            default: r.iv = max(1, Int((Double(r.iv) * r.ef).rounded()))
            }
            r.n += 1
        } else {
            r.n = 0
            r.iv = 0                                  // aynı oturumda tekrar
        }

        let delta = 0.1 - (5.0 - Double(q)) * (0.08 + (5.0 - Double(q)) * 0.02)
        r.ef = max(1.3, r.ef + delta)
        r.due = today + r.iv
        r.last = today
        return r
    }

    /// Cevap doğruluğu ve süresinden kalite notu türetir.
    ///
    /// Hızlı ve doğru = 5, yavaş ama doğru = 3. Bu ayrım önemli: kelimeyi
    /// düşünerek çıkarmak ile refleksle hatırlamak aynı hafıza gücü değildir.
    ///
    /// İpucu kullanılmış doğru cevap en fazla 3 alır — cümledeki bağlamla
    /// bulunan cevap tam hatırlama sayılmaz, aralık asgari ölçüde uzar.
    static func quality(correct: Bool, seconds: Double, hintUsed: Bool) -> Int {
        if correct {
            if hintUsed { return 3 }
            if seconds < 4 { return 5 }
            if seconds < 9 { return 4 }
            return 3
        } else {
            return seconds < 6 ? 2 : 1
        }
    }
}
