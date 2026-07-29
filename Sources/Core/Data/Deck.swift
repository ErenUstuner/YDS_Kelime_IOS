import Foundation

// ============================================================
// Deste yükleme
//
// deck.json uygulama paketine gömülüdür — ağ bağlantısı gerekmez,
// uygulama uçak modunda da tam çalışır. Dosya tools/prepare_data.py
// tarafından web projesinin kaynaklarından üretilir.
// ============================================================

/// Paketten okunan, değişmeyen kart destesi.
struct Deck: Sendable {
    let cards: [Card]
    let irregular: [String: [String]]
    let version: Int
    let generatedAt: String

    private let index: [String: Card]

    init(payload: DeckPayload) {
        self.cards = payload.cards
        self.irregular = payload.irregular
        self.version = payload.version
        self.generatedAt = payload.generatedAt
        self.index = Dictionary(payload.cards.map { ($0.id, $0) },
                                uniquingKeysWith: { first, _ in first })
    }

    subscript(id: String) -> Card? { index[id] }

    var words: [Card] { cards.filter { $0.kind == .word } }
    var phrasals: [Card] { cards.filter { $0.kind == .phrasal } }
}

enum DeckLoaderError: LocalizedError {
    case resourceMissing
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "Kelime verisi uygulama paketinde bulunamadı."
        case .decodingFailed(let error):
            return "Kelime verisi okunamadı: \(error.localizedDescription)"
        }
    }
}

enum DeckLoader {

    /// Uygulama paketinden desteyi yükler.
    ///
    /// Hata durumunda çökmek yerine hatayı fırlatır: veri dosyası bozuksa
    /// kullanıcıya anlaşılır bir ekran gösterebilmek, uygulamanın açılışta
    /// kapanmasından çok daha iyidir.
    static func load(from bundle: Bundle = .main) throws -> Deck {
        guard let url = bundle.url(forResource: "deck", withExtension: "json") else {
            throw DeckLoaderError.resourceMissing
        }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let payload = try JSONDecoder().decode(DeckPayload.self, from: data)
            return Deck(payload: payload)
        } catch {
            throw DeckLoaderError.decodingFailed(error)
        }
    }
}
