import SwiftUI

// ============================================================
// Şık düğmesi
//
// Dokunma hedefi en az 52 punto yüksekliğinde: Apple'ın 44 punto
// asgari önerisinin üstünde, çünkü şıklar art arda dizili ve yanlış
// şıka basmak burada geri alınamaz bir eylem.
// ============================================================

struct AnswerButton: View {

    /// `State` yerine `Appearance`: SwiftUI'nin @State sarmalayıcısıyla
    /// ad çakışması yaşamamak için.
    enum Appearance {
        case idle       // henüz cevaplanmadı
        case correct    // doğru şık
        case wrong      // kullanıcının seçtiği yanlış şık
        case dimmed     // cevaplandı, bu şık ilgisiz
    }

    let index: Int
    let text: String
    let state: Appearance
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.sm) {
                Text("\(index + 1)")
                    .font(.ydsCaption.weight(.bold).monospacedDigit())
                    .foregroundStyle(numberColor)
                    .frame(width: 24, height: 24)
                    .background(numberBackground, in: Circle())

                Text(text)
                    .font(.ydsBody.weight(.medium))
                    .foregroundStyle(Theme.txt)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let mark {
                    Image(systemName: mark)
                        .font(.headline)
                        .foregroundStyle(state == .correct ? Theme.ok : Theme.err)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: state == .idle ? 1 : 1.6)
            )
            .opacity(state == .dimmed ? 0.45 : 1)
            .scaleEffect(state == .correct && !reduceMotion ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .animation(.snappy(duration: 0.22), value: state)
        .accessibilityLabel(accessibilityText)
    }

    // ------------------------------------------------------------

    private var mark: String? {
        switch state {
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        default: return nil
        }
    }

    private var background: Color {
        switch state {
        case .idle, .dimmed: return Theme.surface
        case .correct: return Theme.okDim
        case .wrong: return Theme.errDim
        }
    }

    private var border: Color {
        switch state {
        case .idle, .dimmed: return Theme.line
        case .correct: return Theme.ok
        case .wrong: return Theme.err
        }
    }

    private var numberColor: Color {
        state == .idle ? Theme.txt3 : Theme.txt2
    }

    private var numberBackground: Color {
        state == .idle ? Theme.surface3 : Theme.surface2
    }

    private var accessibilityText: String {
        switch state {
        case .correct: return "\(text), doğru cevap"
        case .wrong: return "\(text), yanlış cevap"
        default: return text
        }
    }
}
