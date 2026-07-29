import SwiftUI

// ============================================================
// Cevap kartı
//
// Cevap verildikten sonra açılan bölüm: doğru karşılık, örnek cümle,
// çevirisi, ikinci örnek ve bir sonraki tekrarın ne zaman geleceği.
//
// Tekrar aralığını göstermek bilinçli bir tercih: kullanıcı sistemin
// neden bazı kelimeleri sık, bazılarını seyrek sorduğunu görmezse
// algoritmayı rastgelelik sanır ve programa güvenmez.
// ============================================================

struct RevealCard: View {

    let outcome: AnswerOutcome
    let matcher: SentenceMatcher

    private var card: Card { outcome.question.card }

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            headline
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    meaningRow
                    Divider().overlay(Theme.line)
                    exampleBlock(title: "Örnek cümle",
                                 sentence: card.exampleEN,
                                 translation: card.exampleTR)
                    if !card.exampleEN2.isEmpty {
                        exampleBlock(title: "İkinci örnek",
                                     sentence: card.exampleEN2,
                                     translation: nil)
                    }
                    scheduleNote
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // ------------------------------------------------------------

    private var headline: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: outcome.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(outcome.isCorrect ? Theme.ok : Theme.err)

            Text(outcome.isCorrect
                 ? "Doğru — \(card.term)"
                 : "\(card.term) = \(card.meaning)")
                .font(.ydsHeadline)
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Theme.Space.md)
        .background(outcome.isCorrect ? Theme.okDim : Theme.errDim,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var meaningRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(card.term)
                    .font(.ydsTitle)
                    .foregroundStyle(Theme.txt)
                TagChip(text: card.pos.turkishLabel)
            }
            Text(card.meaning)
                .font(.ydsBody)
                .foregroundStyle(Theme.txt2)
        }
    }

    private func exampleBlock(title: String, sentence: String, translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.ydsCaption.weight(.semibold))
                .foregroundStyle(Theme.txt3)
                .textCase(.uppercase)
                .kerning(0.5)
            HighlightedSentence(sentence: sentence, term: card.term, matcher: matcher)
            if let translation {
                Text(translation)
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scheduleNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
                .font(.caption)
            Text(scheduleText)
        }
        .font(.ydsCaption)
        .foregroundStyle(Theme.txt3)
    }

    private var scheduleText: String {
        let when = outcome.nextIntervalDays == 0
            ? "bu oturumda tekrar sorulacak"
            : "sonraki tekrar \(outcome.nextIntervalDays) gün sonra"
        let ef = String(format: "%.2f", outcome.easinessFactor)
        let hint = outcome.hintUsed ? " · ipucu kullanıldı" : ""
        return "\(when) · kolaylık katsayısı \(ef)\(hint)"
    }
}
