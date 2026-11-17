import Foundation

/// Kullanıcının tüm tercih ve ilerleme verisi.
/// Misafirken cihazda, giriş yapınca Firestore'da `users/{uid}` dokümanında tutulur.
/// Tek doküman yaklaşımı Firebase ücretsiz (Spark) kotasını en az okuma/yazma ile kullanır.
struct UserData: Codable, Equatable, Sendable {
    var displayName: String?

    // Onboarding
    var onboarded = false
    var learnLang: LearningLanguage?
    var level: Level?
    var goal: LearningGoal?
    var exam: Exam?
    var refresh: RefreshOption?

    // Bildirim
    var notifyOn = false
    var notifyHour = 9
    var notifyMinute = 0

    // Kelime durumları (Word.id listeleri)
    var known: [String] = []
    var learning: [String] = []
    var saved: [String] = []
    var customWords: [Word] = []
    var decks: [Deck] = []

    // Bugün kartı
    var todayWordId: String?
    var todayWordShownAt: Date?

    // Pratik
    /// "yyyy-MM-dd" → doğru sayısı
    var dailyPractice: [String: Int] = [:]
    var journeyDone = 0

    var widgetMode: WidgetMode = .lock

    var updatedAt = Date()

    enum WidgetMode: String, Codable, Sendable { case lock, home }

    var notifyTimeText: String { String(format: "%02d:%02d", notifyHour, notifyMinute) }
    var effectiveLang: LearningLanguage { learnLang ?? .en }
    var effectiveLevel: Level { level ?? .b1 }
    var effectiveRefresh: RefreshOption { refresh ?? .hourly }
}

struct Deck: Codable, Identifiable, Hashable, Sendable {
    var id: String = UUID().uuidString
    var name: String
    var wordIds: [String] = []
}
