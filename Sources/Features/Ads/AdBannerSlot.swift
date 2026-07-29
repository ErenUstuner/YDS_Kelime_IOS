import SwiftUI
import UIKit
import GoogleMobileAds

// ============================================================
// Reklam alanı
//
// Reklam yüklenene kadar hiç yer kaplamaz. Bu önemli: önceden yer
// ayırmak, reklam gelmediğinde ekranın ortasında boş bir delik bırakır.
// Reklam geldiğinde alan yumuşak bir geçişle açılır.
//
// Üstteki "Reklam" etiketi AdMob politikasının gereği: reklamın
// içerikten ayırt edilebilir olması zorunlu. Etiketsiz yerleşim,
// yanıltıcı yerleşim sayılır.
// ============================================================

struct AdBannerSlot: View {

    @EnvironmentObject private var env: AppEnvironment
    let placement: AdPlacement

    @State private var loadedHeight: CGFloat = 0

    var body: some View {
        Group {
            if env.ads.isReady, let unitID = env.ads.adUnitID(for: placement) {
                VStack(spacing: 4) {
                    if loadedHeight > 0 {
                        Text("Reklam")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.txt3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    BannerRepresentable(unitID: unitID, onHeight: { height in
                        withAnimation(.easeOut(duration: 0.25)) { loadedHeight = height }
                    })
                    .frame(height: loadedHeight)
                }
                .padding(.horizontal, loadedHeight > 0 ? 2 : 0)
                .frame(height: loadedHeight > 0 ? loadedHeight + 18 : 0)
                .clipped()
            }
        }
    }
}

// ============================================================
// UIKit köprüsü
// ============================================================

private struct BannerRepresentable: UIViewRepresentable {

    let unitID: String
    let onHeight: (CGFloat) -> Void

    func makeUIView(context: Context) -> BannerView {
        // Uyarlanabilir (adaptive) boyut: cihaz genişliğine göre
        // Google en uygun yüksekliği seçer. Sabit 320x50 banner,
        // büyük ekranlarda hem çirkin durur hem daha az kazandırır.
        let width = UIScreen.main.bounds.width - 32
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = unitID
        banner.rootViewController = AdsManager.rootViewController
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ view: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onHeight: onHeight) }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let onHeight: (CGFloat) -> Void

        init(onHeight: @escaping (CGFloat) -> Void) {
            self.onHeight = onHeight
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onHeight(bannerView.adSize.size.height)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // Sessizce kapat. Reklam gelmemesi kullanıcının sorunu değil;
            // hata mesajı göstermek yalnızca deneyimi bozardı.
            onHeight(0)
        }
    }
}
