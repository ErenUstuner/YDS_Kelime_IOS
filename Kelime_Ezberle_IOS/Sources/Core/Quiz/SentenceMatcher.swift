import Foundation

// ============================================================
// Örnek cümlede hedef ifadeyi bulma
//
// Cümlelerde kelime çekimli geçer: "abandon" -> "abandoned",
// "apply" -> "applies", "arise" -> "arose". Düz metin araması bu
// hâlleri kaçırır, o yüzden gövdeden desen üretiyoruz.
//
// Web'deki stemRe/termRe ile aynı kurallar. Kural değişirse iki
// tarafta birlikte değişmeli — tools/prepare_data.py doğrulaması da
// aynı gövdeleme mantığını kullanır.
//
// Bu katman SwiftUI bilmez: yalnızca eşleşen aralıkları döndürür,
// biçimlendirmeyi görünüm katmanı yapar.
// ============================================================

struct SentenceMatcher: Sendable {

    private let irregular: [String: [String]]

    init(irregular: [String: [String]]) {
        self.irregular = irregular
    }

    // ------------------------------------------------------------
    // Gövdeleme
    // ------------------------------------------------------------

    /// Tek bir sözcüğün çekimli hâllerini yakalayan desen parçası.
    ///
    /// - Parameter isParticle: phrasal verb'in ikinci ve sonraki sözcüğü mü?
    ///   "up", "on", "of" gibi edatlar çekimlenmez; onlara sonek eklemek
    ///   "on" ararken "onto"yu da yakalar ve yanlış vurgular.
    private func stemPattern(_ word: String, isParticle: Bool) -> String {
        let letters = word.filter { $0.isLetter }
        let stem = String(letters)
        guard !stem.isEmpty else { return NSRegularExpression.escapedPattern(for: word) }

        let alternates = irregular[stem.lowercased()] ?? []
        if isParticle && alternates.isEmpty {
            return NSRegularExpression.escapedPattern(for: stem)
        }

        var forms: [String] = []
        let lower = stem.lowercased()
        let vowels = Set("aeiou")

        if lower.count >= 2, lower.hasSuffix("y"),
           let beforeY = lower.dropLast().last, !vowels.contains(beforeY) {
            // apply -> applies / applied / applying, try -> tried / tries
            let head = String(stem.dropLast())
            forms = [head + "y[a-z]{0,3}", head + "i[a-z]{0,3}"]
        } else if lower.hasSuffix("e"), stem.count > 3 {
            // advocate -> advocated / advocating
            forms = [String(stem.dropLast()) + "[a-z]{0,4}"]
        } else {
            // abandon -> abandoned / abandoning
            forms = [stem + "[a-z]{0,4}"]
        }

        forms += alternates.map { NSRegularExpression.escapedPattern(for: $0) }
        return forms.count > 1 ? "(?:" + forms.joined(separator: "|") + ")" : forms[0]
    }

    /// Hedef ifadenin tamamını yakalayan desen.
    ///
    /// Phrasal verb'lerde araya nesne girebilir — "put the meeting off"
    /// gibi. Sözcükler arasına en fazla 3 sözcüklük boşluk tanınıyor;
    /// daha fazlası tesadüfi eşleşme üretmeye başlıyor.
    private func regex(for term: String) -> NSRegularExpression? {
        let words = term.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return nil }

        let body = words.enumerated()
            .map { stemPattern($0.element, isParticle: $0.offset > 0) }
            .joined(separator: "\\s+(?:\\w+\\s+){0,3}")

        return try? NSRegularExpression(pattern: "\\b(" + body + ")\\b",
                                        options: [.caseInsensitive])
    }

    // ------------------------------------------------------------
    // Genel arayüz
    // ------------------------------------------------------------

    /// Cümledeki eşleşme aralıkları. Eşleşme yoksa boş dizi.
    func matches(term: String, in sentence: String) -> [Range<String.Index>] {
        nsMatches(term: term, in: sentence)
            .compactMap { Range($0, in: sentence) }
    }

    private func nsMatches(term: String, in sentence: String) -> [NSRange] {
        guard let re = regex(for: term) else { return [] }
        let full = NSRange(location: 0, length: (sentence as NSString).length)
        return re.matches(in: sentence, options: [], range: full).map(\.range)
    }

    /// Hedef ifadeyi boşlukla gizlenmiş cümle.
    ///
    /// TR→EN yönünde kullanılıyor: aranan İngilizce ifade cevabın kendisi
    /// olduğu için ipucu cümlesinde açıkça görünemez.
    /// Eşleşme bulunamazsa cümle olduğu gibi döner — yanlış yere boşluk
    /// koymaktansa ipucunu biraz kolaylaştırmak yeğdir.
    func cloze(term: String, in sentence: String, blank: String = "______") -> String {
        let ranges = nsMatches(term: term, in: sentence)
        guard !ranges.isEmpty else { return sentence }
        // NSMutableString üzerinde çalışıyoruz: String.Index'ler ilk
        // değişiklikten sonra geçersizleşirdi.
        let out = NSMutableString(string: sentence)
        for range in ranges.reversed() {
            out.replaceCharacters(in: range, with: blank)
        }
        return out as String
    }
}
