import SwiftUI
import UniformTypeIdentifiers
import UIKit

// ============================================================
// Ayarlar
//
// Bildirim izni, yedekleme, gizlilik bağlantıları ve sıfırlama.
//
// "Reklam tercihleri" satırı zorunlu: Google'ın onay çerçevesi (UMP)
// kullanıcının kararını sonradan değiştirebilmesini şart koşuyor.
// Bu satır olmadan AB kullanıcılarına reklam gösterme hakkı doğmuyor.
// ============================================================

struct SettingsView: View {

    @EnvironmentObject private var env: AppEnvironment

    @AppStorage("notifications.enabled") private var remindersOn = false
    @AppStorage("notifications.hour") private var reminderHour = 20

    @State private var showsResetConfirm = false
    @State private var showsImporter = false
    @State private var exportURL: URL?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                remindersSection
                backupSection
                adsSection
                aboutSection
                dangerSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient)
            .navigationTitle("Ayarlar")
            .alert("Tüm ilerleme silinsin mi?", isPresented: $showsResetConfirm) {
                Button("Sil", role: .destructive) {
                    env.store.reset()
                    env.refreshWidget()
                    message = "Tüm ilerleme sıfırlandı."
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Öğrenme geçmişin, tekrar takvimin ve istatistiklerin kalıcı olarak silinecek. Bu işlem geri alınamaz.")
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil },
                                                       set: { if !$0 { message = nil } })) {
                Button("Tamam", role: .cancel) {}
            }
            .fileImporter(isPresented: $showsImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .sheet(item: Binding(get: { exportURL.map(ShareItem.init) },
                                 set: { if $0 == nil { exportURL = nil } })) { item in
                ShareSheet(url: item.url)
            }
        }
    }

    // ------------------------------------------------------------

    private var remindersSection: some View {
        Section {
            Toggle("Günlük tekrar hatırlatması", isOn: Binding(
                get: { remindersOn },
                set: { newValue in
                    remindersOn = newValue
                    Task { await toggleReminders(newValue) }
                }
            ))

            if remindersOn {
                Picker("Saat", selection: Binding(
                    get: { reminderHour },
                    set: { newValue in
                        reminderHour = newValue
                        Task {
                            await env.notifications.setPreferredHour(newValue)
                            await env.notifications.rescheduleDailyReminder(dueCount: env.counts.due)
                        }
                    }
                )) {
                    ForEach(6...23, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
            }
        } header: {
            Text("Hatırlatma")
        } footer: {
            Text("Vadesi gelen kartın olduğu günlerde tek bir bildirim gönderilir. Tekrar edilecek kart yoksa bildirim gelmez.")
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                exportProgress()
            } label: {
                Label("İlerlemeyi dışa aktar", systemImage: "square.and.arrow.up")
            }
            Button {
                showsImporter = true
            } label: {
                Label("Yedekten geri yükle", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Yedekleme")
        } footer: {
            Text("Dosya, sitedeki \"İlerlemeyi dışa aktar\" düğmesinin ürettiğiyle aynı biçimdedir; iki taraf arasında taşınabilir.")
        }
    }

    private var adsSection: some View {
        Section {
            Button {
                Task { await env.ads.presentPrivacyOptions() }
            } label: {
                Label("Reklam tercihleri", systemImage: "hand.raised")
            }
            .disabled(!env.ads.privacyOptionsAvailable)
        } header: {
            Text("Reklamlar")
        } footer: {
            Text(env.ads.privacyOptionsAvailable
                 ? "Kişiselleştirilmiş reklam onayını buradan değiştirebilirsin."
                 : "Bulunduğun bölgede ek bir onay penceresi gösterilmiyor. Reklamlar kişiselleştirilmeden yayınlanır.")
        }
    }

    private var aboutSection: some View {
        Section("Hakkında") {
            LabeledContent("Kelime sayısı", value: "\(env.deck.cards.count)")
            LabeledContent("Veri sürümü", value: env.deck.generatedAt)
            LabeledContent("Uygulama sürümü", value: Self.appVersion)
            Link(destination: URL(string: "https://ydskelimelerim.com/gizlilik/")!) {
                Label("Gizlilik politikası", systemImage: "lock.shield")
            }
            Link(destination: URL(string: "https://ydskelimelerim.com/kullanim-kosullari/")!) {
                Label("Kullanım koşulları", systemImage: "doc.text")
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showsResetConfirm = true
            } label: {
                Label("Tüm ilerlemeyi sıfırla", systemImage: "trash")
            }
        }
    }

    // ------------------------------------------------------------

    private static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }

    private func toggleReminders(_ enabled: Bool) async {
        guard enabled else {
            await env.notifications.cancelAll()
            return
        }
        let granted = await env.notifications.requestAuthorization()
        if granted {
            await env.notifications.setPreferredHour(reminderHour)
            await env.notifications.rescheduleDailyReminder(dueCount: env.counts.due)
        } else {
            remindersOn = false
            message = "Bildirim izni verilmedi. Ayarlar › Bildirimler bölümünden açabilirsin."
        }
    }

    private func exportProgress() {
        do {
            let data = try env.store.exportData()
            let name = "yds-kelimelerim-ilerleme-\(Self.todayStamp).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            message = "Dışa aktarma başarısız: \(error.localizedDescription)"
        }
    }

    private static var todayStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            // Dosya seçici sandbox dışından URL verir; erişim açıkça istenmeli.
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            try env.store.importData(data)
            env.refreshWidget()
            message = "İlerleme geri yüklendi."
        } catch {
            message = "Dosya okunamadı. Doğru yedek dosyasını seçtiğinden emin ol."
        }
    }
}

// ============================================================
// Paylaşım sayfası
// ============================================================

private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
