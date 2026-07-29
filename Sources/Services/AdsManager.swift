import Foundation
import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

// ============================================================
// Reklam yönetimi
//
// Sıralama bu dosyanın en önemli kısmı:
//
//   1. UMP onay formu toplanır (GDPR / KVKK)
//   2. ATT izni istenir (Apple kuralı)
//   3. ANCAK ondan sonra Mobile Ads SDK başlatılır
//
// SDK başlatıldığı anda reklam ön yüklemeye başlar. Onaydan önce
// başlatmak hem GDPR ihlali hem de AdMob politikası ihlalidir;
// Google bu durumda AB trafiğinde reklam yayınını durdurur.
//
// ATT'nin UMP'den SONRA gelmesi de kural: Apple, izleme izni
// diyaloğunun kendi açıklama ekranınızdan sonra gösterilmesini
// istiyor; ters sırada reddedilme oranı ciddi biçimde artıyor.
// ============================================================

/// Reklam alanının hangi ekranda olduğu. Her alanın ayrı birim
/// kimliği var; AdMob panelinde gelir kırılımını görebilmek için.
enum AdPlacement: String {
    case quiz
    case result
    case list

    fileprivate var infoKey: String {
        switch self {
        case .quiz: return "YDSAdUnitQuiz"
        case .result: return "YDSAdUnitResult"
        case .list: return "YDSAdUnitList"
        }
    }
}

@MainActor
final class AdsManager: ObservableObject {

    /// SDK başlatıldı ve reklam istenebilir.
    @Published private(set) var isReady = false
    /// Ayarlar ekranındaki "Reklam tercihleri" satırı etkin olsun mu?
    @Published private(set) var privacyOptionsAvailable = false

    /// Derlemede reklam kapalıysa hiçbir şey yapılmaz.
    let enabled: Bool = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "YDSAdsEnabled") as? String
        return (raw ?? "YES").uppercased() != "NO"
    }()

    func adUnitID(for placement: AdPlacement) -> String? {
        guard enabled else { return nil }
        let value = Bundle.main.object(forInfoDictionaryKey: placement.infoKey) as? String
        let trimmed = value?.trimmingCharacters(in: .whitespaces) ?? ""
        // Boş bırakılan alan hiç çizilmez: yarım kalmış boş bir kutu
        // göstermektense hiç göstermemek daha iyi.
        return trimmed.isEmpty ? nil : trimmed
    }

    // ------------------------------------------------------------
    // Başlatma
    // ------------------------------------------------------------

    func prepare() async {
        guard enabled, !isReady else { return }

        await requestConsent()
        await requestTrackingAuthorizationIfNeeded()

        MobileAds.shared.start()
        isReady = true
    }

    /// UMP onay akışı.
    ///
    /// Türkiye gibi Google'ın onay formu göstermediği bölgelerde
    /// `canRequestAds` doğrudan true döner ve kullanıcı hiçbir pencere
    /// görmez — gereksiz bir tıklama eklemiyoruz.
    private func requestConsent() async {
        let parameters = RequestParameters()
        #if DEBUG
        // Geliştirmede AB davranışını sınamak için:
        // let debugSettings = DebugSettings()
        // debugSettings.geography = .EEA
        // debugSettings.testDeviceIdentifiers = ["CIHAZ_KIMLIGI"]
        // parameters.debugSettings = debugSettings
        #endif

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }

        guard let root = Self.rootViewController else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.loadAndPresentIfRequired(from: root) { _ in
                continuation.resume()
            }
        }

        privacyOptionsAvailable =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Kullanıcı tercihini sonradan değiştirebilsin diye (Ayarlar ekranı).
    func presentPrivacyOptions() async {
        guard let root = Self.rootViewController else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.presentPrivacyOptionsForm(from: root) { _ in
                continuation.resume()
            }
        }
    }

    /// ATT izni.
    ///
    /// Reddedilirse uygulama aynen çalışmaya devam eder; reklamlar
    /// yalnızca kişiselleştirilmeden gösterilir. Bu yüzden izni
    /// zorlayan hiçbir ekran koymuyoruz — Apple bunu da reddediyor.
    private func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // Kısa gecikme: uygulama daha ilk karesini çizmeden sistem
        // diyaloğu açılırsa iOS onu bazen hiç göstermiyor.
        try? await Task.sleep(nanoseconds: 600_000_000)
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    // ------------------------------------------------------------

    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
    }
}
