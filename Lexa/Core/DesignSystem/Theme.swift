import SwiftUI
import UIKit

/// Uygulama görünümü. Cihaza kaydedilir (giriş yapmadan da geçerli); varsayılan: telefonun ayarı.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "lexa.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistem"
        case .light: "Açık"
        case .dark: "Koyu"
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Tüm pencerelere uygular. `preferredColorScheme(nil)` "Sistem"e geri dönüşte
    /// güvenilir çalışmadığı için pencere düzeyinde ayarlanır; sayfalar ve tam ekran
    /// açılan ekranlar da bunu miras alır.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

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
/// Koyu modda tanıtım ekranındaki ışıklı zemini (`GlowBackground`) kullanır.
struct PastelBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark {
            GlowBackground(intensity: .soft)
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

/// Koyu zemin üzerinde bulanık pembe, altın ve yeşil ışıklar.
/// Tanıtım ekranı `.vivid`, içerik ekranları (kartlar okunaklı kalsın diye) `.soft` kullanır.
struct GlowBackground: View {
    enum Intensity {
        case vivid, soft

        var scale: Double { self == .vivid ? 1 : 0.7 }
    }

    var intensity: Intensity = .vivid

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LexaColor.wall
                Circle().fill(Color(hex: 0xC86A8E).opacity(0.35 * intensity.scale))
                    .frame(width: 340).blur(radius: 90)
                    .position(x: w * 0.12, y: h * 0.18)
                Circle().fill(Color(hex: 0xE5C46B).opacity(0.22 * intensity.scale))
                    .frame(width: 300).blur(radius: 90)
                    .position(x: w * 0.92, y: h * 0.42)
                Circle().fill(Color(hex: 0x2F8A86).opacity(0.35 * intensity.scale))
                    .frame(width: 360).blur(radius: 100)
                    .position(x: w * 0.4, y: h * 0.86)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
                            .fill((tint ?? LexaColor.glass).opacity(tint == nil ? 0.45 : 0.55))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(LexaColor.glass.opacity(0.7), lineWidth: 1)
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
