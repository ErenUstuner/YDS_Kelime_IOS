import Foundation

// ============================================================
// Kart modeli
//
// Web sürümündeki DECK dizisinin birebir karşılığı. Kart kimlikleri
// (w0.., p0..) web ile aynı sırada üretilir; ilerleme verisi iki
// platform arasında taşınabilir kalsın diye.
// ============================================================

/// Kartın türü. Kelime ve phrasal verb ayrı destelerde çalışılabilir.
enum CardKind: String, Codable, CaseIterable, Sendable {
    case word
    case phrasal
}

/// Sözcük türü. Çeldirici seçiminde aynı türden kartlar tercih edilir —
/// bir fiile karşılık sıfat şıkları göstermek soruyu yapay biçimde kolaylaştırır.
enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
    case noun = "n"
    case verb = "v"
    case adjective = "adj"
    case adverb = "adv"
    case phrasal = "phr"

    var turkishLabel: String {
        switch self {
        case .noun: return "isim"
        case .verb: return "fiil"
        case .adjective: return "sıfat"
        case .adverb: return "zarf/bağlaç"
        case .phrasal: return "phrasal verb"
        }
    }
}

/// Zorluk seviyesi (1 temel — 3 ileri). Yeni kartlar kolaydan zora sıralanır.
enum WordLevel: Int, Codable, CaseIterable, Sendable, Comparable {
    case basic = 1
    case intermediate = 2
    case advanced = 3

    var turkishLabel: String {
        switch self {
        case .basic: return "temel"
        case .intermediate: return "orta"
        case .advanced: return "ileri"
        }
    }

    static func < (lhs: WordLevel, rhs: WordLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Tek bir çalışma kartı. Değişmez (immutable) — çalışma ilerlemesi
/// ayrı bir `ReviewRecord` içinde tutulur, kart verisi paketten okunur.
struct Card: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: CardKind
    /// İngilizce ifade. Phrasal verb'lerde birden çok sözcük olabilir.
    let term: String
    let pos: PartOfSpeech
    /// Türkçe karşılık. Virgülle ayrılmış birden çok anlam içerebilir;
    /// ilk anlam çeldirici karşılaştırmasında kanonik kabul edilir.
    let meaning: String
    let exampleEN: String
    let exampleTR: String
    /// İpucu düğmesinde gösterilen ikinci örnek cümle.
    let exampleEN2: String
    let level: WordLevel

    /// Çeldirici seçiminde kullanılan normalleştirilmiş anlam.
    /// "terk etmek, vazgeçmek" -> "terk etmek"
    var canonicalMeaning: String {
        (meaning.split(separator: ",").first.map(String.init) ?? meaning)
            .trimmingCharacters(in: .whitespaces)
            .lowercased(with: Locale(identifier: "tr_TR"))
    }

    var canonicalTerm: String {
        term.lowercased(with: Locale(identifier: "en_US"))
    }
}

/// Paketle gelen `deck.json` dosyasının kökü.
struct DeckPayload: Codable, Sendable {
    let version: Int
    let generatedAt: String
    let wordCount: Int
    let phrasalCount: Int
    /// Düzensiz fiillerin çekimli hâlleri: "arise" -> ["arose", "arisen"].
    /// Örnek cümlede hedef kelimeyi vurgularken kullanılır.
    let irregular: [String: [String]]
    let cards: [Card]
}
