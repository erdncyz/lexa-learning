import SwiftUI

enum LearningLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case en, de, es

    var id: String { rawValue }

    var name: String {
        switch self {
        case .en: "İngilizce"
        case .de: "Almanca"
        case .es: "İspanyolca"
        }
    }

    var nativeName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .es: "Español"
        }
    }

    var flag: String {
        switch self {
        case .en: "🇬🇧"
        case .de: "🇩🇪"
        case .es: "🇪🇸"
        }
    }

    var tint: Color {
        switch self {
        case .en: Color(red: 168 / 255, green: 214 / 255, blue: 204 / 255)
        case .de: Color(red: 198 / 255, green: 186 / 255, blue: 226 / 255)
        case .es: Color(red: 242 / 255, green: 198 / 255, blue: 176 / 255)
        }
    }

    /// AVSpeechSynthesizer ses kodu
    var speechCode: String {
        switch self {
        case .en: "en-US"
        case .de: "de-DE"
        case .es: "es-ES"
        }
    }
}

enum Level: String, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .a1: "Başlangıç"
        case .a2: "Temel"
        case .b1: "Orta"
        case .b2: "Orta Üstü"
        case .c1: "İleri"
        case .c2: "Yetkin"
        }
    }

    var tint: Color {
        switch self {
        case .a1: LexaColor.mint
        case .a2: LexaColor.blue
        case .b1: LexaColor.lavender
        case .b2: LexaColor.pink
        case .c1: LexaColor.peach
        case .c2: LexaColor.cream
        }
    }

    var index: Int { Level.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.index < rhs.index }
}

enum LearningGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case exam
    case dailyConversation = "daily_conversation"
    case vocabularyGrowth = "vocabulary_growth"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .exam: "Sınava hazırlanıyorum"
        case .dailyConversation: "Günlük konuşma"
        case .vocabularyGrowth: "Kelime dağarcığımı geliştirmek"
        }
    }

    var subtitle: String {
        switch self {
        case .exam: "IELTS veya TOEFL için kelime öğren."
        case .dailyConversation: "Günlük hayatta kullanabileceğin kelimeleri keşfet."
        case .vocabularyGrowth: "Seviyene uygun yeni kelimeler öğren."
        }
    }

    var symbol: String {
        switch self {
        case .exam: "graduationcap"
        case .dailyConversation: "bubble.left"
        case .vocabularyGrowth: "book"
        }
    }

    /// Sınav hedefi yalnızca İngilizce için sunulur.
    static func options(for lang: LearningLanguage) -> [LearningGoal] {
        lang == .en ? [.exam, .dailyConversation, .vocabularyGrowth] : [.dailyConversation, .vocabularyGrowth]
    }
}

enum Exam: String, Codable, CaseIterable, Identifiable, Sendable {
    case ielts, toefl, yds
    var id: String { rawValue }
    var name: String {
        switch self {
        case .ielts: "IELTS"
        case .toefl: "TOEFL"
        case .yds: "YDS / YÖKDİL"
        }
    }

    /// Kelime setindeki etiket (`exams` alanı) — büyük harf: IELTS, TOEFL, YDS.
    var tag: String { rawValue.uppercased() }
}

enum RefreshOption: Int, Codable, CaseIterable, Identifiable, Sendable {
    case halfHour = 30, hourly = 60, threeHours = 180, daily = 1440

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .halfHour: "30 dakikada bir"
        case .hourly: "Saatte bir"
        case .threeHours: "3 saatte bir"
        case .daily: "Günde bir"
        }
    }

    var shortName: String {
        switch self {
        case .halfHour: "30 dk"
        case .hourly: "1 saat"
        case .threeHours: "3 saat"
        case .daily: "1 gün"
        }
    }

    var subtitle: String {
        switch self {
        case .halfHour: "Sık sık yeni kelimeler keşfet."
        case .hourly: "Gün boyunca düzenli öğren."
        case .threeHours: "Kelimelere daha fazla zaman ayır."
        case .daily: "Her gün yeni bir kelimeyle tanış."
        }
    }

    var symbol: String {
        switch self {
        case .halfHour: "bolt"
        case .hourly: "clock"
        case .threeHours: "sun.max"
        case .daily: "calendar"
        }
    }

    var tint: Color {
        switch self {
        case .halfHour: LexaColor.mint
        case .hourly: LexaColor.blue
        case .threeHours: LexaColor.lavender
        case .daily: LexaColor.pink
        }
    }
}
