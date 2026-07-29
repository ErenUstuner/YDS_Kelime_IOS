import SwiftUI

// ============================================================
// Oturum akışı
//
// Oturum nesnesinin sahibi burasıdır (@StateObject). Test ve sonuç
// ekranları arasındaki geçişi yönetir.
//
// "Tekrar dene" yeni bir nesne oluşturmaz, aynı oturumu `start()` ile
// sıfırlar: sunumu kapatıp açmadan yeni kuyruk kurulur, ekran titremez.
// ============================================================

@MainActor
struct QuizFlowView: View {

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: QuizSession

    /// Kuyruk kurulamadıysa (deste boş) sunumu hemen kapatmak için.
    @State private var didFailToStart = false

    init(environment: AppEnvironment) {
        _session = StateObject(wrappedValue: environment.makeSession())
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            if let summary = session.summary {
                ResultView(summary: summary, onRetry: retry, onClose: close)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if session.current != nil {
                QuizView(session: session, onQuit: { session.quit() })
                    .transition(.opacity)
            } else {
                ProgressView()
                    .tint(Theme.accent)
            }
        }
        .animation(.snappy(duration: 0.24), value: session.summary != nil)
        .task {
            guard session.current == nil && session.summary == nil else { return }
            if !session.start() { didFailToStart = true }
        }
        .onChange(of: didFailToStart) { _, failed in
            if failed { dismiss() }
        }
        .onChange(of: session.summary != nil) { _, finished in
            if finished { env.sessionDidFinish() }
        }
    }

    private func retry() {
        withAnimation(.snappy(duration: 0.24)) {
            if !session.start() { close() }
        }
    }

    private func close() {
        env.sessionDidFinish()
        dismiss()
    }
}
