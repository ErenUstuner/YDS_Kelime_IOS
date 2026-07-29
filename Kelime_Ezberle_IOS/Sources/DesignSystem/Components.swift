import SwiftUI

// ============================================================
// Ortak bileşenler
// ============================================================

/// Kart yüzeyi. Uygulamadaki her kutu bunu kullanır ki köşe yarıçapı,
/// kenarlık ve gölge tek yerden değişsin.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}

/// Küçük bilgi etiketi (sözcük türü, seviye, tekrar sayısı).
struct TagChip: View {
    let text: String
    var color: Color = Theme.txt2
    var background: Color = Theme.surface3

    var body: some View {
        Text(text)
            .font(.ydsCaption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .lineLimit(1)
    }
}

/// Ana ekrandaki sayaç kutusu.
struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.ydsCaption)
                .foregroundStyle(Theme.txt3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Segmentli seçici. SwiftUI'nin Picker'ı yerine kendi bileşenimiz:
/// üç değerden fazlasını taşımıyoruz ve tema renklerine tam uyum gerekiyor.
struct SegmentedChoice<Value: Hashable>: View {
    let values: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(values, id: \.self) { value in
                Button {
                    withAnimation(.snappy(duration: 0.18)) { selection = value }
                } label: {
                    Text(label(value))
                        .font(.ydsCallout.weight(selection == value ? .semibold : .regular))
                        .foregroundStyle(selection == value ? Color.white : Theme.txt2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == value {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm - 2, style: .continuous)
                                    .fill(Theme.accent)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}

/// Birincil eylem düğmesi.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ydsHeadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

/// İkincil (çerçeveli) düğme.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ydsCallout.weight(.medium))
            .foregroundStyle(Theme.txt)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.surface2.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}

/// Vurgulanmış örnek cümle.
///
/// Hedef kelimeyi bulup renklendirir. Metni parçalara ayırıp `Text`
/// birleştirmek yerine `AttributedString` kullanıyoruz: satır kırılması
/// doğru çalışsın ve VoiceOver cümleyi bütün olarak okusun diye.
struct HighlightedSentence: View {
    let sentence: String
    let term: String
    let matcher: SentenceMatcher
    var tint: Color = Theme.accent2

    var body: some View {
        Text(attributed)
            .font(.ydsSerif)
            .foregroundStyle(Theme.txt)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        var result = AttributedString(sentence)
        for range in matcher.matches(term: term, in: sentence) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[lower..<upper].foregroundColor = tint
            result[lower..<upper].font = .ydsSerif.weight(.semibold)
        }
        return result
    }
}

/// İçerik yokken gösterilen sade durum.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Theme.txt3)
            Text(title)
                .font(.ydsHeadline)
                .foregroundStyle(Theme.txt)
            Text(message)
                .font(.ydsCallout)
                .foregroundStyle(Theme.txt3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }
}
