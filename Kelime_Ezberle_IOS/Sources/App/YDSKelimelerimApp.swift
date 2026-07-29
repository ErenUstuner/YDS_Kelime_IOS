import SwiftUI

// ============================================================
// Uygulama giriş noktası
// ============================================================

@main
@MainActor
struct YDSKelimelerimApp: App {

    @StateObject private var env = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .preferredColorScheme(nil)          // sistem temasına uy
                .task {
                    // Sıralama önemli: önce onay, sonra SDK başlatma.
                    // Tersi yapılırsa SDK onay bilinmeden reklam ön yükleyebilir;
                    // bu hem GDPR ihlali hem de AdMob politikası ihlalidir.
                    await env.ads.prepare()
                    env.refreshWidget()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Uygulama arka plana giderken widget'ı tazele: kullanıcı
            // ana ekrana döndüğünde güncel sayıyı görsün.
            if phase == .background { env.refreshWidget() }
        }
    }
}
