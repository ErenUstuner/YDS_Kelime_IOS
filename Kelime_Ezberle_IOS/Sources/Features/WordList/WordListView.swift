import SwiftUI

// ============================================================
// Kelime listesi
//
// 781 kayıt. Liste `LazyVStack` yerine `List` ile: hücre geri
// dönüşümü, kaydırma performansı ve arama alanı hazır geliyor.
//
// Arama hem İngilizce ifadede hem Türkçe karşılıkta çalışır;
// Türkçe karşılaştırma için tr_TR yereli kullanılıyor — "İ/ı"
// dönüşümü İngilizce yerelde yanlış sonuç verir.
// ============================================================

struct WordListView: View {

    @EnvironmentObject private var env: AppEnvironment
    @State private var query = ""
    @State private var filter: DeckFilter = .mix
    @State private var stateFilter: StateFilter = .all

    enum StateFilter: String, CaseIterable, Identifiable {
        case all, due, hard, known
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "Tümü"
            case .due: return "Tekrar"
            case .hard: return "Zorlar"
            case .known: return "Bilinen"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SegmentedChoice(values: DeckFilter.allCases,
                                    label: \.turkishLabel,
                                    selection: $filter)
                    SegmentedChoice(values: StateFilter.allCases,
                                    label: \.label,
                                    selection: $stateFilter)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Section {
                    if filtered.isEmpty {
                        EmptyStateView(systemImage: "magnifyingglass",
                                       title: "Sonuç yok",
                                       message: "Arama veya süzgeçleri değiştirmeyi deneyin.")
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(filtered) { card in
                            NavigationLink {
                                WordDetailView(card: card,
                                               record: env.store.record(for: card.id))
                            } label: {
                                WordRow(card: card,
                                        state: CardState.of(env.store.snapshot.rec[card.id]))
                            }
                        }
                    }
                } header: {
                    Text("\(filtered.count) kayıt")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient)
            .navigationTitle("Kelimeler")
            .searchable(text: $query, prompt: "Kelime veya anlam ara")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .safeAreaInset(edge: .bottom) {
                AdBannerSlot(placement: .list)
                    .environmentObject(env)
                    .background(.ultraThinMaterial)
            }
        }
    }

    // ------------------------------------------------------------

    private var filtered: [Card] {
        let today = SM2Scheduler.dayIndex()
        let needle = query.trimmingCharacters(in: .whitespaces)
            .lowercased(with: Locale(identifier: "tr_TR"))

        return env.deck.cards.filter { card in
            guard filter == .mix || card.kind.rawValue == filter.rawValue else { return false }

            let record = env.store.snapshot.rec[card.id]
            switch stateFilter {
            case .all: break
            case .due:
                guard let r = record, r.seen > 0, r.due <= today else { return false }
            case .hard:
                guard CardState.of(record) == .hard else { return false }
            case .known:
                guard CardState.of(record) == .known else { return false }
            }

            guard !needle.isEmpty else { return true }
            return card.term.lowercased(with: Locale(identifier: "tr_TR")).contains(needle)
                || card.meaning.lowercased(with: Locale(identifier: "tr_TR")).contains(needle)
        }
    }
}

// ============================================================

private struct WordRow: View {
    let card: Card
    let state: CardState

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(card.term)
                    .font(.ydsBody.weight(.semibold))
                    .foregroundStyle(Theme.txt)
                Text(card.meaning)
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(card.level.turkishLabel)
                .font(.ydsCaption)
                .foregroundStyle(Theme.txt3)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint(state.turkishLabel)
    }

    private var color: Color {
        switch state {
        case .new: return Theme.line2
        case .hard: return Theme.err
        case .learning: return Theme.warn
        case .known: return Theme.ok
        }
    }
}

// ============================================================

struct WordDetailView: View {

    @EnvironmentObject private var env: AppEnvironment
    let card: Card
    let record: ReviewRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                header
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        example(title: "Örnek cümle",
                                sentence: card.exampleEN,
                                translation: card.exampleTR)
                        if !card.exampleEN2.isEmpty {
                            Divider().overlay(Theme.line)
                            example(title: "İkinci örnek",
                                    sentence: card.exampleEN2,
                                    translation: nil)
                        }
                    }
                }
                progressCard
            }
            .padding(Theme.Space.md)
        }
        .scrollIndicators(.hidden)
        .background(Theme.backgroundGradient)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(card.term)
                .font(.ydsDisplay)
                .foregroundStyle(Theme.txt)
            Text(card.meaning)
                .font(.ydsBody)
                .foregroundStyle(Theme.txt2)
            HStack(spacing: 6) {
                TagChip(text: card.pos.turkishLabel)
                TagChip(text: card.level.turkishLabel)
                TagChip(text: CardState.of(record.seen > 0 ? record : nil).turkishLabel)
            }
        }
    }

    private func example(title: String, sentence: String, translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.ydsCaption.weight(.semibold))
                .foregroundStyle(Theme.txt3)
                .textCase(.uppercase)
            HighlightedSentence(sentence: sentence, term: card.term, matcher: env.matcher)
            if let translation {
                Text(translation)
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt2)
            }
        }
    }

    @ViewBuilder
    private var progressCard: some View {
        if record.seen > 0 {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Bu kelimedeki ilerlemen")
                        .font(.ydsCaption.weight(.semibold))
                        .foregroundStyle(Theme.txt3)
                        .textCase(.uppercase)
                    row("Soruldu", "\(record.seen) kez")
                    row("Doğru", "\(record.ok)")
                    row("Yanlış", "\(record.bad)")
                    row("Tekrar aralığı", record.iv == 0 ? "bu oturumda" : "\(record.iv) gün")
                    row("Kolaylık katsayısı", String(format: "%.2f", record.ef))
                }
            }
        } else {
            SurfaceCard {
                Text("Bu kelime henüz hiç sorulmadı.")
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt3)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.txt2)
            Spacer()
            Text(value).foregroundStyle(Theme.txt).fontWeight(.medium)
        }
        .font(.ydsCallout)
    }
}
