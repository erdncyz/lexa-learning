import SwiftUI
import UIKit

/// Tasarım token'ları — Open Design export'undaki `:root` değişkenlerinden alındı.
/// Açık / koyu mod değerleri prototiple birebir aynıdır.
enum LexaColor {
    static let bg = dynamic(light: 0xE6E8EC, dark: 0x101214)
    static let surface = dynamic(light: 0xF7F8FA, dark: 0x1A1D22)
    static let surface2 = dynamic(light: 0xDDE1E6, dark: 0x262A30)
    static let paper = dynamic(light: 0xFBFBFC, dark: 0x171A1E)
    static let ink = dynamic(light: 0x14171C, dark: 0xF2F3F5)
    static let ink2 = dynamic(light: 0x3A414C, dark: 0xC5CAD1)
    static let ink3 = dynamic(light: 0x3E4652, dark: 0xB4BCC6)
    static let line = dynamic(light: 0xC5CAD3, dark: 0x343A42)
    static let accent = dynamic(light: 0x14555C, dark: 0xC5D4D2)
    static let accentPress = dynamic(light: 0x0E3E44, dark: 0xD5E2E0)
    static let onAccent = dynamic(light: 0xF4F8F8, dark: 0x121618)
    static let accentSoft = dynamic(light: 0xD5E4E3, dark: 0x24302F)
    static let accentInk = dynamic(light: 0x0C3E44, dark: 0xD7E6E4)
    static let danger = dynamic(light: 0x8C2E2A, dark: 0xE7B1AB)
    static let dangerSoft = dynamic(light: 0xF3E4E2, dark: 0x3A2422)
    static let dangerInk = dynamic(light: 0x6E2420, dark: 0xF0C8C3)
    static let wall = Color(hex: 0x16181C)

    /// Cam yüzeyler, alanlar ve ikon daireleri için zemin: açıkta beyaz, koyuda koyu gri.
    /// Kullanım: `LexaColor.glass.opacity(0.55)`
    static let glass = dynamic(light: 0xFFFFFF, dark: 0x2B3038)

    // Pastel tonlar (kartlar, seviye kutuları, yolculuk noktaları).
    // Koyu modda, açık renkli yazının okunabilmesi için derin tonlara döner.
    static let mint = dynamic(light: 0xBAE4D6, dark: 0x1F3D35)
    static let blue = dynamic(light: 0xBAD6F2, dark: 0x1F3349)
    static let lavender = dynamic(light: 0xD6CCEE, dark: 0x2F2947)
    static let pink = dynamic(light: 0xF4C6D8, dark: 0x46273A)
    static let peach = dynamic(light: 0xF6D6BC, dark: 0x47311F)
    static let cream = dynamic(light: 0xF6ECD0, dark: 0x3E3722)

    static func level(_ code: String) -> Color {
        switch code {
        case "A1": return Color(hex: 0x2F6F62)
        case "A2": return Color(hex: 0x3D6E86)
        case "B1": return Color(hex: 0x3E5680)
        case "B2": return Color(hex: 0x5C5278)
        case "C1": return Color(hex: 0x8A5A3A)
        case "C2": return Color(hex: 0x8A4450)
        default: return Color(hex: 0x3A414C)
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum LexaFont {
    /// Kelimeler ve başlıklar: Newsreader (serif)
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Newsreader", size: size).weight(weight)
    }

    static func displayItalic(_ size: CGFloat) -> Font {
        .custom("Newsreader", size: size).italic()
    }

    /// Arayüz metinleri: IBM Plex Sans
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("IBM Plex Sans", size: size, relativeTo: style).weight(weight)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
