import SwiftUI

// ============================================================
// Kök görünüm — sekme çubuğu
// ============================================================

struct RootView: View {

    @EnvironmentObject private var env: AppEnvironment
    @State private var selection: Tab = .study

    enum Tab: Hashable {
        case study, list, stats, settings
    }

    var body: some View {
        if let error = env.loadError {
            DataErrorView(message: error)
        } else {
            TabView(selection: $selection) {
                HomeView()
                    .tabItem { Label("Çalış", systemImage: "graduationcap.fill") }
                    .tag(Tab.study)

                WordListView()
                    .tabItem { Label("Kelimeler", systemImage: "list.bullet.rectangle") }
                    .tag(Tab.list)

                StatsView()
                    .tabItem { Label("İstatistik", systemImage: "chart.bar.fill") }
                    .tag(Tab.stats)

                SettingsView()
                    .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
            .tint(Theme.accent)
        }
    }
}

/// Veri dosyası okunamadığında gösterilir.
///
/// Bu ekranın var olması bir tercih: paketteki JSON bozulursa uygulama
/// açılışta çökerdi ve App Store incelemesinde doğrudan ret sebebi olurdu.
private struct DataErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Theme.backgroundGradient
            VStack(spacing: Theme.Space.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.warn)
                Text("Kelime verisi yüklenemedi")
                    .font(.ydsTitle)
                    .foregroundStyle(Theme.txt)
                Text(message)
                    .font(.ydsCallout)
                    .foregroundStyle(Theme.txt2)
                    .multilineTextAlignment(.center)
                Text("Uygulamayı silip yeniden yüklemek sorunu çözecektir.")
                    .font(.ydsCaption)
                    .foregroundStyle(Theme.txt3)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Space.xl)
        }
    }
}
