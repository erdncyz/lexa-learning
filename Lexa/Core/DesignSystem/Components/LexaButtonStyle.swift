import SwiftUI

/// Prototipteki `.btn-primary / .btn-secondary / .btn-ghost` karşılığı.
struct LexaButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, quiet }

    var kind: Kind = .primary
    var fullWidth = true

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LexaFont.ui(16, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .foregroundStyle(foreground)
            .background { background(pressed: configuration.isPressed) }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(LexaMotion.fast, value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return LexaColor.ink2.opacity(0.7) }
        switch kind {
        case .primary: return LexaColor.onAccent
        case .secondary, .ghost: return LexaColor.accent
        case .quiet: return LexaColor.ink
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch kind {
        case .primary:
            Capsule().fill(isEnabled ? (pressed ? LexaColor.accentPress : LexaColor.accent) : Color.white.opacity(0.45))
                .overlay { if !isEnabled { Capsule().strokeBorder(Color.white.opacity(0.6)) } }
        case .secondary:
            Capsule().fill(Color.white.opacity(pressed ? 0.75 : 0.55))
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.8)) }
        case .quiet:
            Capsule().fill(LexaColor.accentSoft.opacity(pressed ? 0.9 : 0.6))
        case .ghost:
            Color.clear
        }
    }
}

extension ButtonStyle where Self == LexaButtonStyle {
    static var lexaPrimary: LexaButtonStyle { LexaButtonStyle(kind: .primary) }
    static var lexaSecondary: LexaButtonStyle { LexaButtonStyle(kind: .secondary) }
    static var lexaGhost: LexaButtonStyle { LexaButtonStyle(kind: .ghost) }
    static var lexaQuiet: LexaButtonStyle { LexaButtonStyle(kind: .quiet) }
}

/// Dairesel cam ikon butonu (geri, kapat, kaydet).
struct CircleIconButton: View {
    let symbol: String
    let label: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "\(symbol).fill" : symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(LexaColor.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.6)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.8)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
