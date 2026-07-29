import SwiftUI

// ============================================================
// Test ekranı
//
// Yerleşim sırası bilinçli:
//   soru → şıklar → reklam → ipucu/cevap
//
// Reklamın şıkların ALTINDA olması AdMob politikası açısından
// kritik: şıkların üstünde duran bir reklam, kullanıcı cevaba
// basarken yanlışlıkla tıklanır. Bu "kazara tıklama" ihlali,
// hesap askıya alınmasının en yaygın sebeplerinden biridir.
// Reklam soru başına yenilenmez; oturum boyunca aynı kalır.
// ============================================================

struct QuizView: View {

    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject var session: QuizSession
    let onQuit: () -> Void

    @State private var showsQuitConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Space.md) {
                        if let question = session.current {
                            prompt(question)
                            answers(question)
                            adSlot
                            hintOrReveal(question)
                                .id("reveal")
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, Theme.Space.xl)
                }
                .scrollIndicators(.hidden)
                .onChange(of: session.outcome?.question.id) { _, id in
                    guard id != nil else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("reveal", anchor: .bottom)
                    }
                }
            }
            footer
        }
        .confirmationDialog("Oturumu bitir",
                            isPresented: $showsQuitConfirm,
                            titleVisibility: .visible) {
            Button("Bitir ve özeti gör", role: .destructive, action: onQuit)
            Button("Devam et", role: .cancel) {}
        } message: {
            Text("Şu ana kadar verdiğin cevaplar kaydedildi.")
        }
    }

    // ------------------------------------------------------------
    // Üst çubuk
    // ------------------------------------------------------------

    private var header: some View {
        VStack(spacing: Theme.Space.sm) {
            HStack {
                Button {
                    showsQuitConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Theme.txt2)
                        .frame(width: 34, height: 34)
                        .background(Theme.surface2, in: Circle())
                }
                .accessibilityLabel("Oturumu bitir")

                Spacer()

                Text("\(min(session.position + 1, session.total)) / \(session.total)")
                    .font(.ydsCallout.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.txt2)

                Spacer()

                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(session.streak)")
                        .font(.ydsCallout.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                }
                .foregroundStyle(session.streak > 0 ? Theme.warn : Theme.txt3)
                .frame(minWidth: 44)
                .accessibilityLabel("Seri: \(session.streak)")
            }

            ProgressView(value: session.progress)
                .tint(Theme.accent)
                .scaleEffect(x: 1, y: 1.4, anchor: .center)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm)
    }

    // ------------------------------------------------------------
    // Soru
    // ------------------------------------------------------------

    private func prompt(_ question: QuizQuestion) -> some View {
        SurfaceCard(padding: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack(spacing: 6) {
                    TagChip(text: question.card.pos.turkishLabel)
                    TagChip(text: question.card.level.turkishLabel,
                            color: levelColor(question.card.level),
                            background: levelColor(question.card.level).opacity(0.15))
                    TagChip(text: question.isNew ? "yeni"
                                : (question.repetition > 0 ? "tekrar #\(question.repetition)" : "yeniden"))
                    Spacer(minLength: 0)
                }

                Text(question.prompt)
                    .font(question.promptIsEnglish ? .ydsDisplay : .system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.disabled)

                Text(question.promptIsEnglish ? "Türkçe karşılığı hangisi?" : "İngilizce karşılığı hangisi?")
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func levelColor(_ level: WordLevel) -> Color {
        switch level {
        case .basic: return Theme.ok
        case .intermediate: return Theme.warn
        case .advanced: return Theme.err
        }
    }

    // ------------------------------------------------------------
    // Şıklar
    // ------------------------------------------------------------

    private func answers(_ question: QuizQuestion) -> some View {
        VStack(spacing: Theme.Space.xs) {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                AnswerButton(index: index,
                             text: question.label(for: option),
                             state: appearance(for: index),
                             action: { session.answer(index: index) })
            }
        }
    }

    private func appearance(for index: Int) -> AnswerButton.Appearance {
        guard let outcome = session.outcome else { return .idle }
        if index == outcome.correctIndex { return .correct }
        if index == outcome.pickedIndex { return .wrong }
        return .dimmed
    }

    // ------------------------------------------------------------
    // Reklam
    // ------------------------------------------------------------

    @ViewBuilder
    private var adSlot: some View {
        // Oturum boyunca tek örnek: `id` sabit olduğu için soru
        // değiştiğinde görünüm yeniden kurulmaz, reklam yenilenmez.
        AdBannerSlot(placement: .quiz)
            .environmentObject(env)
            .id("quiz-banner")
    }

    // ------------------------------------------------------------
    // İpucu ve cevap
    // ------------------------------------------------------------

    @ViewBuilder
    private func hintOrReveal(_ question: QuizQuestion) -> some View {
        VStack(spacing: Theme.Space.md) {
            if session.outcome == nil {
                hintSection(question)
            } else if let outcome = session.outcome {
                RevealCard(outcome: outcome, matcher: env.matcher)
            }
        }
    }

    @ViewBuilder
    private func hintSection(_ question: QuizQuestion) -> some View {
        if session.hintVisible {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text(question.promptIsEnglish
                         ? "İpucu — örnek kullanım"
                         : "İpucu — boşluğa hangi ifade gelmeli?")
                        .font(.ydsCaption.weight(.semibold))
                        .foregroundStyle(Theme.accent2)

                    if question.promptIsEnglish {
                        HighlightedSentence(sentence: question.card.exampleEN2,
                                            term: question.card.term,
                                            matcher: env.matcher)
                    } else {
                        // TR→EN yönünde aranan ifade cevabın kendisi;
                        // cümlede boşluk bırakılıyor.
                        Text(env.matcher.cloze(term: question.card.term,
                                               in: question.card.exampleEN2))
                            .font(.ydsSerif)
                            .foregroundStyle(Theme.txt)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("İpucu kullanıldı: bu kelime doğru bilinse bile tekrar aralığı daha az uzayacak.")
                        .font(.ydsCaption)
                        .foregroundStyle(Theme.txt3)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            Button {
                withAnimation(.snappy(duration: 0.2)) { session.revealHint() }
            } label: {
                Label("Cümlede kullanımını gör", systemImage: "lightbulb")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // ------------------------------------------------------------
    // Alt çubuk
    // ------------------------------------------------------------

    @ViewBuilder
    private var footer: some View {
        if session.outcome != nil {
            Button {
                withAnimation(.snappy(duration: 0.2)) { session.advance() }
            } label: {
                Label("Sonraki", systemImage: "arrow.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.xs)
            .padding(.bottom, Theme.Space.xs)
            .background(.ultraThinMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
