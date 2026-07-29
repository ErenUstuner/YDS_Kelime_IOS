import SwiftUI

// ============================================================
// Sonuç ekranı
//
// Web'deki halka animasyonunun karşılığı. Reklam burada oturum
// başına yalnızca bir kez yüklenir — doğal bir mola anı olduğu için
// hem politikaya uygun hem de kullanıcıyı bölmeyen tek yer.
// ============================================================

struct ResultView: View {

    @EnvironmentObject private var env: AppEnvironment
    let summary: SessionSummary
    let onRetry: () -> Void
    let onClose: () -> Void

    @State private var ringProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                ring
                titles
                counters
                AdBannerSlot(placement: .result)
                    .environmentObject(env)
                mistakeList
                actions
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            guard !reduceMotion else {
                ringProgress = Double(summary.percent) / 100
                return
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
                ringProgress = Double(summary.percent) / 100
            }
        }
    }

    // ------------------------------------------------------------

    private var ringColor: Color {
        if summary.percent >= 80 { return Theme.ok }
        if summary.percent >= 55 { return Theme.warn }
        return Theme.err
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.surface3, lineWidth: 13)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("%\(summary.percent)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.txt)
                    .contentTransition(.numericText())
                Text("\(summary.correct) / \(summary.total)")
                    .font(.ydsCallout.monospacedDigit())
                    .foregroundStyle(Theme.txt3)
            }
        }
        .frame(width: 156, height: 156)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Başarı yüzde \(summary.percent). \(summary.correct) doğru, \(summary.wrong) yanlış.")
    }

    private var titles: some View {
        VStack(spacing: 5) {
            Text(summary.title)
                .font(.ydsTitle)
                .foregroundStyle(Theme.txt)
            Text(summary.subtitle)
                .font(.ydsCallout)
                .foregroundStyle(Theme.txt2)
                .multilineTextAlignment(.center)
        }
    }

    private var counters: some View {
        HStack(spacing: Theme.Space.xs) {
            StatTile(value: "\(summary.correct)", label: "Doğru", tint: Theme.ok)
            StatTile(value: "\(summary.wrong)", label: "Yanlış", tint: Theme.err)
            StatTile(value: "\(summary.bestStreak)", label: "En uzun seri", tint: Theme.warn)
        }
    }

    @ViewBuilder
    private var mistakeList: some View {
        if !summary.mistakes.isEmpty {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Tekrar edilecekler")
                        .font(.ydsCaption.weight(.semibold))
                        .foregroundStyle(Theme.txt3)
                        .textCase(.uppercase)
                        .kerning(0.6)

                    ForEach(summary.mistakes) { card in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                            Text(card.term)
                                .font(.ydsBody.weight(.semibold))
                                .foregroundStyle(Theme.txt)
                            Text(card.meaning)
                                .font(.ydsCallout)
                                .foregroundStyle(Theme.txt2)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Space.xs) {
            Button {
                onRetry()
            } label: {
                Label("Yeni oturum", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Ana ekrana dön", action: onClose)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.top, Theme.Space.xs)
    }
}
