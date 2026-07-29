import Foundation

// ============================================================
// Çeldirici üretimi
//
// Yanlış şıklar rastgele seçilirse soru kolaylaşır ve ölçüm değeri düşer.
// Web sürümündeki üç kademeli kova mantığı burada da aynen uygulanıyor:
//
//   1. yakın : aynı sözcük türü + en fazla 1 seviye fark
//   2. orta  : aynı sözcük türü
//   3. geniş : aynı deste türünden herhangi bir kart
//
// Yakın kovadan yeterli aday çıkmazsa bir alt kovaya inilir. Böylece
// şıklar mümkün olduğunca birbirine benzer ve soru gerçekten ayırt eder.
// ============================================================

/// Sorunun yönü.
enum QuizDirection: String, CaseIterable, Identifiable, Sendable {
    case en2tr      // İngilizce sorulur, Türkçe şıklar
    case tr2en      // Türkçe sorulur, İngilizce şıklar
    case both       // her kartta rastgele biri

    var id: String { rawValue }

    var turkishLabel: String {
        switch self {
        case .en2tr: return "EN → TR"
        case .tr2en: return "TR → EN"
        case .both: return "Karışık"
        }
    }
}

enum DistractorGenerator {

    /// `card` için `count` adet yanlış şık üretir.
    ///
    /// Aynı anlama gelen kartlar elenir — "terk etmek" karşılığı iki farklı
    /// kelimede geçiyorsa ikisini birden şık yapmak soruyu cevapsız bırakır.
    static func make(for card: Card,
                     in deck: [Card],
                     direction: QuizDirection,
                     count: Int,
                     shuffler: ([Card]) -> [Card] = { $0.shuffled() }) -> [Card] {

        let candidates = deck.filter {
            $0.id != card.id
                && $0.kind == card.kind
                && $0.canonicalMeaning != card.canonicalMeaning
        }

        let near = candidates.filter {
            abs($0.level.rawValue - card.level.rawValue) <= 1 && $0.pos == card.pos
        }
        let mid = candidates.filter { $0.pos == card.pos }

        var used: Set<String> = [card.canonicalMeaning, card.canonicalTerm]
        var out: [Card] = []

        for bucket in [near, mid, candidates] {
            for candidate in shuffler(bucket) {
                let key = direction == .en2tr ? candidate.canonicalMeaning : candidate.canonicalTerm
                if used.contains(key) { continue }
                used.insert(key)
                out.append(candidate)
                if out.count >= count { return out }
            }
        }
        return out
    }
}
