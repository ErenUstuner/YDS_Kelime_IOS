import SwiftUI

// ============================================================
// Ana ekran
//
// Web'deki #vHome görünümünün karşılığı: sayaçlar, deste seçimi,
// yön ve uzunluk segmentleri, başlat düğmesi.
// ============================================================

struct HomeView: View {

    @EnvironmentObject private var env: AppEnvironment
    @State private var isStudying = false
    @State private var showsEmptyDeckAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient
                ScrollView {
                    VStack(spacing: Theme.Space.md) {
                        counters
                        streakBanner
                        optionsCard
                        startButton
                        infoNote
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, Theme.Space.xl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("YDS Kelimelerim")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $isStudying) {
            QuizFlowView(environment: env)
                .environmentObject(env)
        }
        .alert("Bu destede kart bulunamadı", isPresented: $showsEmptyDeckAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Farklı bir deste seçip yeniden deneyin.")
        }
    }

    // ------------------------------------------------------------

    private var counters: some View {
        let c = env.counts
        return SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Bugünün durumu")
                    .font(.ydsCaption.weight(.semibold))
                    .foregroundStyle(Theme.txt3)
                    .textCase(.uppercase)
                    .kerning(0.6)

                HStack(spacing: Theme.Space.xs) {
                    StatTile(value: "\(c.due)", label: "Tekrar", tint: Theme.warn)
                    StatTile(value: "\(c.fresh)", label: "Yeni", tint: Theme.accent)
                    StatTile(value: "\(c.studied)", label: "Çalışılan", tint: Theme.ok)
                    StatTile(value: env.store.accuracyPercent.map { "\($0)%" } ?? "—",
                             label: "Doğruluk", tint: Theme.txt2)
                }
            }
        }
    }

    @ViewBuilder
    private var streakBanner: some View {
        let streak = env.dayStreak
        if streak > 1 {
            HStack(spacing: Theme.Space.sm) {
                Text("🔥")
                    .font(.title3)
                Text("\(streak) gündür kesintisiz çalışıyorsun")
                    .font(.ydsCallout.weight(.medium))
                    .foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(Theme.warnDim, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }

    private var optionsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                labeled("Deste") {
                    SegmentedChoice(values: DeckFilter.allCases,
                                    label: \.turkishLabel,
                                    selection: $env.options.deck)
                }
                labeled("Soru yönü") {
                    SegmentedChoice(values: QuizDirection.allCases,
                                    label: \.turkishLabel,
                                    selection: $env.options.direction)
                }
                labeled("Oturum uzunluğu") {
                    SegmentedChoice(values: SessionOptions.lengthChoices,
                                    label: { "\($0) soru" },
                                    selection: $env.options.length)
                }
            }
        }
    }

    private func labeled<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.ydsCaption.weight(.semibold))
                .foregroundStyle(Theme.txt3)
                .textCase(.uppercase)
                .kerning(0.6)
            content()
        }
    }

    private var startButton: some View {
        Button {
            // Kuyruğun kurulabildiğini sunumdan önce sınıyoruz: boş bir
            // ekran açıp hemen kapatmak kullanıcıya hata gibi görünürdü.
            if env.canStartSession() {
                isStudying = true
            } else {
                showsEmptyDeckAlert = true
            }
        } label: {
            Label("Çalışmaya başla", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var infoNote: some View {
        Text("Sorular aralıklı tekrar takvimine göre seçilir: önce vadesi gelen kartlar, sonra yeni kelimeler. Yanlış bildiklerin oturumun sonunda yeniden sorulur.")
            .font(.ydsCaption)
            .foregroundStyle(Theme.txt3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}
