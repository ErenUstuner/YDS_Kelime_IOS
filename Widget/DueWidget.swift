import WidgetKit
import SwiftUI

// ============================================================
// "Tekrar bekleyenler" widget'ı
//
// Widget, uygulamanın yazdığı küçük özet dosyasını okur; desteyi ve
// tüm tekrar kayıtlarını kendisi çözümlemez. Sebebi widget belleğinin
// sert biçimde sınırlı olması — 781 kartı çözümleyen bir widget
// sistem tarafından sessizce sonlandırılır ve boş görünür.
//
// Zaman çizelgesi gece yarısında yenilenir: takvim günü değişince
// vadesi gelen kart sayısı da değişir.
// ============================================================

struct DueEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedContainer.WidgetSnapshot
}

struct DueProvider: TimelineProvider {

    func placeholder(in context: Context) -> DueEntry {
        DueEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DueEntry) -> Void) {
        completion(DueEntry(date: Date(),
                            snapshot: SharedContainer.readSnapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DueEntry>) -> Void) {
        let entry = DueEntry(date: Date(),
                             snapshot: SharedContainer.readSnapshot() ?? .placeholder)
        let midnight = Calendar.current.nextDate(after: Date(),
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct DueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YDSDueWidget", provider: DueProvider()) { entry in
            DueWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.surface }
        }
        .configurationDisplayName("Tekrar bekleyenler")
        .description("Bugün tekrarı gelen kelime sayısını gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// ============================================================

struct DueWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: DueEntry

    private var snapshot: SharedContainer.WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    // ---------- Ana ekran ----------

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .font(.caption2)
                Text("YDS")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)

            Spacer(minLength: 0)

            Text("\(snapshot.due)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(snapshot.due > 0 ? Theme.warn : Theme.ok)
                .contentTransition(.numericText())

            Text(headline)
                .font(.caption)
                .foregroundStyle(Theme.txt2)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            small
            Divider().overlay(Theme.line)
            VStack(alignment: .leading, spacing: 8) {
                metric("Yeni kelime", "\(snapshot.newCards)", Theme.accent)
                metric("En uzun seri", "\(snapshot.streakBest)", Theme.warn)
                metric("Doğruluk", snapshot.accuracy.map { "%\($0)" } ?? "—", Theme.ok)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.txt3)
            Spacer(minLength: 4)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
    }

    // ---------- Kilit ekranı ----------

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text("\(snapshot.due)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("tekrar")
                    .font(.system(size: 9))
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("YDS Kelimelerim")
                .font(.caption2.weight(.semibold))
            Text("\(snapshot.due) tekrar bekliyor")
                .font(.headline)
            Text("\(snapshot.newCards) yeni kelime hazır")
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ---------- Metin ----------

    private var headline: String {
        if snapshot.due > 0 { return "kelimenin tekrarı geldi" }
        if snapshot.studiedToday { return "bugünlük tamam, yarın görüşürüz" }
        return "tekrar yok — yeni kelime çalışabilirsin"
    }
}
