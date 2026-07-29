import SwiftUI

// ============================================================
// İstatistik ekranı
// ============================================================

struct StatsView: View {

    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.md) {
                    distributionCard
                    activityCard
                    tableCard
                    hardestCard
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.xl)
            }
            .scrollIndicators(.hidden)
            .background(Theme.backgroundGradient)
            .navigationTitle("İstatistik")
        }
    }

    private var stats: StudyStats { env.stats }

    // ------------------------------------------------------------
    // Öğrenme dağılımı
    // ------------------------------------------------------------

    private var distributionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                sectionTitle("Öğrenme dağılımı")

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(order, id: \.0) { state, color in
                            Rectangle()
                                .fill(color)
                                .frame(width: geo.size.width * stats.share(of: state))
                        }
                    }
                }
                .frame(height: 12)
                .clipShape(Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(distributionDescription)

                // Efsane. Dört öğe iki sütuna sığıyor; tek sütun
                // dikeyde gereksiz yer kaplıyordu.
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          alignment: .leading, spacing: 6) {
                    ForEach(order, id: \.0) { state, color in
                        HStack(spacing: 6) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(state.turkishLabel)
                                .font(.ydsCaption)
                                .foregroundStyle(Theme.txt2)
                            Text("\(stats.stateCounts[state] ?? 0)")
                                .font(.ydsCaption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.txt)
                        }
                    }
                }
            }
        }
    }

    private var order: [(CardState, Color)] {
        [(.known, Theme.ok), (.learning, Theme.warn), (.hard, Theme.err), (.new, Theme.line2)]
    }

    private var distributionDescription: String {
        order.map { "\($0.0.turkishLabel) \(stats.stateCounts[$0.0] ?? 0)" }
            .joined(separator: ", ")
    }

    // ------------------------------------------------------------
    // Son 30 gün
    // ------------------------------------------------------------

    private var activityCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                sectionTitle("Son 30 gün")
                HStack(spacing: 3) {
                    ForEach(Array(stats.recentDays.enumerated()), id: \.offset) { _, studied in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(studied ? Theme.accent : Theme.surface3)
                            .frame(height: 22)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Son 30 günün \(stats.recentDays.filter { $0 }.count) gününde çalışıldı")

                Text("\(env.dayStreak) gündür kesintisiz · toplam \(stats.studiedDays) gün")
                    .font(.ydsCaption)
                    .foregroundStyle(Theme.txt3)
            }
        }
    }

    // ------------------------------------------------------------
    // Sayı tablosu
    // ------------------------------------------------------------

    private var tableCard: some View {
        SurfaceCard {
            VStack(spacing: 0) {
                row("Toplam kayıt", "\(stats.totalCards)")
                row("Çalışılan kart", "\(stats.studiedCards)")
                row("Bugün tekrarı gelen", "\(stats.dueToday)")
                row("Toplam cevap", "\(stats.totalAnswers)")
                row("Genel doğruluk", stats.accuracyPercent.map { "%\($0)" } ?? "—")
                row("En uzun seri", "\(stats.bestStreak)")
                row("Tamamlanan oturum", "\(stats.sessions)", last: true)
            }
        }
    }

    private func row(_ label: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt2)
                Spacer()
                Text(value)
                    .font(.ydsCallout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.txt)
            }
            .padding(.vertical, 9)
            if !last { Divider().overlay(Theme.line) }
        }
    }

    // ------------------------------------------------------------
    // En çok zorlanılanlar
    // ------------------------------------------------------------

    private var hardestCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                sectionTitle("En çok zorlandıkların")

                let hardest = StatsCalculator.hardestCards(deck: env.deck,
                                                           snapshot: env.store.snapshot)
                if hardest.isEmpty {
                    Text("Henüz yanlış cevabın yok.")
                        .font(.ydsCallout)
                        .foregroundStyle(Theme.txt3)
                } else {
                    ForEach(hardest, id: \.0.id) { card, record in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                            Text(card.term)
                                .font(.ydsCallout.weight(.semibold))
                                .foregroundStyle(Theme.txt)
                            Text(card.meaning)
                                .font(.ydsCaption)
                                .foregroundStyle(Theme.txt2)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(record.bad) yanlış")
                                .font(.ydsCaption.monospacedDigit())
                                .foregroundStyle(Theme.err)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.ydsCaption.weight(.semibold))
            .foregroundStyle(Theme.txt3)
            .textCase(.uppercase)
            .kerning(0.6)
    }
}
