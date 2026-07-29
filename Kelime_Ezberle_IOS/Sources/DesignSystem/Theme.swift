import SwiftUI
import UIKit

// ============================================================
// Tasarım sistemi
//
// Renkler web sürümündeki CSS değişkenlerinden alındı; koyu ve açık
// tema değerleri birebir aynı. İki platform yan yana açıldığında
// aynı ürün gibi görünsün diye.
//
// Renkler Assets.xcassets yerine burada tanımlı: tek dosyada görmek,
// katalogda 20 ayrı renk klasörü gezmekten hem hızlı hem denetlenebilir.
// ============================================================

enum Theme {

    // ---------- Yüzeyler ----------
    static let bg = adaptive(dark: 0x0A0E1A, light: 0xF6F8FC)
    static let surface = adaptive(dark: 0x141B2D, light: 0xFFFFFF)
    static let surface2 = adaptive(dark: 0x1A2338, light: 0xF1F5FB)
    static let surface3 = adaptive(dark: 0x212C46, light: 0xE6ECF7)
    static let line = adaptive(dark: 0x26304A, light: 0xDDE4F0)
    static let line2 = adaptive(dark: 0x37436A, light: 0xC3CEE3)

    // ---------- Metin ----------
    static let txt = adaptive(dark: 0xE8EDF7, light: 0x12182A)
    static let txt2 = adaptive(dark: 0xA6B3CF, light: 0x4A5670)
    static let txt3 = adaptive(dark: 0x6E7C9E, light: 0x77839E)

    // ---------- Vurgu ve durum ----------
    static let accent = adaptive(dark: 0x5B8CFF, light: 0x2F5FD0)
    static let accent2 = adaptive(dark: 0x7AA2FF, light: 0x2452BD)
    static let ok = adaptive(dark: 0x2FBF71, light: 0x12894A)
    static let err = adaptive(dark: 0xF2555A, light: 0xC62630)
    static let warn = adaptive(dark: 0xF0A336, light: 0xA8630F)

    static let accentDim = accent.opacity(0.13)
    static let okDim = ok.opacity(0.14)
    static let errDim = err.opacity(0.14)
    static let warnDim = warn.opacity(0.13)

    // ---------- Ölçüler ----------
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
    }

    enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 32
    }

    /// Ana ekranın arkasındaki yumuşak parlama. Webdeki radial-gradient'in
    /// karşılığı — düz renkli arka plan bu üründe fazla yassı duruyor.
    static var backgroundGradient: some View {
        LinearGradient(colors: [accent.opacity(0.16), bg],
                       startPoint: .top,
                       endPoint: .center)
            .background(bg)
            .ignoresSafeArea()
    }

    // ---------- Yardımcı ----------

    /// Koyu/açık tema için ayrı değer taşıyan renk.
    private static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// ============================================================
// Yazı tipi ölçeği
//
// Hepsi Dynamic Type'a bağlı (.system(...) yerine relativeTo).
// Sabit punto kullanmak, yazı boyutunu büyüten kullanıcılarda
// arayüzü kullanılamaz hâle getirir ve App Store erişilebilirlik
// incelemesinde de göze çarpar.
// ============================================================
extension Font {
    static let ydsDisplay = Font.system(size: 34, weight: .bold, design: .rounded)
    static let ydsTitle = Font.system(.title2, design: .rounded).weight(.semibold)
    static let ydsHeadline = Font.system(.headline, design: .rounded)
    static let ydsBody = Font.system(.body)
    static let ydsCallout = Font.system(.callout)
    static let ydsCaption = Font.system(.caption)
    static let ydsSerif = Font.system(.body, design: .serif)
}
