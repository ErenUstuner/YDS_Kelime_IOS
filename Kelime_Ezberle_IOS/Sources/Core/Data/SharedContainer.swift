import Foundation

// ============================================================
// Uygulama ve widget'ın ortak veri kabı
//
// Widget ayrı bir işlemdir; uygulamanın sandbox'ına erişemez.
// İlerleme verisi bu yüzden App Group konteynerine yazılır.
// Grup kimliği koda gömülmez, Info.plist üzerinden xcconfig'ten gelir —
// paket kimliğini değiştirmek isteyen tek bir dosyaya dokunur.
// ============================================================

enum SharedContainer {

    /// Info.plist'ten okunan App Group kimliği.
    static let appGroupIdentifier: String = {
        Bundle.main.object(forInfoDictionaryKey: "YDSAppGroupIdentifier") as? String
            ?? "group.com.ustuner.ydskelimelerim"
    }()

    /// İlerleme dosyasının bulunduğu klasör.
    ///
    /// App Group tanımlı değilse (yanlış profil, eksik entitlement) uygulama
    /// çökmez; kendi Documents klasörüne düşer. Bu durumda widget veriyi
    /// göremez ama uygulamanın kendisi sorunsuz çalışmaya devam eder.
    static var directory: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var progressURL: URL { directory.appendingPathComponent("progress.json") }
    static var widgetSnapshotURL: URL { directory.appendingPathComponent("widget-snapshot.json") }

    /// Widget'ın okuduğu küçük özet.
    ///
    /// Widget'ın 781 kartlık desteyi ve tüm tekrar kayıtlarını çözümlemesi
    /// gereksiz pahalı olurdu; widget belleğinin sınırlı olduğu da unutulmamalı.
    /// Uygulama her oturum sonunda bu özeti yeniden yazar.
    struct WidgetSnapshot: Codable, Sendable {
        var due: Int
        var newCards: Int
        var studiedToday: Bool
        var streakBest: Int
        var accuracy: Int?          // yüzde; hiç cevap yoksa nil
        var updatedAt: Date

        static let placeholder = WidgetSnapshot(due: 12, newCards: 24, studiedToday: false,
                                                streakBest: 9, accuracy: 82, updatedAt: Date())
    }

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: widgetSnapshotURL, options: .atomic)
    }

    static func readSnapshot() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: widgetSnapshotURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
