import SwiftUI

enum LexaSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let gutter: CGFloat = 20
}

enum LexaRadius {
    static let card: CGFloat = 22
    static let tile: CGFloat = 18
    static let control: CGFloat = 16
}

enum LexaMotion {
    static let fast = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.15)
    static let base = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.2)
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
}

/// Prototipteki pastel degrade zemin (pembe → krem → lila → nane).
struct PastelBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark {
            LinearGradient(
                colors: [Color(hex: 0x1C1A22), Color(hex: 0x16191D), Color(hex: 0x141C1C)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xF3E1E8), Color(hex: 0xF4EEDF), Color(hex: 0xE6E0F1), Color(hex: 0xDCEEE9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [Color(hex: 0xF7F0DC).opacity(0.9), .clear], center: .topTrailing, startRadius: 10, endRadius: 360)
                RadialGradient(colors: [Color(hex: 0xD8EFE8).opacity(0.8), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        }
    }
}

/// Yarı saydam "cam" kart yüzeyi.
struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = LexaSpacing.l
    var radius: CGFloat = LexaRadius.card
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill((tint ?? Color.white).opacity(tint == nil ? 0.45 : 0.55))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                    }
                    .shadow(color: Color(hex: 0x14171C).opacity(0.06), radius: 14, y: 6)
            }
    }
}

extension View {
    func lexaCard(padding: CGFloat = LexaSpacing.l, radius: CGFloat = LexaRadius.card, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius, tint: tint))
    }

    /// Sekme ekranlarının ortak zemini.
    func lexaScreenBackground() -> some View {
        background { PastelBackground() }
    }
}
